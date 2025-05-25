import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:komarigoto_app/domain/entities/recipe.dart';
import 'package:komarigoto_app/domain/repositories/recipe_repository.dart';
import 'package:komarigoto_app/domain/usecases/suggest_recipes_use_case.dart';

class MockRecipeRepository extends Mock implements RecipeRepository {}

void main() {
  late SuggestRecipesUseCaseImpl useCase;
  late MockRecipeRepository mockRecipeRepository;

  setUp(() {
    mockRecipeRepository = MockRecipeRepository();
    useCase = SuggestRecipesUseCaseImpl(mockRecipeRepository);
  });

  final tIngredientIds = ['ing1', 'ing2'];
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

  // TODO: フィルタリングロジックが実装されたら、より詳細なテストケースを追加
  test('should fetch recipes from the repository (current implementation fetches all)', () async {
    // Arrange
    when(mockRecipeRepository.fetchAllRecipes()).thenAnswer((_) async => tRecipes); // SuggestRecipesUseCaseの現在の実装に合わせる
    // Act
    final result = await useCase.call(tIngredientIds);
    // Assert
    expect(result, tRecipes);
    verify(mockRecipeRepository.fetchAllRecipes()); // SuggestRecipesUseCaseの現在の実装に合わせる
    verifyNoMoreInteractions(mockRecipeRepository);
  });
}
