import functions_framework
from google.cloud import firestore
import requests
import os
import logging
from vertexai.preview.generative_models import GenerativeModel
from google.cloud import storage
import tempfile

# Gemini APIのエンドポイントやAPIキーは環境変数で管理
GEMINI_API_URL = os.environ.get('GEMINI_API_URL', 'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent')
GEMINI_API_KEY = os.environ.get('GEMINI_API_KEY')

# Firestoreクライアント初期化
firestore_client = firestore.Client()

def generate_kana_and_synonyms(name: str, category: str):
    """
    Gemini APIでカナ・同義語・画像URLを生成
    """
    prompt = f"""
    以下の食材名について、
    1. カナ表記（ひらがな）
    2. 一般的な同義語（3つ程度、カンマ区切り）
    3. 料理用途に適した画像の説明文（英語）
    をJSONで出力してください。
    食材名: {name}
    カテゴリ: {category}
    出力例: {{"kana": "とまと", "synonyms": ["トマト", "赤い実", "西洋ナス"], "image_prompt": "a fresh red tomato on a white background"}}
    """
    headers = {"Content-Type": "application/json"}
    payload = {
        "contents": [{"parts": [{"text": prompt}]}]
    }
    params = {"key": GEMINI_API_KEY}
    response = requests.post(GEMINI_API_URL, headers=headers, params=params, json=payload, timeout=30)
    response.raise_for_status()
    candidates = response.json().get('candidates', [])
    if not candidates:
        raise Exception('No candidates from Gemini API')
    import json
    text = candidates[0]['content']['parts'][0]['text']
    data = json.loads(text)
    return data

def generate_image_url(image_prompt: str, doc_id: str) -> str:
    """
    Vertex AIで画像生成し、Firebase StorageにアップロードしてURLを返す
    """
    # Vertex AIで画像生成
    model = GenerativeModel("imagegeneration@001")
    responses = model.generate_images(image_prompt)
    image_bytes = responses[0].images[0].bytes  # 画像バイナリ

    # 一時ファイルに保存
    with tempfile.NamedTemporaryFile(delete=False, suffix=".png") as tmp:
        tmp.write(image_bytes)
        tmp_path = tmp.name

    # Firebase Storageにアップロード
    bucket_name = os.environ.get("FIREBASE_STORAGE_BUCKET")  # 例: "your-project-id.appspot.com"
    storage_client = storage.Client()
    bucket = storage_client.bucket(bucket_name)
    blob = bucket.blob(f"ingredients/{doc_id}.png")
    blob.upload_from_filename(tmp_path, content_type="image/png")
    blob.make_public()  # 必要に応じて公開設定

    return blob.public_url

@functions_framework.cloud_event
def ingredient_master_on_create(cloud_event):
    """
    Firestore ingredients_masterコレクションのonCreateトリガー
    """
    value = cloud_event.data["value"]
    fields = value["fields"]
    name = fields["name"]["stringValue"]
    category = fields["category"]["stringValue"]
    doc_id = value["name"].split("/")[-1]
    logging.info(f"Triggered for doc_id={doc_id}, name={name}")
    # Gemini APIで生成
    try:
        result = generate_kana_and_synonyms(name, category)
        kana = result.get("kana", "")
        synonyms = result.get("synonyms", [])
        image_prompt = result.get("image_prompt", "")
        image_url = generate_image_url(image_prompt, doc_id)
        # Firestoreに追記
        firestore_client.collection('ingredients_master').document(doc_id).update({
            "kana": kana,
            "synonyms": synonyms,
            "imageUrl": image_url
        })
        logging.info(f"Updated doc_id={doc_id} with kana/synonyms/imageUrl")
    except Exception as e:
        logging.error(f"Gemini生成失敗: {e}")
        firestore_client.collection('ingredients_master').document(doc_id).update({
            "kana": "",
            "synonyms": [],
            "imageUrl": ""
        })
