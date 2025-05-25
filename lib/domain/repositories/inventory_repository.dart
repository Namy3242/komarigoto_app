import '../entities/inventory_item.dart';

/// ユーザー在庫関連の操作を定義するリポジトリインターフェース
abstract class InventoryRepository {
  /// ユーザーの在庫一覧を取得
  Future<List<InventoryItem>> fetchUserInventory(String userId);

  /// 在庫アイテムを追加または更新
  Future<void> upsertInventoryItem(String userId, InventoryItem item);

  /// 在庫アイテムを削除
  Future<void> deleteInventoryItem(String userId, String ingredientId);
}
