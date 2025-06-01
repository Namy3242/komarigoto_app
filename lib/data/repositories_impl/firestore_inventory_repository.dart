import '../datasources/firestore_wrapper.dart';
import '../../domain/entities/inventory_item.dart';
import '../../domain/repositories/inventory_repository.dart';

/// Firestoreを利用したInventoryRepositoryの実装
class FirestoreInventoryRepository implements InventoryRepository {
  final FirestoreWrapper _firestoreWrapper;

  FirestoreInventoryRepository(this._firestoreWrapper);

  @override
  Future<List<InventoryItem>> fetchUserInventory(String userId) async {
    final snapshot = await _firestoreWrapper.getCollection('users/$userId/inventory');
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return InventoryItem(
        ingredientId: doc.id,
        status: data['status'] as String? ?? 'in_stock',
        quantity: (data['quantity'] as int?) ?? 1, // nullなら1をデフォルト
      );
    }).toList();
  }

  @override
  Future<void> upsertInventoryItem(String userId, InventoryItem item) async {
    await _firestoreWrapper.setDocument('users/$userId/inventory', item.ingredientId, {
      'status': item.status,
      'quantity': item.quantity,
    });
  }

  @override
  Future<void> deleteInventoryItem(String userId, String ingredientId) async {
    await _firestoreWrapper.deleteDocument('users/$userId/inventory', ingredientId);
  }
}
