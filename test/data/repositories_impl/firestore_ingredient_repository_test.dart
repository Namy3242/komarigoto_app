import 'dart:developer';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Ensure this import exists
import 'package:komarigoto_app/data/datasources/firestore_wrapper.dart';
import 'package:komarigoto_app/data/repositories_impl/firestore_ingredient_repository.dart';
import 'package:komarigoto_app/domain/entities/ingredient.dart';
import 'package:mockito/annotations.dart';
import 'firestore_ingredient_repository_test.mocks.dart';

@GenerateMocks([FirestoreWrapper])
void main() {
  late MockFirestoreWrapper mockWrapper;
  late FirestoreIngredientRepository repository;

  setUp(() {
    mockWrapper = MockFirestoreWrapper();
    repository = FirestoreIngredientRepository(mockWrapper);
  });

  group('fetchAllIngredients', () {
    test('should return a list of ingredients when data is available', () async {
      when(mockWrapper.getCollection('ingredients_master'))
          .thenAnswer((_) async {
        log('Mocked getCollection called with ingredients_master for fetchAllIngredients test');
        return FakeQuerySnapshot([
          FakeQueryDocumentSnapshot('ingredient1', {
            'name': 'Tomato',
            'imageUrl': 'https://example.com/tomato.jpg',
            'category': 'Vegetable',
          }),
        ]);
      });

      final ingredients = await repository.fetchAllIngredients();

      log('Fetched ingredients: $ingredients');

      expect(ingredients.length, 1);
      expect(ingredients.first.id, 'ingredient1');
      expect(ingredients.first.name, 'Tomato');
      expect(ingredients.first.imageUrl, 'https://example.com/tomato.jpg');
      expect(ingredients.first.category, 'Vegetable');
    });

    test('should throw an exception when Firestore throws an error', () async {
      when(mockWrapper.getCollection('ingredients_master'))
          .thenThrow(Exception('Firestore error'));

      expect(() async => await repository.fetchAllIngredients(), throwsException);
    });

    test('should return an empty list when no ingredients are available', () async {
      // Arrange
      when(mockWrapper.getCollection('ingredients_master'))
          .thenAnswer((_) async {
        log('Mocked getCollection called with ingredients_master for empty list test');
        return FakeQuerySnapshot([]); // Return an empty document list
      });

      // Act
      final ingredients = await repository.fetchAllIngredients();

      // Assert
      log('Fetched ingredients for empty list test: $ingredients');
      expect(ingredients.length, 0);
      expect(ingredients, isEmpty);
    });
  });

  group('fetchIngredientById', () {
    test('should return an ingredient when it exists', () async {
      final tIngredientId = 'ingredient1';
      final tIngredientData = {
        'name': 'Tomato',
        'imageUrl': 'https://example.com/tomato.jpg',
        'category': 'Vegetable',
      };
      when(mockWrapper.getDocument('ingredients_master', tIngredientId))
          .thenAnswer((_) async => FakeDocumentSnapshot(tIngredientId, tIngredientData, exists: true));

      final ingredient = await repository.fetchIngredientById(tIngredientId);

      expect(ingredient, isNotNull);
      expect(ingredient!.id, tIngredientId);
      expect(ingredient.name, 'Tomato');
    });

    test('should return null when the ingredient does not exist', () async {
      final tIngredientId = 'non_existent_id';
      when(mockWrapper.getDocument('ingredients_master', tIngredientId))
          .thenAnswer((_) async => FakeDocumentSnapshot(tIngredientId, {}, exists: false));

      final ingredient = await repository.fetchIngredientById(tIngredientId);

      expect(ingredient, isNull);
    });

    test('should throw an exception when Firestore throws an error', () async {
      final tIngredientId = 'ingredient1';
      when(mockWrapper.getDocument('ingredients_master', tIngredientId))
          .thenThrow(Exception('Firestore error'));

      expect(() async => await repository.fetchIngredientById(tIngredientId), throwsException);
    });
  });

  group('addIngredient', () {
    final tIngredient = Ingredient(
      id: 'newIngredient',
      name: 'Cucumber',
      imageUrl: 'https://example.com/cucumber.jpg',
      category: 'Vegetable',
    );

    test('should call setDocument on FirestoreWrapper with correct data', () async {
      when(mockWrapper.setDocument('ingredients_master', tIngredient.id, argThat(anything)))
          .thenAnswer((_) async => Future.value());

      await repository.addIngredient(tIngredient);

      verify(mockWrapper.setDocument('ingredients_master', tIngredient.id, {
        'name': tIngredient.name,
        'imageUrl': tIngredient.imageUrl,
        'category': tIngredient.category,
      }));
    });

    test('should throw ArgumentError if ingredient name is empty', () async {
      final invalidIngredient = Ingredient(id: 'id', name: '', imageUrl: 'url', category: 'cat');
      expect(() async => await repository.addIngredient(invalidIngredient), throwsArgumentError);
    });

    test('should throw an exception when Firestore throws an error', () async {
      when(mockWrapper.setDocument('ingredients_master', tIngredient.id, argThat(anything)))
          .thenThrow(Exception('Firestore error'));

      expect(() async => await repository.addIngredient(tIngredient), throwsException);
    });
  });

  group('updateIngredient', () {
    final tIngredient = Ingredient(
      id: 'existingIngredient',
      name: 'Updated Tomato',
      imageUrl: 'https://example.com/updated_tomato.jpg',
      category: 'Vegetable',
    );
    test('should call updateDocument on FirestoreWrapper with correct data', () async {
      when(mockWrapper.updateDocument(
        'ingredients_master',
        tIngredient.id,
        {
          'name': tIngredient.name,
          'imageUrl': tIngredient.imageUrl,
          'category': tIngredient.category,
        },
      )).thenAnswer((_) async => Future.value());

      await repository.updateIngredient(tIngredient);

      verify(mockWrapper.updateDocument('ingredients_master', tIngredient.id, {
        'name': tIngredient.name,
        'imageUrl': tIngredient.imageUrl,
        'category': tIngredient.category,
      }));
    });

    test('should throw ArgumentError if ingredient id is empty', () async {
      final invalidIngredient = Ingredient(id: '', name: 'name', imageUrl: 'url', category: 'cat');
      expect(() async => await repository.updateIngredient(invalidIngredient), throwsArgumentError);
    });

    test('should throw an exception when Firestore throws an error', () async {
      when(mockWrapper.updateDocument(
        'ingredients_master',
        tIngredient.id,
        {
          'name': tIngredient.name,
          'imageUrl': tIngredient.imageUrl,
          'category': tIngredient.category,
        },
      )).thenThrow(Exception('Firestore error'));

      expect(() async => await repository.updateIngredient(tIngredient), throwsException);
    });
  });

  group('deleteIngredient', () {
    final tIngredientId = 'ingredientToDelete';
    test('should call deleteDocument on FirestoreWrapper with correct id', () async {
      when(mockWrapper.deleteDocument('ingredients_master', tIngredientId))
          .thenAnswer((_) async => Future.value());

      await repository.deleteIngredient(tIngredientId);

      verify(mockWrapper.deleteDocument('ingredients_master', tIngredientId));
    });

    test('should throw an exception when Firestore throws an error', () async {
      when(mockWrapper.deleteDocument('ingredients_master', tIngredientId))
          .thenThrow(Exception('Firestore error'));

      expect(() async => await repository.deleteIngredient(tIngredientId), throwsException);
    });
  });
}

