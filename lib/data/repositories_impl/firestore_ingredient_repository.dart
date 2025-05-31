import 'dart:developer';
import '../datasources/firestore_wrapper.dart';
import '../../domain/entities/ingredient.dart';
import '../../domain/repositories/ingredient_repository.dart';

/// Firestoreを利用したIngredientRepositoryの実装
class FirestoreIngredientRepository implements IngredientRepository {
  final FirestoreWrapper _firestoreWrapper;

  FirestoreIngredientRepository(this._firestoreWrapper);

  @override
  Future<List<Ingredient>> fetchAllIngredients() async {
    try {
      log('Calling getCollection with ingredients_master');
      final snapshot = await _firestoreWrapper.getCollection('ingredients_master');
      log('Fetched snapshot: ${snapshot.docs.map((doc) => doc.data()).toList()}');
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Ingredient(
          id: doc.id,
          name: data['name'] as String? ?? 'Unknown',
          imageUrl: data['imageUrl'] as String? ?? '',
          category: data['category'] as String? ?? '',
          kana: data['kana'] as String? ?? '',
          synonyms: (data['synonyms'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
        );
      }).toList();
    } catch (e, stackTrace) {
      log('Error fetching ingredients: $e', stackTrace: stackTrace);
      rethrow; // Re-throw the exception to ensure it propagates to the caller
    }
  }

  @override
  Future<Ingredient?> fetchIngredientById(String id) async {
    try {
      final doc = await _firestoreWrapper.getDocument('ingredients_master', id);
      if (!doc.exists || doc.data() == null) return null;
      final data = doc.data()!;
      return Ingredient(
        id: doc.id,
        name: data['name'] as String? ?? 'Unknown',
        imageUrl: data['imageUrl'] as String? ?? '',
        category: data['category'] as String? ?? '',
        kana: data['kana'] as String? ?? '',
        synonyms: (data['synonyms'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      );
    } catch (e, stackTrace) {
      log('Error fetching ingredient by ID: $e', stackTrace: stackTrace);
      throw Exception('Failed to fetch ingredient by ID');
    }
  }

  @override
  Future<void> addIngredient(Ingredient ingredient) async {
    if (ingredient.name.isEmpty || ingredient.imageUrl.isEmpty || ingredient.category.isEmpty) {
      throw ArgumentError('Ingredient fields cannot be empty');
    }
    try {
      await _firestoreWrapper.setDocument('ingredients_master', ingredient.id, {
        'name': ingredient.name,
        'imageUrl': ingredient.imageUrl,
        'category': ingredient.category,
        'kana': ingredient.kana,
        'synonyms': ingredient.synonyms,
      });
    } catch (e, stackTrace) {
      log('Error adding ingredient: $e', stackTrace: stackTrace);
      throw Exception('Failed to add ingredient');
    }
  }

  @override
  Future<void> deleteIngredient(String id) async {
    try {
      await _firestoreWrapper.deleteDocument('ingredients_master', id);
    } catch (e, stackTrace) {
      log('Error deleting ingredient: $e', stackTrace: stackTrace);
      throw Exception('Failed to delete ingredient');
    }
  }

  @override
  Future<void> updateIngredient(Ingredient ingredient) async {
    if (ingredient.id.isEmpty) {
      throw ArgumentError('Ingredient ID cannot be empty for update');
    }
    if (ingredient.name.isEmpty || ingredient.imageUrl.isEmpty || ingredient.category.isEmpty) {
      throw ArgumentError('Ingredient fields cannot be empty for update');
    }
    try {
      await _firestoreWrapper.updateDocument('ingredients_master', ingredient.id, {
        'name': ingredient.name,
        'imageUrl': ingredient.imageUrl,
        'category': ingredient.category,
        'kana': ingredient.kana,
        'synonyms': ingredient.synonyms,
      });
    } catch (e, stackTrace) {
      log('Error updating ingredient: $e', stackTrace: stackTrace);
      throw Exception('Failed to update ingredient');
    }
  }
}
