import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:komarigoto_app/data/datasources/firestore_wrapper.dart';
import 'package:komarigoto_app/data/repositories_impl/firestore_inventory_repository.dart';
import 'package:komarigoto_app/domain/usecases/fetch_user_inventory_use_case.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'ingredient_master_add_screen.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../domain/entities/ingredient.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as developer; // developer.log を使用するためにインポート
import 'package:url_launcher/url_launcher.dart';
import 'auth_service.dart'; // AuthServiceをインポート
import 'yomimono_screen.dart'; // YomimonoScreenをインポート

// presentation層用の拡張Ingredientクラス
class PresentationIngredient extends Ingredient {
  final IconData icon;
  bool isAvailable;
  PresentationIngredient({
    required String id,
    required String name,
    required String imageUrl,
    required String category,
    required String kana,
    required List<String> synonyms,
    required this.icon,
    required this.isAvailable,
  }) : super(id: id, name: name, imageUrl: imageUrl, category: category, kana: kana, synonyms: synonyms);
}

// カテゴリごとのマテリアルデザイン風カラー（context依存でThemeから取得）
Color getCategoryColor(BuildContext context, String category) {
  final scheme = Theme.of(context).colorScheme;
  switch (category) {
    case '野菜':
      return scheme.secondaryContainer;
    case '肉':
      return scheme.tertiaryContainer;
    case '魚':
      return scheme.primaryContainer;
    case '調味料':
      return scheme.surfaceVariant;
    case '香辛料':
      return scheme.errorContainer;
    case 'その他':
    default:
      return scheme.background;
  }
}

// 食材在庫リストの状態管理用Provider
final ingredientInventoryProvider = StateNotifierProvider<IngredientInventoryNotifier, Map<String, List<PresentationIngredient>>>(
  (ref) => IngredientInventoryNotifier(ref),
);

class IngredientInventoryNotifier extends StateNotifier<Map<String, List<PresentationIngredient>>> {
  final Ref ref;
  IngredientInventoryNotifier(this.ref) : super({});

  String get userId => FirebaseAuth.instance.currentUser?.uid ?? '';  // --- レシピ提案・保存用状態 ---
  bool _isLoading = false;
  String? errorMessage;

  bool get isLoading => _isLoading;
  
  set isLoading(bool value) {
    _isLoading = value;
    state = Map.from(state); // 状態変更を通知
  }

