import 'package:komarigoto_app/domain/entities/recipe.dart';
import 'package:komarigoto_app/domain/repositories/recipe_repository.dart';

/// すべてのレシピを取得するユースケース
abstract class FetchAllRecipesUseCase {
  /// ユースケースを実行します。
  ///
  /// 成功した場合はレシピのリストを返します。
  /// 失敗した場合は例外をスローします。
  Future<List<Recipe>> call();
}

class FetchAllRecipesUseCaseImpl implements FetchAllRecipesUseCase {
  final RecipeRepository _repository;

  FetchAllRecipesUseCaseImpl(this._repository);

  @override
  Future<List<Recipe>> call() async {
    return _repository.fetchAllRecipes();
  }
}
