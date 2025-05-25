import '../entities/ingredient.dart';

/// 食材マスタ関連の操作を定義するリポジトリインターフェース
abstract class IngredientRepository {
  /// 全ての食材を取得
  Future<List<Ingredient>> fetchAllIngredients();

  /// 食材をIDで取得
  Future<Ingredient?> fetchIngredientById(String id);

  /// 新しい食材を追加
  Future<void> addIngredient(Ingredient ingredient);

  /// 食材を削除
  Future<void> deleteIngredient(String id);

  /// 食材を更新
  Future<void> updateIngredient(Ingredient ingredient);
}
