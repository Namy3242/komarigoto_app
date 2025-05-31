/// 食材マスタ用のエンティティ
class Ingredient {
  final String id;
  final String name;
  final String imageUrl;
  final String category; // "肉/魚", "野菜", "果物", "調味料", "卵・豆製品・乳製品", "その他"
  final String kana; // カナ読み
  final List<String> synonyms; // 同義語リスト

  Ingredient({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.category,
    required this.kana,
    required this.synonyms,
  });
}
