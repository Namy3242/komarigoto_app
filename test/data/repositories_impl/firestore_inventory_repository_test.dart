import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:komarigoto_app/data/datasources/firestore_wrapper.dart';
import 'package:komarigoto_app/data/repositories_impl/firestore_inventory_repository.dart';
import 'package:komarigoto_app/domain/entities/inventory_item.dart';

class MockFirestoreWrapper extends Mock implements FirestoreWrapper {
  @override
  Future<QuerySnapshot<Map<String, dynamic>>> getCollection(String collectionPath) async {
    return super.noSuchMethod(Invocation.method(#getCollection, [collectionPath]),
        returnValue: Future.value(FakeQuerySnapshot([])));
  }

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> getDocument(String collectionPath, String documentId) async {
    return super.noSuchMethod(Invocation.method(#getDocument, [collectionPath, documentId]),
        returnValue: Future.value(FakeQueryDocumentSnapshot(documentId, {})));
  }

  @override
  Future<void> setDocument(String collectionPath, String documentId, Map<String, dynamic> data) async {
    return super.noSuchMethod(Invocation.method(#setDocument, [collectionPath, documentId, data]));
  }

  @override
  Future<void> updateDocument(String collectionPath, String documentId, Map<String, dynamic> data) async {
    return super.noSuchMethod(Invocation.method(#updateDocument, [collectionPath, documentId, data]));
  }

  @override
  Future<void> deleteDocument(String collectionPath, String documentId) async {
    return super.noSuchMethod(Invocation.method(#deleteDocument, [collectionPath, documentId]));
  }
}

void main() {
  late MockFirestoreWrapper mockWrapper;
  late FirestoreInventoryRepository repository;

  setUp(() {
    mockWrapper = MockFirestoreWrapper();
    repository = FirestoreInventoryRepository(mockWrapper);
  });

  test('fetchUserInventory should return a list of inventory items', () async {
    final fakeQuerySnapshot = FakeQuerySnapshot([
      FakeQueryDocumentSnapshot('ingredient1', {
        'status': 'in_stock',
        'quantity': 5,
      }),
    ]);

    when(mockWrapper.getCollection('users/user123/inventory'))
        .thenAnswer((_) async => fakeQuerySnapshot);

    final inventory = await repository.fetchUserInventory('user123');

    expect(inventory.length, 1);
    expect(inventory.first.ingredientId, 'ingredient1');
    expect(inventory.first.status, 'in_stock');
    expect(inventory.first.quantity, 5);
  });

  group('upsertInventoryItem', () {
    final tUserId = 'user123';
    final tInventoryItem = InventoryItem(
      ingredientId: 'ingredient1',
      status: 'in_stock',
      quantity: 10,
    );

    test('should call setDocument on FirestoreWrapper with correct data', () async {
      when(mockWrapper.setDocument(
        'users/$tUserId/inventory',
        tInventoryItem.ingredientId,
        {
          'status': tInventoryItem.status,
          'quantity': tInventoryItem.quantity,
        },
      )).thenAnswer((_) async => Future.value());

      await repository.upsertInventoryItem(tUserId, tInventoryItem);

      verify(mockWrapper.setDocument('users/$tUserId/inventory', tInventoryItem.ingredientId, {
        'status': tInventoryItem.status,
        'quantity': tInventoryItem.quantity,
      }));
    });

    test('should throw an exception when Firestore throws an error', () async {
      when(mockWrapper.setDocument(
        'users/$tUserId/inventory',
        tInventoryItem.ingredientId,
        {
          'status': tInventoryItem.status,
          'quantity': tInventoryItem.quantity,
        },
      )).thenThrow(Exception('Firestore error'));

      expect(() async => await repository.upsertInventoryItem(tUserId, tInventoryItem), throwsException);
    });
  });

  group('deleteInventoryItem', () {
    final tUserId = 'user123';
    final tIngredientId = 'ingredient1';

    test('should call deleteDocument on FirestoreWrapper with correct data', () async {
      when(mockWrapper.deleteDocument('users/$tUserId/inventory', tIngredientId))
          .thenAnswer((_) async => Future.value());

      await repository.deleteInventoryItem(tUserId, tIngredientId);

      verify(mockWrapper.deleteDocument('users/$tUserId/inventory', tIngredientId));
    });

    test('should throw an exception when Firestore throws an error', () async {
      when(mockWrapper.deleteDocument('users/$tUserId/inventory', tIngredientId))
          .thenThrow(Exception('Firestore error'));

      expect(() async => await repository.deleteInventoryItem(tUserId, tIngredientId), throwsException);
    });
  });
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
