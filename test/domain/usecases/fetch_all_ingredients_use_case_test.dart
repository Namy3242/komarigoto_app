import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:komarigoto_app/domain/entities/ingredient.dart';
import 'package:komarigoto_app/domain/repositories/ingredient_repository.dart';
import 'package:komarigoto_app/domain/usecases/fetch_all_ingredients_use_case.dart';

class MockIngredientRepository extends Mock implements IngredientRepository {}

void main() {
  late FetchAllIngredientsUseCaseImpl useCase;
  late MockIngredientRepository mockIngredientRepository;

  setUp(() {
    mockIngredientRepository = MockIngredientRepository();
    useCase = FetchAllIngredientsUseCaseImpl(mockIngredientRepository);
  });

  final tIngredients = [
    Ingredient(id: 'ing1', name: 'Ingredient 1', imageUrl: '', category: 'test'),
    Ingredient(id: 'ing2', name: 'Ingredient 2', imageUrl: '', category: 'test'),
  ];

  test('should get all ingredients from the repository', () async {
    // Arrange
    when(mockIngredientRepository.fetchAllIngredients()).thenAnswer((_) async => tIngredients);
    // Act
    final result = await useCase.call();
    // Assert
    expect(result, tIngredients);
    verify(mockIngredientRepository.fetchAllIngredients());
    verifyNoMoreInteractions(mockIngredientRepository);
  });
}