  // Firestoreから在庫データを取得し、カテゴリごとにマッピングしてstateにセット
  Future<void> fetchInventory() async {
    developer.log('fetchInventory started for userId: $userId', name: 'IngredientInventoryNotifier');
    if (userId.isEmpty) {
      developer.log('User ID is empty, skipping fetch.', name: 'IngredientInventoryNotifier');
      state = {}; // ユーザーIDがない場合は空の状態にする
      return;
    }

    final firestore = FirebaseFirestore.instance;
    final wrapper = FirestoreWrapper(firestore);
    final repo = FirestoreInventoryRepository(wrapper);
    final useCase = FetchUserInventoryUseCaseImpl(repo);
    
    try {
      final items = await useCase.call(userId);
      developer.log('Fetched inventory items: ${items.length}', name: 'IngredientInventoryNotifier');
      if (items.isEmpty) {
        developer.log('No inventory items found for user.', name: 'IngredientInventoryNotifier');
        state = {};
        return;
      }

      // 1. マスタ食材を全件取得し、ingredientId→マスタ情報Mapを作成
      final masterSnapshot = await firestore.collection('ingredients_master').get();
      developer.log('Fetched master ingredients: ${masterSnapshot.docs.length}', name: 'IngredientInventoryNotifier');
      if (masterSnapshot.docs.isEmpty) {
        developer.log('No master ingredients found.', name: 'IngredientInventoryNotifier');
        state = {};
        return;
      }

      final masterMap = {
        for (final doc in masterSnapshot.docs)
          doc.id: {
            'name': doc['name'] ?? '',
            // categoryが空文字やnullなら必ず'その他'にする
            'category': (doc['category'] as String?)?.isNotEmpty == true ? doc['category'] : 'その他',
            'imageUrl': doc['imageUrl'] ?? '',
            'kana': doc['kana'] ?? '',
            'synonyms': (doc['synonyms'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
          }
      };
      developer.log('Created masterMap with ${masterMap.length} entries.', name: 'IngredientInventoryNotifier');

      // 2. inventoryをingredientIdでマスタ参照し、カテゴリ分け
      final Map<String, List<PresentationIngredient>> categorized = {};
      for (final item in items) {
        developer.log('Processing inventory item: ${item.ingredientId}, status: ${item.status}', name: 'IngredientInventoryNotifier');
        final master = masterMap[item.ingredientId];
        if (master == null) {
          // マスタが見つからない場合も仮カードで表示（最低限の情報のみ）
          final ingredient = PresentationIngredient(
            id: item.ingredientId,
            name: '[未登録]',
            imageUrl: '',
            category: 'その他',
            kana: '',
            synonyms: [],
            icon: Icons.help_outline,
            isAvailable: item.status == 'in_stock',
          );
          (categorized['その他'] ??= []).add(ingredient);
          developer.log('Added [未登録] ingredientId ${item.ingredientId} to category その他', name: 'IngredientInventoryNotifier');
          continue;
        }
        developer.log('Found master data for ${item.ingredientId}: ${master['name']}', name: 'IngredientInventoryNotifier');
        final category = (master['category'] as String?)?.isNotEmpty == true ? master['category'] : 'その他';
        final ingredient = PresentationIngredient(
          id: item.ingredientId,
          name: master['name'],
          imageUrl: master['imageUrl'],
          category: category,
          kana: master['kana'],
          synonyms: List<String>.from(master['synonyms'] ?? []),
          icon: Icons.fastfood, // TODO: アイコンもマスタ連携
          isAvailable: item.status == 'in_stock',
        );
        (categorized[category] ??= []).add(ingredient);
        developer.log('Added ${ingredient.name} to category $category. Available: ${ingredient.isAvailable}', name: 'IngredientInventoryNotifier');
      }
      developer.log('Categorized ingredients: $categorized', name: 'IngredientInventoryNotifier');
      developer.log('ingredientsMap keys: [32m${categorized.keys.toList()}[0m', name: 'IngredientInventoryNotifier');
      state = categorized;
      developer.log('State updated with ${state.length} categories.', name: 'IngredientInventoryNotifier');
    } catch (e, stackTrace) {
      developer.log('Error in fetchInventory: $e', stackTrace: stackTrace, name: 'IngredientInventoryNotifier', error: e);
      state = {}; // エラー発生時は空の状態にする
    }
  }

  void setInitial(Map<String, List<Ingredient>> data) {
    if (state.isEmpty) {
      // Ingredient→PresentationIngredientへ変換
      final converted = <String, List<PresentationIngredient>>{};
      data.forEach((key, list) {
        converted[key] = list.map((i) => PresentationIngredient(
          id: i.id,
          name: i.name,
          imageUrl: i.imageUrl,
          category: i.category,
          kana: i.kana,
          synonyms: i.synonyms,
          icon: Icons.fastfood,
          isAvailable: true,
        )).toList();
      });
      state = converted;
    }
  }

  void toggleIngredient(String category, PresentationIngredient ingredient) async {
    final newMap = {...state};
    final list = List<PresentationIngredient>.from(newMap[category] ?? []);
    final idx = list.indexWhere((e) => e.id == ingredient.id); // idで比較
    if (idx != -1) {
      final newStatus = !ingredient.isAvailable;
      // Firestoreの在庫状態も更新
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('users/$userId/inventory').doc(ingredient.id).update({
        'status': newStatus ? 'in_stock' : 'outof_stock',
      });
      list[idx] = PresentationIngredient(
        id: ingredient.id,
        name: ingredient.name,
        imageUrl: ingredient.imageUrl,
        category: ingredient.category,
        kana: ingredient.kana,
        synonyms: ingredient.synonyms,
        icon: ingredient.icon,
        isAvailable: newStatus,
      );
      newMap[category] = List<PresentationIngredient>.from(list);
      state = newMap;
    }
  }

  // --- レシピ提案・保存 ---
  Future<void> suggestAndSaveRecipes(BuildContext context, String mealType, String extraCondition) async {
    final ingredientsMap = state;
    final available = ingredientsMap.values.expand((list) => list).where((i) => i.isAvailable).map((i) => i.name).toList();
    if (available.isEmpty) {
      errorMessage = '在庫がある食材がありません。';
      state = Map.from(state); // 通知
      return;
    }
    isLoading = true;
    errorMessage = null;
    state = Map.from(state); // 通知

    const endpoint = 'https://asia-northeast2-komarigoto-app.cloudfunctions.net/recipe_suggest';
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    try {
      final res = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'X-API-KEY': apiKey ?? '',
        },
        body: jsonEncode({
          'ingredients': available,
          'mealType': mealType,
          'extraCondition': extraCondition,
        }),
      );      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final recipes = data['recipes'] as List<dynamic>?;
        if (recipes == null || recipes.isEmpty) {
          isLoading = false;
          errorMessage = 'レシピが見つかりませんでした。';
          state = Map.from(state);
          return;
        }
        
        // まず成功ダイアログを表示（ブログ投稿完了を待たない）
        isLoading = false;
        errorMessage = null;
        state = Map.from(state);
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (context) => const AlertDialog(
              title: Text('保存完了'),
              content: Text('提案されたレシピをすべて保存しました。'),
            ),
          );
        }
        
        // Firestoreに全レシピ自動保存（非同期で実行、UIはブロックしない）
        _saveRecipesToFirestore(recipes);
      } else {
        isLoading = false;
        errorMessage = 'レシピ提案APIの呼び出しに失敗しました。\n${res.body}';
        state = Map.from(state);
      }
    } catch (e) {
      isLoading = false;
      errorMessage = '通信エラー: $e';
      state = Map.from(state);
    }
  }

  // --- レシピをFirestoreに非同期で保存 ---
  Future<void> _saveRecipesToFirestore(List<dynamic> recipes) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      final recipesCol = FirebaseFirestore.instance.collection('users/$userId/recipes');
      for (final recipe in recipes) {
        final data = {
          'title': recipe['title'] ?? '',
          'description': recipe['description'] ?? '',
          'ingredients': recipe['ingredients'] ?? [],
          'steps': recipe['steps'] ?? [],
          'titleImageUrl': '',
          'stepImageUrls': [],
          'createdAt': FieldValue.serverTimestamp(),
        };
        batch.set(recipesCol.doc(), data);
      }
      await batch.commit();
      developer.log('Recipes saved to Firestore successfully', name: 'IngredientInventoryNotifier');
    } catch (e) {
      developer.log('Failed to save recipes to Firestore: $e', name: 'IngredientInventoryNotifier');
    }
  }
}

