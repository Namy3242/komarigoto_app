import 'package:komarigoto_app/domain/entities/inventory_item.dart';
import 'package:komarigoto_app/domain/repositories/inventory_repository.dart';

abstract class DeleteInventoryItemUseCase {
  Future<void> call(String userId, String inventoryItemId);
}

class DeleteInventoryItemUseCaseImpl implements DeleteInventoryItemUseCase {
  final InventoryRepository repository;

  DeleteInventoryItemUseCaseImpl(this.repository);

  @override
  Future<void> call(String userId, String inventoryItemId) {
    return repository.deleteInventoryItem(userId, inventoryItemId);
  }
}