class FakeQuerySnapshot implements QuerySnapshot<Map<String, dynamic>> {
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;

  // Constructor accepts List<FakeQueryDocumentSnapshot> and casts it internally or expects correct type
  FakeQuerySnapshot(List<FakeQueryDocumentSnapshot> fakeDocs) : docs = fakeDocs;

  @override
  List<DocumentChange<Map<String, dynamic>>> get docChanges => throw UnimplementedError('docChanges not implemented in fake');

  @override
  SnapshotMetadata get metadata => throw UnimplementedError('metadata not implemented in fake');

  @override
  int get size => docs.length;

  // QuerySnapshot does not have an `isEmpty` getter directly. Use `size == 0`.
}

class FakeQueryDocumentSnapshot implements QueryDocumentSnapshot<Map<String, dynamic>> {
  @override
  final String id;
  final Map<String, dynamic> _data;

  FakeQueryDocumentSnapshot(this.id, this._data);

  @override
  Map<String, dynamic> data() => _data;

  @override
  bool get exists => true; // QueryDocumentSnapshot always exists

  @override
  SnapshotMetadata get metadata => throw UnimplementedError('metadata not implemented in fake');

  @override
  DocumentReference<Map<String, dynamic>> get reference => throw UnimplementedError('reference not implemented in fake');

  @override
  dynamic get(Object field) {
    if (_data.containsKey(field as String)) {
      return _data[field];
    }
    // Firestore's get behavior might throw or return null based on field type.
    // For simplicity in mock, throwing an error for non-existent fields.
    throw StateError('Field "$field" does not exist in the document snapshot with id "$id"');
  }

  @override
  dynamic operator [](Object field) => get(field);
}

// Add FakeDocumentSnapshot for getDocument testing
class FakeDocumentSnapshot implements DocumentSnapshot<Map<String, dynamic>> {
  @override
  final String id;
  final Map<String, dynamic>? _data;
  @override
  final bool exists;

  FakeDocumentSnapshot(this.id, this._data, {this.exists = true});

  @override
  Map<String, dynamic>? data() => _data;

  @override
  SnapshotMetadata get metadata => throw UnimplementedError('metadata not implemented in fake');

  @override
  DocumentReference<Map<String, dynamic>> get reference => throw UnimplementedError('reference not implemented in fake');

  @override
  dynamic get(Object field) {
    if (_data != null && _data.containsKey(field as String)) { // Removed ! from _data.containsKey
      return _data[field]; // Removed ! from _data[field]
    }
    throw StateError('Field "$field" does not exist in the document snapshot with id "$id"');
  }

  @override
  dynamic operator [](Object field) => get(field);
}