// --- 冷蔵庫画面（StatefulWidget化） ---
class IngredientInventoryScreen extends ConsumerStatefulWidget {
  const IngredientInventoryScreen({super.key});

  @override
  ConsumerState<IngredientInventoryScreen> createState() => _IngredientInventoryScreenState();
}

class _IngredientInventoryScreenState extends ConsumerState<IngredientInventoryScreen> {
  @override
  void initState() {
    super.initState();
    // 初期表示時に在庫を取得
    Future.microtask(() {
      ref.read(ingredientInventoryProvider.notifier).fetchInventory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ingredientsMap = ref.watch(ingredientInventoryProvider);
    final notifier = ref.read(ingredientInventoryProvider.notifier);
    final isLoading = notifier.isLoading;
    final errorMessage = notifier.errorMessage;

    // エラー時はSnackBar表示
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
        notifier.errorMessage = null; // 一度表示したらクリア
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('冷蔵庫'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'ログアウト',
            onPressed: () async {
              final shouldLogout = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('ログアウト'),
                  content: const Text('ログアウトしますか？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('キャンセル'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('ログアウト'),
                    ),
                  ],
                ),
              );
              if (shouldLogout == true) {
                final authService = AuthService();
                await authService.signOut();
              }
            },
          ),
        ],
      ),
      body: ListView(
        children: [
          for (final category in [
            '主食', '肉・魚・卵・豆', '野菜', 'きのこ', '調味料', '香辛料', 'その他'
          ])
            IngredientCategorySection(
              category: category,
              ingredients: ingredientsMap[category] ?? [],
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: isLoading ? null : () {
          // レシピ生成用入力フォームを表示
          showDialog(
            context: context,
            builder: (context) {
              String selectedType = '夕食';
              final TextEditingController extraController = TextEditingController();
              return AlertDialog(
                title: const Text('レシピ条件入力'),
                content: StatefulBuilder(
                  builder: (context, setState) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        value: selectedType,
                        decoration: const InputDecoration(labelText: '食事タイプ'),
                        items: const [
                          '朝食', '昼食', '夕食', '作り置き', '調味料(タレ・ソース・ドレッシングなど)',
                        ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (val) => setState(() => selectedType = val!),
                      ),
                      TextField(
                        controller: extraController,
                        decoration: const InputDecoration(labelText: '追加条件'),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      notifier.suggestAndSaveRecipes(context, selectedType, extraController.text);
                    },
                    child: const Text('レシピ生成'),
                  ),
                ],
              );
            },
          );
        },
        tooltip: '今ある食材で作れるレシピ',
        child: isLoading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
            : const Icon(Icons.restaurant_menu),
      ),
    );
  }
}

class IngredientCategorySection extends ConsumerWidget {
  final String category;
  final List<PresentationIngredient> ingredients;

  const IngredientCategorySection({
    required this.category,
    required this.ingredients,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = getCategoryColor(context, category);
    final theme = Theme.of(context);
    final notifier = ref.read(ingredientInventoryProvider.notifier); // notifierを取得
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: color.withOpacity(0.85),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.label, color: color.darken(0.25), size: 26),
                  const SizedBox(width: 10),
                  Text(
                    category,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: color.darken(0.35),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              color: Colors.transparent,
              height: 260, // カテゴリ内の高さを164→260に拡大
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _AddIngredientCard(
                      color: color,
                      onTap: () => _showAddIngredientSheet(context, ref, category),
                    ),
                    ...ingredients.map((ingredient) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      child: IngredientCard(
                        name: ingredient.name,
                        icon: ingredient.icon,
                        isAvailable: ingredient.isAvailable,
                        onFlip: () => notifier.toggleIngredient(category, ingredient),
                        color: color,
                        imageUrl: ingredient.imageUrl,
                        onDelete: () async {
                          await FirebaseFirestore.instance.collection('users/${notifier.userId}/inventory').doc(ingredient.id).delete();
                          await notifier.fetchInventory();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${ingredient.name} を在庫から削除しました')),
                            );
                          }
                        },
                      ),
                    )).toList(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

// --- 食材追加カード ---
class _AddIngredientCard extends StatelessWidget {
  final Color color;
  final VoidCallback onTap;
  const _AddIngredientCard({required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 110,
        height: 110, // 高さを140→110に調整
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.18),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.darken(0.18), width: 1.0),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min, // これを追加
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle_outline, color: color.darken(0.18), size: 38),
              const SizedBox(height: 8),
              Text('追加', style: TextStyle(color: color.darken(0.28), fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}

// --- 食材追加用ボトムシート ---
void _showAddIngredientSheet(BuildContext context, WidgetRef ref, String category) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (context) {
      return _AddIngredientSheet(category: category);
    },
  );
}

