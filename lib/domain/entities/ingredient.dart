/// 食材マスタ用のエンティティ
class Ingredient {
  final String id;
  final String name;
  final String imageUrl;
  final String category; // "肉/魚", "野菜", "果物", "調味料", "卵・豆製品・乳製品", "その他"

  Ingredient({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.category,
  });
}
