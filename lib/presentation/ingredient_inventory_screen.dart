import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class Ingredient {
  final String name;
  final IconData icon;
  final String category;
  bool isAvailable;
  Ingredient({required this.name, required this.icon, required this.category, required this.isAvailable});
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
  (ref) => IngredientInventoryNotifier({}),
);

class IngredientInventoryNotifier extends StateNotifier<Map<String, List<Ingredient>>> {
  IngredientInventoryNotifier(Map<String, List<Ingredient>> initial) : super(initial);

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
  final Map<String, List<Ingredient>> categorizedIngredients;

  const IngredientInventoryScreen({
    required this.categorizedIngredients,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 初回のみProviderに初期値をセット（stateが空のときのみ）
    useEffect(() {
      if (ref.read(ingredientInventoryProvider).isEmpty && categorizedIngredients.isNotEmpty) {
        Future.microtask(() {
          ref.read(ingredientInventoryProvider.notifier).setInitial(categorizedIngredients);
        });
      }
      return null;
    }, []); // 依存配列を空にして初回のみ実行
    final ingredientsMap = ref.watch(ingredientInventoryProvider);
    return ListView(
      children: ingredientsMap.entries.map((entry) =>
        IngredientCategorySection(
          category: entry.key,
          ingredients: entry.value,
        )
      ).toList(),
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
    // 仮の候補リスト（本来はDBや定数から）
    final allCandidates = [
      Ingredient(name: 'トマト', icon: Icons.local_pizza, category: '野菜', isAvailable: true),
      Ingredient(name: 'きゅうり', icon: Icons.eco, category: '野菜', isAvailable: true),
      Ingredient(name: 'にんじん', icon: Icons.emoji_nature, category: '野菜', isAvailable: true),
      Ingredient(name: '鶏肉', icon: Icons.set_meal, category: '肉', isAvailable: true),
      Ingredient(name: '豚肉', icon: Icons.lunch_dining, category: '肉', isAvailable: true),
      Ingredient(name: 'サーモン', icon: Icons.set_meal, category: '魚', isAvailable: true),
      Ingredient(name: '塩', icon: Icons.spa, category: '調味料', isAvailable: true),
      Ingredient(name: 'しょうゆ', icon: Icons.spa, category: '調味料', isAvailable: true),
      Ingredient(name: '卵', icon: Icons.egg, category: 'その他', isAvailable: true),
    ];
    final filtered = allCandidates.where((i) =>
      i.category == category &&
      (searchText.value.isEmpty || i.name.contains(searchText.value))
    ).toList();

    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6, // 高さを画面の60%に指定
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
              height: 140,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: filtered.map((ingredient) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: IngredientCard(
                    name: ingredient.name,
                    icon: ingredient.icon,
                    isAvailable: true,
                    onFlip: () {}, // 追加処理は後で
                    color: getCategoryColor(context, category),
                  ),
                )).toList(),
              ),
            ),
          ],
        ),
      ),
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
        height: 140, // 高さを140→110に統一
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
