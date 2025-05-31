# Cloud Functions for Firebase (Python) デプロイ手順

## 必要なファイル
- main.py（エントリポイント）
- ingredient_master_on_create.py（今回追加したトリガー）
- requirements.txt

## デプロイ前準備
1. Google Cloud SDKインストール＆認証
2. プロジェクトIDの確認
3. Firestore有効化
4. Gemini APIキーの取得＆環境変数設定

## デプロイ手順
1. 必要なパッケージをインストール
   ```sh
   pip install -r requirements.txt
   ```
2. Cloud Functionsデプロイ
   ```sh
   gcloud functions deploy ingredient_master_on_create \
     --runtime python310 \
     --trigger-event providers/cloud.firestore/eventTypes/document.create \
     --trigger-resource "projects/<プロジェクトID>/databases/(default)/documents/ingredients_master/{docId}" \
     --set-env-vars GEMINI_API_KEY=<取得したAPIキー>
   ```
   - <プロジェクトID>はご自身のFirebase/GCPプロジェクトIDに置換してください
   - 必要に応じてGEMINI_API_URLも--set-env-varsで指定可能

## 注意
- Firestoreのingredients_masterに新規追加があると自動でGemini API連携＆追記が行われます
- 失敗時は空値で追記されます
- 画像生成APIを使う場合はgenerate_image_url関数を適宜修正してください

---
何か不明点があればご相談ください。
