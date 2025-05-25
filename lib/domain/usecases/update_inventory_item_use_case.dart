import 'package:komarigoto_app/domain/entities/inventory_item.dart';
import 'package:komarigoto_app/domain/repositories/inventory_repository.dart';

abstract class UpdateInventoryItemUseCase {
  Future<void> call(String userId, InventoryItem item);
}

class UpdateInventoryItemUseCaseImpl implements UpdateInventoryItemUseCase {
  final InventoryRepository repository;

  UpdateInventoryItemUseCaseImpl(this.repository);

  @override
  Future<void> call(String userId, InventoryItem item) async {
    // For updating, we can reuse the upsert logic if it handles existing items.
    // Or, if there's a specific update method in the repository, use that.
    // Assuming upsertInventoryItem handles updates appropriately.
    return await repository.upsertInventoryItem(userId, item);
  }
}
