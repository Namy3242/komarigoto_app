import 'package:komarigoto_app/domain/entities/inventory_item.dart';
import 'package:komarigoto_app/domain/repositories/inventory_repository.dart';

/// 在庫に食材を追加するユースケース
abstract class AddIngredientToInventoryUseCase {
  /// ユースケースを実行します。
  ///
  /// [userId] ユーザーID。
  /// [item] 追加する在庫アイテム。
  Future<void> call(String userId, InventoryItem item);
}

class AddIngredientToInventoryUseCaseImpl implements AddIngredientToInventoryUseCase {
  final InventoryRepository _repository;

  AddIngredientToInventoryUseCaseImpl(this._repository);

  @override
  Future<void> call(String userId, InventoryItem item) async {
    // 設計書に基づき、新規追加時は quantity: 1, status: 'in_stock' とする
    // このロジックはViewModel側でInventoryItemを作成する際に含めるか、
    // UseCaseで強制するか検討の余地あり。
    // ここでは渡されたitemをそのまま使用する。
    // 必要であれば、ここでitemの内容を調整するロジックを追加。
    // 例: final newItem = item.copyWith(quantity: 1, status: 'in_stock');
    return _repository.upsertInventoryItem(userId, item);
  }
}
