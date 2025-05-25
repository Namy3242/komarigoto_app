import 'package:komarigoto_app/domain/entities/recipe.dart';
import 'package:komarigoto_app/domain/repositories/recipe_repository.dart';

/// レシピを提案するユースケース
abstract class SuggestRecipesUseCase {
  /// ユースケースを実行します。
  ///
  /// [ingredientIds] 在庫のある食材IDのリスト。
  /// 成功した場合は提案レシピのリストを返します。
  /// 失敗した場合は例外をスローします。
  Future<List<Recipe>> call(List<String> ingredientIds);
}

class SuggestRecipesUseCaseImpl implements SuggestRecipesUseCase {
  final RecipeRepository _repository;

  SuggestRecipesUseCaseImpl(this._repository);

  @override
  Future<List<Recipe>> call(List<String> ingredientIds) async {
    // TODO: 設計書に基づき、フィルタリングロジックを実装
    // 例: return _repository.fetchRecipesByIngredients(ingredientIds);
    // 現時点では、すべてのレシピを返し、実際のフィルタリングはリポジトリ側またはこのユースケース内で行うことを想定
    return _repository.fetchAllRecipes(); // 仮実装
  }
}