class _AddIngredientSheet extends HookWidget {
  final String category;
  const _AddIngredientSheet({required this.category});

  @override
  Widget build(BuildContext context) {
    final searchController = useTextEditingController();
    final searchText = useState('');
    final isAvailable = useState(true); // トグル用
    final notifier = ProviderScope.containerOf(context, listen: false).read(ingredientInventoryProvider.notifier); // notifierを取得
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('ingredients_master')
          .where('category', isEqualTo: category)
          .snapshots(),
      builder: (context, snapshot) {
        final allCandidates = snapshot.data?.docs.map((doc) {
          final data = doc.data();
          return PresentationIngredient(
            id: doc.id,
            name: data['name'] ?? '',
            imageUrl: data['imageUrl'] ?? '',
            category: data['category'] ?? '',
            kana: data['kana'] ?? '',
            synonyms: (data['synonyms'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
            icon: Icons.fastfood,
            isAvailable: true,
          );
        }).toList() ?? [];
        return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance
              .collection('users/${notifier.userId}/inventory') // TODO: userId を使用するように修正
              .get(),
          builder: (context, inventorySnapshot) {
            final inventoryIds = inventorySnapshot.hasData
                ? inventorySnapshot.data!.docs.map((doc) => doc['ingredientId'] as String).toSet()
                : <String>{};
            final filtered = allCandidates.where((i) =>
              !inventoryIds.contains(i.id) &&
              (searchText.value.isEmpty ||
                  i.name.toLowerCase().contains(searchText.value.toLowerCase()) ||
                  i.kana.contains(searchText.value) ||
                  (i.synonyms.any((s) => s.toLowerCase().contains(searchText.value.toLowerCase()))))
            ).toList();

            return Padding(
              padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.75,
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('在庫ありで追加', style: TextStyle(fontSize: 16)),
                        Switch(
                          value: isAvailable.value,
                          onChanged: (val) => isAvailable.value = val,
                          activeColor: Theme.of(context).primaryColor,
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          hintText: '食材名で検索',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey[200],
                          suffixIcon: searchText.value.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    searchController.clear();
                                    searchText.value = '';
                                  },
                                )
                              : null,
                        ),
                        onChanged: (value) => searchText.value = value,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                      child: Text(
                        '候補 (${filtered.length}件)',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: filtered.map((ingredient) {
                            return IngredientCard(
                              name: ingredient.name,
                              icon: ingredient.icon,
                              isAvailable: true,
                              onFlip: () async {
                                final userId = notifier.userId;
                                if (userId.isEmpty) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('ユーザーIDが取得できませんでした。')),
                                    );
                                  }
                                  return;
                                }
                                await FirebaseFirestore.instance
                                    .collection('users/$userId/inventory')
                                    .doc(ingredient.id)
                                    .set({
                                  'ingredientId': ingredient.id,
                                  'name': ingredient.name,
                                  'category': ingredient.category,
                                  'imageUrl': ingredient.imageUrl,
                                  'status': isAvailable.value ? 'in_stock' : 'outof_stock',
                                  'addedAt': FieldValue.serverTimestamp(),
                                });

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('${ingredient.name} を在庫に追加しました')),
                                  );
                                }
                                notifier.fetchInventory();
                              },
                              color: getCategoryColor(context, ingredient.category),
                              imageUrl: ingredient.imageUrl,
                              onDelete: null,
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
                ),
              );
            },
        );
      },
    );
  }
}

// --- 食材カード（グローバルスコープに移動） ---
class IngredientCard extends StatelessWidget {
  final String name;
  final IconData icon;
  final bool isAvailable;
  final VoidCallback onFlip;
  final Color color;
  final String? imageUrl;
  final VoidCallback? onDelete; // 削除用コールバックを追加

