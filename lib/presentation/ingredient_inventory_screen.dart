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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Text(category, style: Theme.of(context).textTheme.titleLarge),
        ),
        Container(
          color: color.withOpacity(0.4),
          height: 164,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              switchInCurve: Curves.easeInOut,
              switchOutCurve: Curves.easeInOut,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.1, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: Row(
                key: ValueKey(ingredients.map((e) => e.isAvailable).join()),
                children: ingredients.map((ingredient) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: IngredientCard(
                    name: ingredient.name,
                    icon: ingredient.icon,
                    isAvailable: ingredient.isAvailable,
                    onFlip: () => ref.read(ingredientInventoryProvider.notifier).toggleIngredient(category, ingredient),
                    color: color,
                  ),
                )).toList(),
              ),
            ),
          ),
        ),
        const Divider(),
      ],
    );
  }
}

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
        height: 140,
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        decoration: BoxDecoration(
          color: isAvailable ? color : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: isAvailable ? color.withOpacity(0.25) : Colors.black12,
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isAvailable ? theme.colorScheme.primary.withOpacity(0.25) : Colors.grey[300]!,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 上部: アイコン
            Container(
              decoration: BoxDecoration(
                color: isAvailable ? Colors.white : Colors.grey[200],
                shape: BoxShape.circle,
                boxShadow: [
                  if (isAvailable)
                    BoxShadow(
                      color: color.withOpacity(0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                ],
              ),
              padding: const EdgeInsets.all(10),
              child: Icon(
                icon,
                size: 38,
                color: isAvailable ? theme.colorScheme.primary : Colors.grey,
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
                color: isAvailable ? color.withOpacity(0.13) : Colors.grey[100],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isAvailable ? theme.colorScheme.onSecondaryContainer : Colors.grey[600],
                      letterSpacing: 0.5,
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

// main.dartのMyApp直下にProviderScopeを追加してください
