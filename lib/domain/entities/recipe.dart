/// レシピ情報用のエンティティ
class Recipe {
  final String id;
  final String title;
  final String description;
  final List<RecipeIngredient> ingredients;
  final List<String> steps;
  final String imageUrl;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> tags;
  final int likes;
  final List<String> likedUsers;
  final bool shared;
  final String prompt;
  final String difficulty;
  final int time;
  final int servings;

  Recipe({
    required this.id,
    required this.title,
    required this.description,
    required this.ingredients,
    required this.steps,
    required this.imageUrl,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.tags,
    required this.likes,
    required this.likedUsers,
    required this.shared,
    required this.prompt,
    required this.difficulty,
    required this.time,
    required this.servings,
  });
}

/// レシピ内の食材情報
class RecipeIngredient {
  final String ingredientId;
  final String amount;

  RecipeIngredient({
    required this.ingredientId,
    required this.amount,
  });
}