  const IngredientCard({
    required this.name,
    required this.icon,
    required this.isAvailable,
    required this.onFlip,
    required this.color,
    this.imageUrl,
    this.onDelete,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // --- 購入リンク生成 ---
    String encode(String s) => Uri.encodeComponent(s);
    final amazonUrl = 'https://www.amazon.co.jp/s?k=' + encode(name);
    final rakutenUrl = 'https://search.rakuten.co.jp/search/mall/' + encode(name);
    // TODO: 生協API連携時はここに追加
    // TODO: Gemini等AIで商品レコメンドを取得する場合はここでAPI呼び出し

    Future<void> openUrl(String url) async {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }

    return GestureDetector(
      onTap: onFlip,
      onLongPressStart: onDelete != null
          ? (details) async {
              final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
              final Offset tapPosition = details.globalPosition;
              final RelativeRect position = RelativeRect.fromRect(
                Rect.fromPoints(
                  tapPosition,
                  tapPosition,
                ),
                Offset.zero & overlay.size,
              );
              final result = await showMenu<String>(
                context: context,
                position: position,
                items: [
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text('削除'),
                      ],
                    ),
                  ),
                ],
              );
              if (result == 'delete') {
                onDelete!();
              }
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        width: 200, // 幅をさらに拡大
        height: 240, // 高さをさらに拡大
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        decoration: BoxDecoration(
          color: isAvailable ? color : Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: isAvailable ? Colors.black12 : Colors.black12,
              blurRadius: isAvailable ? 4 : 16,
              offset: isAvailable ? const Offset(0, 1) : const Offset(0, -8),
            ),
          ],
          border: isAvailable
              ? Border.all(color: color.darken(0.18), width: 2.0)
              : Border.all(color: Colors.transparent, width: 0),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 上部: 画像 or アイコン
            Container(
              width: double.infinity,
              height: 120, // 画像エリアも拡大
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(10),
                  topRight: Radius.circular(10),
                ),
              ),
              child: imageUrl != null && imageUrl!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(10),
                        topRight: Radius.circular(10),
                      ),
                      child: Image.network(
                        imageUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 120,
                        errorBuilder: (context, error, stackTrace) => Icon(icon, size: 64, color: isAvailable ? color.darken(0.18) : Colors.grey),
                      ),
                    )
                  : Icon(
                      icon,
                      size: 64,
                      color: isAvailable ? color.darken(0.18) : Colors.grey,
                    ),
            ),
            // 下部: テキスト＋ラベル＋購入ボタン
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: isAvailable ? color.withOpacity(0.13) : Colors.white,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(10),
                  bottomRight: Radius.circular(10),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isAvailable ? color.darken(0.28) : Colors.grey[600],
                      letterSpacing: 0.7,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  // フリップアニメーション付きチェック表示
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    transitionBuilder: (child, animation) {
                      final rotateAnim = Tween(begin: 0.0, end: 1.0).animate(animation);
                      return AnimatedBuilder(
                        animation: rotateAnim,
                        child: child,
                        builder: (context, child) {
                          final isReverse = rotateAnim.value > 0.5;
                          final angle = isReverse
                              ? (1 - rotateAnim.value) * 3.1416
                              : rotateAnim.value * 3.1416;
                          return Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.001)
                              ..rotateY(angle),
                            child: child,
                          );
                        },
                      );
                    },
                    child: isAvailable
                        ? Row(
                            key: const ValueKey('有る'),
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle, color: Colors.green[600], size: 18),
                              const SizedBox(width: 4),
                            ],
                          )
                        : Row(
                            key: const ValueKey('無い'),
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cancel, color: Colors.red[400], size: 18),
                              const SizedBox(width: 4),
                            ],
                          ),
                  ),
                  // --- 購入ボタン ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.shopping_cart, color: Colors.blueAccent),
                        tooltip: 'Amazonで探す',
                        onPressed: () => openUrl(amazonUrl),
                      ),
                      IconButton(
                        icon: const Icon(Icons.shopping_bag, color: Colors.deepOrange),
                        tooltip: '楽天で探す',
                        onPressed: () => openUrl(rakutenUrl),
                      ),
                      // TODO: 生協APIやAIレコメンドボタンもここに追加可能
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      )
    );
  }
}

// --- ユーティリティ: カラーを暗くする拡張 ---
extension ColorUtils on Color {
  Color darken([double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}

// main.dartのMyApp直下にProviderScopeを追加してください

class MainBottomNav extends StatefulWidget {
  final int initialIndex;
  const MainBottomNav({Key? key, this.initialIndex = 0}) : super(key: key);

  @override
  State<MainBottomNav> createState() => _MainBottomNavState();
}

class _MainBottomNavState extends State<MainBottomNav> {  int _selectedIndex = 0;  final List<Widget> _screens = [
    const IngredientInventoryScreen(),
    const MoodRecipeScreen(), // 気分タブを2番目に移動
    const RecipeListScreen(),
    const YomimonoScreen(), // よみもの画面を追加
    const IngredientMasterAddScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // 5つのアイテムに対応
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        backgroundColor: Colors.white,
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,        selectedLabelStyle: TextStyle(color: Colors.deepPurple, fontSize: 13, fontWeight: FontWeight.bold),
        unselectedLabelStyle: TextStyle(color: Colors.grey, fontSize: 12),
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.kitchen), label: '冷蔵庫'),
          BottomNavigationBarItem(icon: Icon(Icons.emoji_emotions), label: '気分'),
          BottomNavigationBarItem(icon: Icon(Icons.restaurant_menu), label: 'レシピ'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'よみもの'),
          BottomNavigationBarItem(icon: Icon(Icons.add_box), label: '食材候補'),
        ],
      ),
    );
  }
}

