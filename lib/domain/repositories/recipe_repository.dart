import '../entities/recipe.dart';

/// レシピ関連の操作を定義するリポジトリインターフェース
abstract class RecipeRepository {
  /// 全てのレシピを取得
  Future<List<Recipe>> fetchAllRecipes();

  /// レシピをIDで取得
  Future<Recipe?> fetchRecipeById(String id);

  /// 新しいレシピを追加
  Future<void> addRecipe(Recipe recipe);

  /// レシピを削除
  Future<void> deleteRecipe(String id);

  /// レシピに「いいね」を追加
  Future<void> likeRecipe(String recipeId, String userId);

  /// レシピの「いいね」を削除
  Future<void> unlikeRecipe(String recipeId, String userId);
}
