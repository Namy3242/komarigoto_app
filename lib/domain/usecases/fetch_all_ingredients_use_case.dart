import 'package:komarigoto_app/domain/entities/ingredient.dart';
import 'package:komarigoto_app/domain/repositories/ingredient_repository.dart';

/// すべての食材マスターデータを取得するユースケース
abstract class FetchAllIngredientsUseCase {
  Future<List<Ingredient>> call();
}

class FetchAllIngredientsUseCaseImpl implements FetchAllIngredientsUseCase {
  final IngredientRepository _repository;

  FetchAllIngredientsUseCaseImpl(this._repository);

  @override
  Future<List<Ingredient>> call() async {
    return _repository.fetchAllIngredients();
  }
}
