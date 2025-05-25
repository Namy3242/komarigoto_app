/// ユーザーの在庫管理用エンティティ
class InventoryItem {
  final String ingredientId;
  final String status; // "in_stock", "outof_stock"
  final int quantity;

  InventoryItem({
    required this.ingredientId,
    required this.status,
    required this.quantity,
  });
}
