import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:komarigoto_app/domain/entities/recipe.dart';
import 'package:komarigoto_app/domain/repositories/recipe_repository.dart';
import 'package:komarigoto_app/domain/usecases/fetch_all_recipes_use_case.dart';

class MockRecipeRepository extends Mock implements RecipeRepository {}

void main() {
  late FetchAllRecipesUseCaseImpl useCase;
  late MockRecipeRepository mockRecipeRepository;

  setUp(() {
    mockRecipeRepository = MockRecipeRepository();
    useCase = FetchAllRecipesUseCaseImpl(mockRecipeRepository);
  });

  final tRecipes = [
    Recipe(
      id: 'recipe1',
      name: 'Test Recipe 1',
      description: 'Description 1',
      ingredients: [],
      instructions: [],
      category: 'test',
      cookingTime: 30,
      servings: 2,
      imageUrl: ''
    ),
  ];

  test('should get all recipes from the repository', () async {
    // Arrange
    when(mockRecipeRepository.fetchAllRecipes()).thenAnswer((_) async => tRecipes);
    // Act
    final result = await useCase.call();
    // Assert
    expect(result, tRecipes);
    verify(mockRecipeRepository.fetchAllRecipes());
    verifyNoMoreInteractions(mockRecipeRepository);
  });
}