// --- レシピ一覧画面 ---
class RecipeListScreen extends HookConsumerWidget {
  const RecipeListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    // 在庫あり食材名リストを取得するStream
    final inventoryStream = FirebaseFirestore.instance
        .collection('users/$userId/inventory')
        .where('status', isEqualTo: 'in_stock')
        .snapshots();
    return Scaffold(
      appBar: AppBar(
        title: const Text('保存したレシピ一覧'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'ログアウト',
            onPressed: () async {
              final shouldLogout = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('ログアウト'),
                  content: const Text('ログアウトしますか？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('キャンセル'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('ログアウト'),
                    ),
                  ],
                ),
              );
              if (shouldLogout == true) {
                final authService = AuthService();
                await authService.signOut();
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users/$userId/recipes')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, recipeSnapshot) {
          if (recipeSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = recipeSnapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('保存されたレシピはありません'));
          }
          // --- ここで在庫Streamをネスト ---
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: inventoryStream,
            builder: (context, inventorySnapshot) {
              if (inventorySnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              // 在庫あり食材名リスト
              final inStockNames = inventorySnapshot.data?.docs
                      .map((doc) => doc['name'] as String? ?? '')
                      .where((name) => name.isNotEmpty)
                      .toSet() ??
                  <String>{};
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final data = docs[i].data();
                  final recipeId = docs[i].id;
                  final ingredients = (data['ingredients'] as List<dynamic>? ?? []).cast<String>();
                  // 作成日時をDateTimeに変換
                  final Timestamp? createdAtTs = data['createdAt'] as Timestamp?;
                  final String createdAtStr = createdAtTs != null
                      ? DateTime.fromMillisecondsSinceEpoch(createdAtTs.millisecondsSinceEpoch)
                          .toLocal()
                          .toString().substring(0, 16).replaceFirst('T', ' ')
                      : '';
                  // 全材料が在庫にあるか判定（調味料・水は在庫不要）
                  final canCook = ingredients.isNotEmpty && ingredients.every((name) {
                    if (name.contains('調味料') || name == '水') {
                      return true;
                    }
                    return inStockNames.contains(name);
                  });
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: GestureDetector(
                      onLongPressStart: (details) async {
                        final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
                        final Offset tapPosition = details.globalPosition;
                        final RelativeRect position = RelativeRect.fromRect(
                          Rect.fromPoints(
                            tapPosition,
                            tapPosition,
                          ),
                          Offset.zero & overlay.size,
                        );
                        final result = await showMenu<String>(
                          context: context,
                          position: position,
                          items: [
                            const PopupMenuItem<String>(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('削除'),
                                ],
                              ),
                            ),
                          ],
                        );
                        if (result == 'delete') {
                          await FirebaseFirestore.instance
                              .collection('users/$userId/recipes')
                              .doc(recipeId)
                              .delete();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('レシピを削除しました')),
                            );
                          }
                        }
                      },
                      child: ListTile(
                        title: Text(data['title'] ?? ''),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (createdAtStr.isNotEmpty)
                              Text('作成日時: $createdAtStr', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            Text(data['description'] ?? ''),
                          ],
                        ),
                        trailing: Icon(
                          canCook ? Icons.check_circle : Icons.cancel,
                          color: canCook ? Colors.green : Colors.red,
                        ),
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (_) => Dialog(
                              backgroundColor: Colors.transparent,
                              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
                              child: Stack(
                                children: [
                                  Center(
                                    child: RecipeFlipCard(
                                      recipe: data,
                                      isLarge: true,
                                    ),
                                  ),
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: IconButton(
                                      icon: const Icon(Icons.close, size: 32, color: Colors.black54),
                                      onPressed: () => Navigator.of(context).pop(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

// --- レシピフリップカード ---
class RecipeFlipCard extends StatefulWidget {
  final Map<String, dynamic> recipe;
  final bool isLarge;
  const RecipeFlipCard({required this.recipe, this.isLarge = false, super.key});

  @override
  State<RecipeFlipCard> createState() => _RecipeFlipCardState();
}

class _RecipeFlipCardState extends State<RecipeFlipCard> {
  int _page = 0;
  late List<String> _ingredients; // 材料リストをStateで管理
  late final List<dynamic> _steps;
  late final List<dynamic>? _stepImageUrls;
  late final String _title;
  late final String _description;
  late final String _titleImageUrl;
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _ingredients = List<String>.from(widget.recipe['ingredients'] ?? []);
    _steps = List<dynamic>.from(widget.recipe['steps'] ?? []);
    _stepImageUrls = widget.recipe['stepImageUrls'] as List<dynamic>?;
    _title = widget.recipe['title'] ?? '';
    _description = widget.recipe['description'] ?? '';
    _titleImageUrl = widget.recipe['titleImageUrl'] ?? '';
    _buildPages();
  }

  void _buildPages() {
    _pages = [
      // タイトル
      Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_titleImageUrl.isNotEmpty)
                Image.network(
                  _titleImageUrl,
                  height: widget.isLarge ? 200 : 100,
                  errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported),
                ),
              const SizedBox(height: 16),
              Text(
                _title,
                style: TextStyle(fontSize: widget.isLarge ? 28 : 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
      // 材料
      SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('材料', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            ...List.generate(_ingredients.length, (i) {
              final ingredient = _ingredients[i];
              return GestureDetector(
                onTap: () => _showSwapDialog(i, ingredient),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '・$ingredient',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
      // 手順
      ...List.generate(_steps.length, (i) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_stepImageUrls != null && _stepImageUrls.length > i && (_stepImageUrls[i] as String).isNotEmpty)
                Image.network(
                  _stepImageUrls[i],
                  height: widget.isLarge ? 200 : 100,
                  errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported),
                ),
              const SizedBox(height: 8),
              Text('手順${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 8),
              // 手順テキスト内の食材名にリンクを付与
              _buildStepTextWithLinks(_steps[i]),
            ],
          ),
        );
      }),
      // 説明
      if (_description.isNotEmpty)
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Text(_description, style: const TextStyle(fontSize: 16)),
        ),
    ];
  }

  void _next() {
    setState(() {
      _page = (_page + 1) % _pages.length;
    });
  }

  void _prev() {
    setState(() {
      _page = (_page - 1 + _pages.length) % _pages.length;
    });
  }

  Future<void> _showSwapDialog(int index, String ingredient) async {
    // ingredientのカテゴリをFirestoreから取得
    final firestore = FirebaseFirestore.instance;
    final masterSnap = await firestore
        .collection('ingredients_master')
        .where('name', isEqualTo: ingredient)
        .limit(1)
        .get();
    if (masterSnap.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('食材マスタ情報が見つかりません')),
      );
      return;
    }
    final category = masterSnap.docs.first['category'] ?? 'その他';
    // 冷蔵庫の同カテゴリ在庫を取得
    final inventorySnap = await firestore
        .collection('users/${FirebaseAuth.instance.currentUser?.uid}/inventory')
        .get();
    final masterAll = await firestore
        .collection('ingredients_master')
        .get();
    final masterMap = {
      for (final doc in masterAll.docs)
        doc.id: doc.data(),
    };
    final sameCategory = <String>[];
    for (final doc in inventorySnap.docs) {
      final ingId = doc['ingredientId'] as String?;
      if (ingId == null) continue;
      final master = masterMap[ingId];
      if (master == null) continue;
      if ((master['category'] ?? 'その他') == category) {
        sameCategory.add(master['name'] ?? '');
      }
    }
    if (sameCategory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('冷蔵庫に同じカテゴリの食材がありません')),
      );
      return;
    }
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('"$ingredient" を入れ替え'),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final name in sameCategory)
                ListTile(
                  title: Text(name),
                  onTap: () => Navigator.pop(context, name),
                  enabled: name != ingredient,
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
        ],
      ),
    );
    if (selected != null && selected != ingredient) {
      setState(() {
        _ingredients[index] = selected;
        _buildPages();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"$ingredient" を "$selected" に入れ替えました')),
      );
    }
  }

  Future<void> _regenerateRecipe() async {
    // レシピ再生成API呼び出し
    final notifier = ProviderScope.containerOf(context, listen: false).read(ingredientInventoryProvider.notifier);
    await notifier.suggestAndSaveRecipes(context, '夕食', '（材料入れ替え再生成）');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('新しい材料でレシピを再生成しました')),
      );
    }
  }

  // 手順テキスト内の食材名にリンクを付与するWidget
  Widget _buildStepTextWithLinks(String stepText) {
    // 材料リストに含まれる食材名を抽出し、テキスト内でリンク化
    final spans = <InlineSpan>[];
    String rest = stepText;
    while (rest.isNotEmpty) {
      int minIndex = rest.length;
      String? foundIngredient;
      for (final ingredient in _ingredients) {
        final idx = rest.indexOf(ingredient);
        if (idx != -1 && idx < minIndex) {
          minIndex = idx;
          foundIngredient = ingredient;
        }
      }
      if (foundIngredient == null) {
        spans.add(TextSpan(text: rest));
        break;
      }
      if (minIndex > 0) {
        spans.add(TextSpan(text: rest.substring(0, minIndex)));
      }
      // foundIngredientはnullでないのでStringとして扱う
      final ingredientStr = foundIngredient;
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: GestureDetector(
            onTap: () {
              final idx = _ingredients.indexOf(ingredientStr);
              if (idx != -1) {
                _showSwapDialog(idx, ingredientStr);
              }
            },
            child: Text(
              ingredientStr,
              style: const TextStyle(
                color: Colors.blue,
                decoration: TextDecoration.underline,
                fontSize: 16,
              ),
            ),
          ),
        ),
      );
      rest = rest.substring(minIndex + ingredientStr.length);
    }
    return RichText(text: TextSpan(style: const TextStyle(fontSize: 16, color: Colors.black), children: spans));
  }

  @override
  Widget build(BuildContext context) {
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: widget.isLarge ? 340 : 220,
      height: widget.isLarge ? 420 : 260,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 4))],
        border: Border.all(color: Colors.orange.shade200, width: 2),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: _pages[_page]),
          // 左右フリップボタン
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: IconButton(
              icon: const Icon(Icons.chevron_left, size: 32),
              onPressed: _prev,
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: IconButton(
              icon: const Icon(Icons.chevron_right, size: 32),
              onPressed: _next,
            ),
          ),
          // ×ボタン（カード右上）
          Positioned(
            right: 0,
            top: 0,
            child: IconButton(
              icon: const Icon(Icons.close, size: 28, color: Colors.black54),
              onPressed: () => Navigator.of(context).maybePop(),
              tooltip: '閉じる',
            ),
          ),
          // 再生成用FAB（全ページで表示）
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              onPressed: _regenerateRecipe,
              icon: const Icon(Icons.refresh),
              label: const Text('この材料で再生成'),
              heroTag: 'regenerate_recipe',
            ),
          ),
        ],
      ),
    );
    return GestureDetector(
      onTap: () => Navigator.of(context).maybePop(),
      child: card,
    );
  }
}

