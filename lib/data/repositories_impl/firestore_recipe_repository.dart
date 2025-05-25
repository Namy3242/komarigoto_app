import '../../data/datasources/firestore_wrapper.dart';
import '../../domain/entities/recipe.dart';
import '../../domain/repositories/recipe_repository.dart';

/// Firestoreを利用したRecipeRepositoryの実装
class FirestoreRecipeRepository implements RecipeRepository {
  final FirestoreWrapper _firestoreWrapper;

  FirestoreRecipeRepository(this._firestoreWrapper);

  @override
  Future<List<Recipe>> fetchAllRecipes() async {
    final snapshot = await _firestoreWrapper.getCollection('recipes');
    return snapshot.docs.map((doc) {
      final data = doc.data(); // 修正: data() メソッドを使用
      return Recipe(
        id: doc.id,
        title: data['title'],
        description: data['description'],
        ingredients: (data['ingredients'] as List)
            .map((item) => RecipeIngredient(
                  ingredientId: item['ingredientId'],
                  amount: item['amount'],
                ))
            .toList(),
        steps: List<String>.from(data['steps']),
        imageUrl: data['imageUrl'],
        createdBy: data['createdBy'],
        createdAt: DateTime.parse(data['createdAt']),
        updatedAt: DateTime.parse(data['updatedAt']),
        tags: List<String>.from(data['tags']),
        likes: data['likes'],
        likedUsers: List<String>.from(data['likedUsers']),
        shared: data['shared'],
        prompt: data['prompt'],
        difficulty: data['difficulty'],
        time: data['time'],
        servings: data['servings'],
      );
    }).toList();
  }

  @override
  Future<Recipe?> fetchRecipeById(String id) async {
    final doc = await _firestoreWrapper.getDocument('recipes', id);
    final data = doc.data() ?? {};
    return Recipe(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      ingredients: (data['ingredients'] as List? ?? [])
          .map((item) => RecipeIngredient(
                ingredientId: item['ingredientId'] ?? '',
                amount: item['amount'] ?? '',
              ))
          .toList(),
      steps: List<String>.from(data['steps'] ?? []),
      imageUrl: data['imageUrl'] ?? '',
      createdBy: data['createdBy'] ?? '',
      createdAt: DateTime.tryParse(data['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(data['updatedAt'] ?? '') ?? DateTime.now(),
      tags: List<String>.from(data['tags'] ?? []),
      likes: data['likes'] ?? 0,
      likedUsers: List<String>.from(data['likedUsers'] ?? []),
      shared: data['shared'] ?? false,
      prompt: data['prompt'] ?? '',
      difficulty: data['difficulty'] ?? '',
      time: data['time'] ?? 0,
      servings: data['servings'] ?? 0,
    );
  }

  @override
  Future<void> addRecipe(Recipe recipe) async {
    await _firestoreWrapper.setDocument('recipes', recipe.id, {
      'title': recipe.title,
      'description': recipe.description,
      'ingredients': recipe.ingredients
          .map((item) => {
                'ingredientId': item.ingredientId,
                'amount': item.amount,
              })
          .toList(),
      'steps': recipe.steps,
      'imageUrl': recipe.imageUrl,
      'createdBy': recipe.createdBy,
      'createdAt': recipe.createdAt.toIso8601String(),
      'updatedAt': recipe.updatedAt.toIso8601String(),
      'tags': recipe.tags,
      'likes': recipe.likes,
      'likedUsers': recipe.likedUsers,
      'shared': recipe.shared,
      'prompt': recipe.prompt,
      'difficulty': recipe.difficulty,
      'time': recipe.time,
      'servings': recipe.servings,
    });
  }

  @override
  Future<void> deleteRecipe(String id) async {
    await _firestoreWrapper.deleteDocument('recipes', id);
  }

  @override
  Future<void> likeRecipe(String recipeId, String userId) async {
    final docRef = _firestoreWrapper.firestore.collection('recipes').doc(recipeId);
    await _firestoreWrapper.firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      final data = snapshot.data() ?? {};
      final likedUsers = List<String>.from(data['likedUsers'] ?? []);

      if (!likedUsers.contains(userId)) {
        likedUsers.add(userId);
        transaction.update(docRef, {
          'likes': (data['likes'] ?? 0) + 1,
          'likedUsers': likedUsers,
        });
      }
    });
  }

  @override
  Future<void> unlikeRecipe(String recipeId, String userId) async {
    final docRef = _firestoreWrapper.firestore.collection('recipes').doc(recipeId);
    await _firestoreWrapper.firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      final data = snapshot.data() ?? {};
      final likedUsers = List<String>.from(data['likedUsers'] ?? []);

      if (likedUsers.contains(userId)) {
        likedUsers.remove(userId);
        transaction.update(docRef, {
          'likes': (data['likes'] ?? 0) - 1,
          'likedUsers': likedUsers,
        });
      }
    });
  }
}
