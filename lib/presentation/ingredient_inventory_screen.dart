import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:komarigoto_app/data/datasources/firestore_wrapper.dart';
import 'package:komarigoto_app/data/repositories_impl/firestore_inventory_repository.dart';
import 'package:komarigoto_app/domain/usecases/fetch_user_inventory_use_case.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'ingredient_master_add_screen.dart';

class Ingredient {
  final String id; // 追加: マスタID（Firestoreのdoc.id）
  final String name;
  final IconData icon;
  final String category;
  bool isAvailable;
  Ingredient({required this.id, required this.name, required this.icon, required this.category, required this.isAvailable});
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
final ingredientInventoryProvider = StateNotifierProvider<IngredientInventoryNotifier, Map<String, List<Ingredient>>>(
  (ref) => IngredientInventoryNotifier(ref),
);

class IngredientInventoryNotifier extends StateNotifier<Map<String, List<Ingredient>>> {
  final Ref ref;
  IngredientInventoryNotifier(this.ref) : super({});

  final String userId = 'test_user'; // TODO: 本来は認証連携

  // Firestoreから在庫データを取得し、カテゴリごとにマッピングしてstateにセット
  Future<void> fetchInventory() async {
    final firestore = FirebaseFirestore.instance;
    final wrapper = FirestoreWrapper(firestore);
    final repo = FirestoreInventoryRepository(wrapper);
    final useCase = FetchUserInventoryUseCaseImpl(repo);
    final items = await useCase.call(userId);

    // 1. マスタ食材を全件取得し、ingredientId→マスタ情報Mapを作成
    final masterSnapshot = await firestore.collection('ingredients_master').get();
    final masterMap = {
      for (final doc in masterSnapshot.docs)
        doc.id: {
          'name': doc['name'] ?? '',
          'category': doc['category'] ?? 'その他',
          // TODO: アイコンや画像URLも必要ならここで取得
        }
    };

    // 2. inventoryをingredientIdでマスタ参照し、カテゴリ分け
    final Map<String, List<Ingredient>> categorized = {};
    for (final item in items) {
      final master = masterMap[item.ingredientId];
      if (master == null) continue; // マスタに存在しない場合はスキップ
      final ingredient = Ingredient(
        id: item.ingredientId,
        name: master['name'],
        icon: Icons.fastfood, // TODO: アイコンもマスタ連携
        category: master['category'],
        isAvailable: item.status == 'in_stock',
      );
      categorized.putIfAbsent(ingredient.category, () => []).add(ingredient);
    }
    state = categorized;
  }

  void setInitial(Map<String, List<Ingredient>> data) {
    if (state.isEmpty) {
      state = data;
    }
  }

  void toggleIngredient(String category, Ingredient ingredient) {
    final newMap = {...state};
    final list = List<Ingredient>.from(newMap[category] ?? []);
    final idx = list.indexWhere((e) => e.name == ingredient.name);
    if (idx != -1) {
      list[idx] = Ingredient(
        id: ingredient.id, // 追加: IDを保持
        name: ingredient.name,
        icon: ingredient.icon,
        category: ingredient.category,
        isAvailable: !ingredient.isAvailable,
      );
      newMap[category] = List<Ingredient>.from(list);
      state = newMap;
    }
  }
}

class IngredientInventoryScreen extends HookConsumerWidget {
  // Firestore連携型に変更: 引数なし
  const IngredientInventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 初回のみProviderでFirestoreから在庫取得
    useEffect(() {
      ref.read(ingredientInventoryProvider.notifier).fetchInventory();
      return null;
    }, []);
    final ingredientsMap = ref.watch(ingredientInventoryProvider);
    // 早期リターンを削除し、常に全カテゴリを表示
    return ListView(
      children: [
        for (final category in [
          '主食', '肉・魚・卵・豆', '野菜', 'きのこ', '調味料', 'その他'
        ])
          IngredientCategorySection(
            category: category,
            ingredients: ingredientsMap[category] ?? [],
          ),
      ],
    );
  }
}

