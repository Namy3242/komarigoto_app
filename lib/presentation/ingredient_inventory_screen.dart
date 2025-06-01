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

  String get userId => FirebaseAuth.instance.currentUser?.uid ?? '';

  // --- レシピ提案・保存用状態 ---
  bool isLoading = false;
  String? errorMessage;

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
  Future<void> suggestAndSaveRecipes(BuildContext context) async {
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

    const endpoint = 'https://asia-northeast1-suggestrecipe.cloudfunctions.net/recipe_suggest';
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    try {
      final res = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'X-API-KEY': apiKey ?? '',
        },
        body: jsonEncode({'ingredients': available}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final recipes = data['recipes'] as List<dynamic>?;
        if (recipes == null || recipes.isEmpty) {
          isLoading = false;
          errorMessage = 'レシピが見つかりませんでした。';
          state = Map.from(state);
          return;
        }
        // Firestoreに全レシピ自動保存
        final batch = FirebaseFirestore.instance.batch();
        final recipesCol = FirebaseFirestore.instance.collection('users/$userId/recipes');
        for (final recipe in recipes) {
          batch.set(recipesCol.doc(), {
            'title': recipe['title'] ?? '',
            'description': recipe['description'] ?? '',
            'ingredients': recipe['ingredients'] ?? [],
            'steps': recipe['steps'] ?? [],
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
        isLoading = false;
        errorMessage = null;
        state = Map.from(state);
        // 成功時はダイアログ表示
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (context) => const AlertDialog(
              title: Text('保存完了'),
              content: Text('提案されたレシピをすべて保存しました。'),
            ),
          );
        }
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
}

// --- 在庫管理画面（StatefulWidget化） ---
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
      body: ListView(
        children: [
          for (final category in [
            '主食', '肉・魚・卵・豆', '野菜', 'きのこ', '調味料', 'その他'
          ])
            IngredientCategorySection(
              category: category,
              ingredients: ingredientsMap[category] ?? [],
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: isLoading ? null : () => notifier.suggestAndSaveRecipes(context),
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
              height: 164,
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
              padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 24), // Removed const
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
                                  'status': isAvailable.value ? 'in_stock' : 'outof_stock', // Corrected string literal
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
        width: 110,
        height: 150,
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
              height: 60,
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
                        height: 60,
                        errorBuilder: (context, error, stackTrace) => Icon(icon, size: 40, color: isAvailable ? color.darken(0.18) : Colors.grey),
                      ),
                    )
                  : Icon(
                      icon,
                      size: 40,
                      color: isAvailable ? color.darken(0.18) : Colors.grey,
                    ),
            ),
            // 下部: テキスト＋ラベル
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

class _MainBottomNavState extends State<MainBottomNav> {
  int _selectedIndex = 0;
  final List<Widget> _screens = [
    const IngredientInventoryScreen(),
    const IngredientMasterAddScreen(),
    const RecipeListScreen(), // 追加
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.kitchen), label: '在庫管理'),
          BottomNavigationBarItem(icon: Icon(Icons.add_box), label: 'マスタ追加'),
          BottomNavigationBarItem(icon: Icon(Icons.restaurant_menu), label: 'レシピ'), // 追加
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
    return Scaffold(
      appBar: AppBar(title: const Text('保存したレシピ一覧')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users/$userId/recipes')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('保存されたレシピはありません'));
          }
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final data = docs[i].data();
              final recipeId = docs[i].id;
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
                    subtitle: Text(data['description'] ?? ''),
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
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    final steps = (widget.recipe['steps'] as List<dynamic>? ?? []);
    _pages = [
      // タイトル
      Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            widget.recipe['title'] ?? '',
            style: TextStyle(fontSize: widget.isLarge ? 28 : 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
      ),
      // 材料
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('材料', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            ...List.generate(
              (widget.recipe['ingredients'] as List<dynamic>? ?? []).length,
              (i) => Text('・${widget.recipe['ingredients'][i]}', style: const TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
      // 手順（steps配列の各要素ごとに1ページ）
      ...List.generate(steps.length, (i) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('手順${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            Text(steps[i], style: const TextStyle(fontSize: 16)),
          ],
        ),
      )),
      // 説明（最後に表示）
      if ((widget.recipe['description'] ?? '').toString().isNotEmpty)
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Text(widget.recipe['description'] ?? '', style: const TextStyle(fontSize: 16)),
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
        ],
      ),
    );
    return GestureDetector(
      onTap: () => Navigator.of(context).maybePop(),
      child: card,
    );
  }
}