// --- 気分レシピ画面 ---
class MoodRecipeScreen extends HookConsumerWidget {
  const MoodRecipeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // 状態変更を監視するためにwatchを使用
    final ingredientsMap = ref.watch(ingredientInventoryProvider);
    final notifier = ref.read(ingredientInventoryProvider.notifier);
    final isLoading = notifier.isLoading;
    // --- 選択肢 ---
    final cookingMethods = [
      '焼く', '蒸す', '茹でる', '煮る', '揚げる', '炒める', '和える', '炊く', '漬ける', 'オーブン', '電子レンジ'
    ];
    final cuisines = [
      '和風', '洋風', '中華', 'イタリアン', 'フレンチ', 'エスニック', '韓国', '北欧', 'ジャンク', 'アジアン', 'アメリカン',
    ];
    // 料理に直接関係なさそうなカテゴリを「変わり種」として分離
    final kawaridane = [
      '宇宙食風',
      'アニメ飯',
      'パーティー',
      'キャンプ',
      '映え',
      'ノスタルジー',
      'サバイバル',
      '未来感',
      '昭和レトロ',
      '推し活',
      'ご当地',
      '推理',
      'ゲーム飯',
      '映画モチーフ',
      'ファンタジー',
      'ミステリー',
      'スポーツ観戦',
      'お祭り',
      '深夜',
      '失恋',
      '勝負メシ',
      '癒し',
      '冒険',
      'お祝い',
      'おまじない',
      '非日常',
      '旅気分',
      '推し色',
    ];
    final preferences = [
      '時短', '味重視', 'ヘルシー', '節約', 'ボリューム', '見た目重視', '作り置き', '簡単'
    ];
    // --- State ---
    final selectedMethods = useState<List<String>>([]);
    final selectedCuisines = useState<List<String>>([]);
    final selectedPreferences = useState<List<String>>([]);
    final freewordController = useTextEditingController();

