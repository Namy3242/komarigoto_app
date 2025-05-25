# カスタムプロンプト設定

## アーキテクチャ
- クリーンアーキテクチャ＋MVVMを採用
- 各レイヤーの役割：
  - Presentation：View（Widget）、ViewModel
  - Domain：Entity、UseCase
  - Data：Repository、DataSource（Firestore等）

## コーディングスタイル
- Dartの公式スタイルガイドに準拠
- 命名規則：
  - クラス名：PascalCase（例：`InventoryViewModel`）
  - メソッド名：camelCase（例：`fetchInventory`）
  - 変数名：camelCase（例：`userInventory`）
- コメント：
  - ドキュメンテーションコメント（`///`）を使用
  - 必要に応じて関数やクラスの説明を記載

## テスト駆動開発（TDD）
- Domain層→Repositoryインターフェース→ViewModelの順でテストを作成
- 外部依存（Firestore、AI、カメラ等）はMock化

## 使用技術
- Firestoreをデータベースとして使用
- Flutterの公式パッケージを優先的に使用
- 依存関係を追加するときは必ず`pubspec.yaml`を参照して検討し、必要に応じて依存関係を`pubspec.yaml`に追加

## その他留意事項
- 仕様があいまいと判断される場合は、逆質問して仕様を固めてからコーディングすること
