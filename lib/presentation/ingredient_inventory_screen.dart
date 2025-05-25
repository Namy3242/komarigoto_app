import 'package:flutter/material.dart';
import 'package:animated_list_plus/animated_list_plus.dart';
import 'package:animated_list_plus/transitions.dart';

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

class IngredientInventoryScreen extends StatefulWidget {
  final Map<String, List<Ingredient>> categorizedIngredients;
  final void Function(Ingredient) onToggle;

  const IngredientInventoryScreen({
    required this.categorizedIngredients,
    required this.onToggle,
    super.key,
  });

  @override
  State<IngredientInventoryScreen> createState() => _IngredientInventoryScreenState();
}

class _IngredientInventoryScreenState extends State<IngredientInventoryScreen> {
  late Map<String, List<Ingredient>> _ingredientsMap;

  @override
  void initState() {
    super.initState();
    // Deep copy
    _ingredientsMap = widget.categorizedIngredients.map((k, v) => MapEntry(k, v.map((e) => Ingredient(
      name: e.name,
      icon: e.icon,
      category: e.category,
      isAvailable: e.isAvailable,
    )).toList()));
  }

  void _handleToggle(Ingredient ingredient, String category) {
    setState(() {
      ingredient.isAvailable = !ingredient.isAvailable;
    });
    // ソート処理は削除
    widget.onToggle(ingredient);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: _ingredientsMap.entries.map((entry) =>
        IngredientCategorySection(
          category: entry.key,
          ingredients: entry.value,
          onToggle: (ingredient) => _handleToggle(ingredient, entry.key),
        )
      ).toList(),
    );
  }
}

class IngredientCategorySection extends StatelessWidget {
  final String category;
  final List<Ingredient> ingredients;
  final void Function(Ingredient) onToggle;

  const IngredientCategorySection({
    required this.category,
    required this.ingredients,
    required this.onToggle,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
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
          height: 164, // カード高さ+余白に合わせて調整
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
                    onFlip: () => onToggle(ingredient),
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