    return Scaffold(
      appBar: AppBar(
        title: const Text('気分でレシピ提案'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'ログアウト',
            onPressed: () async {
              final shouldLogout = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('ログアウト'),
                  content: const Text('ログアウトしますか？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('キャンセル'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('ログアウト'),
                    ),
                  ],
                ),
              );
              if (shouldLogout == true) {
                final authService = AuthService();
                await authService.signOut();
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('調理法', style: theme.textTheme.titleMedium),
              Wrap(
                spacing: 8,
                children: cookingMethods.map((m) => ChoiceChip(
                  label: Text(m),
                  selected: selectedMethods.value.contains(m),
                  onSelected: (v) {
                    final list = [...selectedMethods.value];
                    if (v) {
                      if (!list.contains(m)) list.add(m);
                    } else {
                      list.remove(m);
                    }
                    selectedMethods.value = list;
                  },
                )).toList(),
              ),
              const SizedBox(height: 20),
              Text('料理ジャンル', style: theme.textTheme.titleMedium),
              Wrap(
                spacing: 8,
                children: cuisines.map((c) => ChoiceChip(
                  label: Text(c),
                  selected: selectedCuisines.value.contains(c),
                  onSelected: (v) {
                    final list = [...selectedCuisines.value];
                    if (v) {
                      if (!list.contains(c)) list.add(c);
                    } else {
                      list.remove(c);
                    }
                    selectedCuisines.value = list;
                  },
                )).toList(),
              ),
              const SizedBox(height: 20),
              // 変わり種カテゴリ
              Text('変わり種', style: theme.textTheme.titleMedium),
              Wrap(
                spacing: 8,
                children: kawaridane.map((k) => ChoiceChip(
                  label: Text(k),
                  selected: selectedCuisines.value.contains(k),
                  onSelected: (v) {
                    final list = [...selectedCuisines.value];
                    if (v) {
                      if (!list.contains(k)) list.add(k);
                    } else {
                      list.remove(k);
                    }
                    selectedCuisines.value = list;
                  },
                )).toList(),
              ),
              const SizedBox(height: 20),
              Text('こだわり', style: theme.textTheme.titleMedium),
              Wrap(
                spacing: 8,
                children: preferences.map((p) => ChoiceChip(
                  label: Text(p),
                  selected: selectedPreferences.value.contains(p),
                  onSelected: (v) {
                    final list = [...selectedPreferences.value];
                    if (v) {
                      if (!list.contains(p)) list.add(p);
                    } else {
                      list.remove(p);
                    }
                    selectedPreferences.value = list;
                  },
                )).toList(),
              ),
              const SizedBox(height: 20),
              Text('フリーワード', style: theme.textTheme.titleMedium),
              TextField(
                controller: freewordController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 40),
              Text('選択した条件でレシピを提案します。', style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: isLoading
            ? null
            : () {
                final method = selectedMethods.value.join(' ');
                final cuisine = selectedCuisines.value.join(' ');
                final pref = selectedPreferences.value.join(' ');
                final freeword = freewordController.text.trim();
                final extra = [method, cuisine, pref, freeword].where((e) => e.isNotEmpty).join(' ');
                notifier.suggestAndSaveRecipes(context, '気分', extra);
              },
        icon: isLoading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
            : const Icon(Icons.restaurant),
        label: const Text('レシピ生成'),
      ),
    );
  }
}
