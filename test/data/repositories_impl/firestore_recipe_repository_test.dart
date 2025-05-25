// ignore_for_file: avoid_redundant_argument_values, avoid_annotating_with_dynamic, prefer_const_constructors, unnecessary_parenthesis, camel_case_types, subtype_of_sealed_class, avoid_returning_null_for_void, avoid_types_on_closure_parameters, avoid_returning_null
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:komarigoto_app/data/datasources/firestore_wrapper.dart';
import 'package:komarigoto_app/data/repositories_impl/firestore_recipe_repository.dart';
import 'package:komarigoto_app/domain/entities/recipe.dart';

class MockFirestoreWrapper extends Mock implements FirestoreWrapper {
  @override
  Future<QuerySnapshot<Map<String, dynamic>>> getCollection(String collectionPath) async {
    return super.noSuchMethod(
      Invocation.method(#getCollection, [collectionPath]),
      returnValue: Future.value(FakeQuerySnapshot([])),
    );
  }

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> getDocument(String collectionPath, String documentId) async {
    return super.noSuchMethod(
      Invocation.method(#getDocument, [collectionPath, documentId]),
      returnValue: Future.value(FakeQueryDocumentSnapshot(documentId, {})),
    );
  }

  @override
  Future<void> setDocument(String path, String id, Map<String, dynamic> data) async {
    return super.noSuchMethod(
      Invocation.method(#setDocument, [path, id, data]),
      returnValue: Future.value(),
    );
  }

  @override
  Future<void> deleteDocument(String path, String id) async {
    return super.noSuchMethod(
      Invocation.method(#deleteDocument, [path, id]),
      returnValue: Future.value(),
    );
  }

  @override
  Future<void> updateDocument(String path, String id, Map<String, dynamic> data) async {
    return super.noSuchMethod(
      Invocation.method(#updateDocument, [path, id, data]),
      returnValue: Future.value(),
    );
  }

  @override
  Future<T> runTransaction<T>(Future<T> Function(Transaction) transactionHandler) {
    return super.noSuchMethod(
      Invocation.method(#runTransaction, [transactionHandler]),
      returnValue: Future.value() as Future<T>,
    );
  }
}

void main() {
  late MockFirestoreWrapper mockWrapper;
  late FirestoreRecipeRepository repository;

  setUp(() {
    mockWrapper = MockFirestoreWrapper();
    repository = FirestoreRecipeRepository(mockWrapper);
  });

  group('fetchAllRecipes', () {
    test('should return a list of recipes when data is available', () async {
      when(mockWrapper.getCollection('recipes')).thenAnswer((_) async =>
          FakeQuerySnapshot([
            createFakeRecipeDocument('recipe1', {
              'title': 'Tomato Soup',
              'description': 'A delicious tomato soup.',
              'ingredients': [
                {'ingredientId': 'tomato', 'amount': '2'},
              ],
              'steps': ['Chop tomatoes', 'Cook in pot'],
              'imageUrl': 'https://example.com/soup.jpg',
              'createdBy': 'user123',
              'createdAt': '2025-05-23T15:00:00Z',
              'updatedAt': '2025-05-23T15:00:00Z',
              'tags': ['soup', 'easy'],
              'likes': 10,
              'likedUsers': ['user123'],
              'shared': true,
              'prompt': 'Easy soup recipe',
              'difficulty': 'easy',
              'time': 30,
              'servings': 4,
            }),
          ]));

      final recipes = await repository.fetchAllRecipes();

      expect(recipes.length, 1);
      expect(recipes.first.title, 'Tomato Soup');
    });

    test('should return an empty list when no data is available', () async {
      when(mockWrapper.getCollection('recipes')).thenAnswer((_) async => FakeQuerySnapshot([]));

      final recipes = await repository.fetchAllRecipes();

      expect(recipes, isEmpty);
    });

    test('should throw an exception when Firestore throws an error', () async {
      when(mockWrapper.getCollection('recipes')).thenThrow(Exception('Firestore error'));

      expect(() => repository.fetchAllRecipes(), throwsException);
    });
  });

  group('fetchRecipeById', () {
    test('should return a recipe when it exists', () async {
      final tRecipeId = 'recipe1';
      final tRecipeData = {
        'title': 'Tomato Soup',
        'description': 'A delicious tomato soup.',
        'ingredients': [
          {'ingredientId': 'tomato', 'amount': '2'},
        ],
        'steps': ['Chop tomatoes', 'Cook in pot'],
        'imageUrl': 'https://example.com/soup.jpg',
        'createdBy': 'user123',
        'createdAt': '2025-05-23T15:00:00Z',
        'updatedAt': '2025-05-23T15:00:00Z',
        'tags': ['soup', 'easy'],
        'likes': 10,
        'likedUsers': ['user123'],
        'shared': true,
        'prompt': 'Easy soup recipe',
        'difficulty': 'easy',
        'time': 30,
        'servings': 4,
      };
      when(mockWrapper.getDocument('recipes', tRecipeId))
          .thenAnswer((_) async => FakeQueryDocumentSnapshot(tRecipeId, tRecipeData));

      final recipe = await repository.fetchRecipeById(tRecipeId);

      expect(recipe, isNotNull);
      expect(recipe!.title, 'Tomato Soup');
      expect(recipe.ingredients.length, 1);
      expect(recipe.ingredients.first.ingredientId, 'tomato');
    });

    test('should return null when the recipe does not exist', () async {
      final tRecipeId = 'non_existent_id';
      when(mockWrapper.getDocument('recipes', tRecipeId))
          .thenAnswer((_) async => FakeQueryDocumentSnapshot(tRecipeId, {}));

      final recipe = await repository.fetchRecipeById(tRecipeId);
      expect(recipe, isNull);
    });

    test('should throw an exception when Firestore throws an error', () async {
      final tRecipeId = 'recipe1';
      when(mockWrapper.getDocument('recipes', tRecipeId))
          .thenThrow(Exception('Firestore error'));

      expect(() async => await repository.fetchRecipeById(tRecipeId), throwsException);
    });
  });

  group('addRecipe', () {
    test('should call setDocument with correct data', () async {
      final tRecipe = Recipe(
        id: 'new_id',
        title: 'New Recipe',
        description: 'desc',
        ingredients: [],
        steps: [],
        imageUrl: '',
        createdBy: 'user1',
        createdAt: DateTime.parse('2025-05-24T00:00:00Z'),
        updatedAt: DateTime.parse('2025-05-24T00:00:00Z'),
        tags: [],
        likes: 0,
        likedUsers: [],
        shared: false,
        prompt: '',
        difficulty: '',
        time: 0,
        servings: 1,
      );
      final expectedMap = {
        'title': tRecipe.title,
        'description': tRecipe.description,
        'ingredients': [],
        'steps': [],
        'imageUrl': '',
        'createdBy': 'user1',
        'createdAt': tRecipe.createdAt.toIso8601String(),
        'updatedAt': tRecipe.updatedAt.toIso8601String(),
        'tags': [],
        'likes': 0,
        'likedUsers': [],
        'shared': false,
        'prompt': '',
        'difficulty': '',
        'time': 0,
        'servings': 1,
      };
      when(mockWrapper.setDocument('recipes', 'new_id', expectedMap)).thenAnswer((_) async => Future.value());
      await repository.addRecipe(tRecipe);
      verify(mockWrapper.setDocument('recipes', 'new_id', expectedMap)).called(1);
    });
    test('should throw if Firestore throws', () async {
      final tRecipe = Recipe(
        id: 'new_id',
        title: 'New Recipe',
        description: 'desc',
        ingredients: [],
        steps: [],
        imageUrl: '',
        createdBy: 'user1',
        createdAt: DateTime.parse('2025-05-24T00:00:00Z'),
        updatedAt: DateTime.parse('2025-05-24T00:00:00Z'),
        tags: [],
        likes: 0,
        likedUsers: [],
        shared: false,
        prompt: '',
        difficulty: '',
        time: 0,
        servings: 1,
      );
      final expectedMap = {
        'title': tRecipe.title,
        'description': tRecipe.description,
        'ingredients': [],
        'steps': [],
        'imageUrl': '',
        'createdBy': 'user1',
        'createdAt': tRecipe.createdAt.toIso8601String(),
        'updatedAt': tRecipe.updatedAt.toIso8601String(),
        'tags': [],
        'likes': 0,
        'likedUsers': [],
        'shared': false,
        'prompt': '',
        'difficulty': '',
        'time': 0,
        'servings': 1,
      };
      when(mockWrapper.setDocument('recipes', 'new_id', expectedMap)).thenThrow(Exception('add error'));
      expect(() => repository.addRecipe(tRecipe), throwsException);
    });
  });

  group('deleteRecipe', () {
    test('should call deleteDocument with correct id', () async {
      when(mockWrapper.deleteDocument('recipes', 'recipe1')).thenAnswer((_) async => Future.value());
      await repository.deleteRecipe('recipe1');
      verify(mockWrapper.deleteDocument('recipes', 'recipe1')).called(1);
    });
    test('should throw if Firestore throws', () async {
      when(mockWrapper.deleteDocument('recipes', 'recipe1')).thenThrow(Exception('delete error'));
      expect(() => repository.deleteRecipe('recipe1'), throwsException);
    });
  });

  group('likeRecipe', () {
    Future<void> dummyTx(Transaction _) async {}
    test('should like a recipe (transaction success)', () async {
      when(mockWrapper.runTransaction(dummyTx)).thenAnswer((inv) async {
        await dummyTx(FakeTransaction());
      });
      await repository.likeRecipe('recipe1', 'user1');
      verify(mockWrapper.runTransaction(dummyTx)).called(1);
    });
    test('should throw if transaction fails', () async {
      when(mockWrapper.runTransaction(dummyTx)).thenThrow(Exception('tx error'));
      expect(() => repository.likeRecipe('recipe1', 'user1'), throwsException);
    });
  });

  group('unlikeRecipe', () {
    Future<void> dummyTx(Transaction _) async {}
    test('should unlike a recipe (transaction success)', () async {
      when(mockWrapper.runTransaction(dummyTx)).thenAnswer((inv) async {
        await dummyTx(FakeTransaction());
      });
      await repository.unlikeRecipe('recipe1', 'user1');
      verify(mockWrapper.runTransaction(dummyTx)).called(1);
    });
    test('should throw if transaction fails', () async {
      when(mockWrapper.runTransaction(dummyTx)).thenThrow(Exception('tx error'));
      expect(() => repository.unlikeRecipe('recipe1', 'user1'), throwsException);
    });
  });
}

FakeQueryDocumentSnapshot createFakeRecipeDocument(String id, Map<String, dynamic> data) {
  return FakeQueryDocumentSnapshot(id, data);
}

class FakeQuerySnapshot implements QuerySnapshot<Map<String, dynamic>> {
  @override
  final List<FakeQueryDocumentSnapshot> docs;

  FakeQuerySnapshot(this.docs);

  @override
  List<DocumentChange<Map<String, dynamic>>> get docChanges => [];

  @override
  SnapshotMetadata get metadata => throw UnimplementedError();

  @override
  int get size => docs.length;
}

class FakeQueryDocumentSnapshot implements QueryDocumentSnapshot<Map<String, dynamic>> {
  @override
  final String id;
  final Map<String, dynamic> _data;

  FakeQueryDocumentSnapshot(this.id, this._data);

  @override
  Map<String, dynamic> data() => _data;

  @override
  SnapshotMetadata get metadata => throw UnimplementedError();

  @override
  DocumentReference<Map<String, dynamic>> get reference => throw UnimplementedError();

  @override
  dynamic operator [](Object field) => _data[field];

  @override
  bool get exists => true;

  @override
  dynamic get(Object field) => _data[field];
}

class FakeDocumentReference implements DocumentReference<Map<String, dynamic>> {
  @override
  final String id;
  FakeDocumentReference(this.id);
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeFirebaseFirestore extends Fake implements FirebaseFirestore {
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    return super.noSuchMethod(Invocation.method(#collection, [path]));
  }

  @override
  DocumentReference<Map<String, dynamic>> doc(String path) {
    return super.noSuchMethod(Invocation.method(#doc, [path]));
  }

  @override
  Future<T> runTransaction<T>(Future<T> Function(Transaction) transactionHandler, {int? maxAttempts, Duration? timeout}) {
    return super.noSuchMethod(
      Invocation.method(#runTransaction, [transactionHandler], {#maxAttempts: maxAttempts, #timeout: timeout})
    );
  }
}

class FakeTransaction implements Transaction {
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