class IngredientCategorySection extends ConsumerWidget {
  final String category;
  final List<Ingredient> ingredients;

  const IngredientCategorySection({
    required this.category,
    required this.ingredients,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = getCategoryColor(context, category);
    final theme = Theme.of(context);
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
                    // 追加カード
                    _AddIngredientCard(
                      color: color,
                      onTap: () => _showAddIngredientSheet(context, ref, category),
                    ),
                    // 既存の食材カード
                    ...ingredients.map((ingredient) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      child: IngredientCard(
                        name: ingredient.name,
                        icon: ingredient.icon,
                        isAvailable: ingredient.isAvailable,
                        onFlip: () => ref.read(ingredientInventoryProvider.notifier).toggleIngredient(category, ingredient),
                        color: color,
                      ),
                    )),
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
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('ingredients_master')
          .where('category', isEqualTo: category)
          .snapshots(),
      builder: (context, snapshot) {
        final allCandidates = snapshot.data?.docs.map((doc) {
          final data = doc.data();
          return Ingredient(
            id: doc.id, // 追加: マスタID
            name: data['name'] ?? '',
            icon: Icons.fastfood, // アイコンは仮
            category: data['category'] ?? '',
            isAvailable: true,
          );
        }).toList() ?? [];
        final filtered = allCandidates.where((i) =>
          searchText.value.isEmpty || i.name.contains(searchText.value)
        ).toList();
        return Padding(
          padding: EdgeInsets.only(
            left: 16, right: 16,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('在庫ありで追加'),
                    Switch(
                      value: isAvailable.value,
                      onChanged: (v) => isAvailable.value = v,
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: searchController,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: '食材名で検索',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => searchText.value = v,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 150,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: filtered.map((ingredient) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: IngredientCard(
                        name: ingredient.name,
                        icon: ingredient.icon,
                        isAvailable: isAvailable.value,
                        onFlip: () async {
                          // Firestoreに在庫追加（ingredientIdで登録）
                          final firestore = FirebaseFirestore.instance;
                          await firestore.collection('users/test_user/inventory').doc(ingredient.id).set({
                            'ingredientId': ingredient.id,
                            'status': isAvailable.value ? 'in_stock' : 'outof_stock',
                            'quantity': 1,
                          });
                          // 在庫管理画面のProviderを更新
                          if (context.mounted) {
                            final container = ProviderScope.containerOf(context, listen: false);
                            await container.read(ingredientInventoryProvider.notifier).fetchInventory();
                            Navigator.of(context).pop();
                          }
                        },
                        color: getCategoryColor(context, category),
                      ),
                    )).toList(),
                  ),
                ),
              ],
            ),
          ),
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

  const IngredientCard({
    required this.name,
    required this.icon,
    required this.isAvailable,
    required this.onFlip,
    required this.color,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onFlip,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        width: 110,
        height: 150, // 高さを140→110に統一
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
              ? Border.all(color: color.darken(0.18), width: 2.0) // 有るときだけ太めの輪郭線
              : Border.all(color: Colors.transparent, width: 0),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 上部: アイコン
            Container(
              decoration: BoxDecoration(
                color: isAvailable ? Colors.white : Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  if (isAvailable)
                    BoxShadow(
                      color: color.withOpacity(0.13),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                ],
              ),
              padding: const EdgeInsets.all(12),
              child: Icon(
                icon,
                size: 40,
                color: isAvailable ? color.darken(0.18) : Colors.grey,
              ),
            ),
            // 中央: Divider
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Divider(
                color: isAvailable ? color.withOpacity(0.45) : Colors.grey[300],
                thickness: 1.2,
                height: 1,
                indent: 18,
                endIndent: 18,
              ),
            ),
            // 下部: テキスト＋ラベル
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white, // ←背景色を常に白に
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
      ),
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
        ],
      ),
    );
  }
}
