import 'package:komarigoto_app/domain/entities/inventory_item.dart';
import 'package:komarigoto_app/domain/repositories/inventory_repository.dart';

/// ユーザーの在庫情報を取得するユースケース
abstract class FetchUserInventoryUseCase {
  /// ユースケースを実行します。
  ///
  /// [userId] ユーザーID。
  /// 成功した場合は在庫アイテムのリストを返します。
  /// 失敗した場合は例外をスローします。
  Future<List<InventoryItem>> call(String userId);
}

class FetchUserInventoryUseCaseImpl implements FetchUserInventoryUseCase {
  final InventoryRepository _repository;

  FetchUserInventoryUseCaseImpl(this._repository);

  @override
  Future<List<InventoryItem>> call(String userId) async {
    return _repository.fetchUserInventory(userId);
  }
}
