import functions_framework
from google.cloud import firestore
from google.cloud import storage
import requests
import os
import logging  # logging を標準で使用
import tempfile
import json
from vertexai.preview.vision_models import ImageGenerationModel
from cloudevents.http import CloudEvent
import base64
from google.protobuf.json_format import MessageToDict
import data_pb2

# 環境変数から取得
GEMINI_API_URL = os.environ.get('GEMINI_API_URL', 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-05-20:generateContent')
GEMINI_API_KEY = os.environ.get('GEMINI_API_KEY')
FIREBASE_STORAGE_BUCKET = os.environ.get("FIREBASE_STORAGE_BUCKET")
# print(f"Attempting to use Firebase Storage Bucket: '{FIREBASE_STORAGE_BUCKET}'") # 環境変数の値を確認
logging.info(f"Attempting to use Firebase Storage Bucket: '{FIREBASE_STORAGE_BUCKET}'")

# クライアント初期化
firestore_client = firestore.Client()
storage_client = storage.Client()


def generate_kana_and_synonyms(name: str, category: str):
    """
    Gemini APIでカナ・同義語・画像説明文を生成
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

    # print(f"[Gemini] Requesting content for: {name}") # print を print に変更
    logging.info(f"[Gemini] Requesting content for: {name}")
    response = requests.post(GEMINI_API_URL, headers=headers, params=params, json=payload, timeout=30)
    response.raise_for_status()

    candidates = response.json().get('candidates', [])
    if not candidates:
        logging.error(f"[Gemini] No candidates returned. Full response: {response.json()}")
        raise Exception('[Gemini] No candidates returned')

    try:
        parts = candidates[0].get('content', {}).get('parts', [])
        if not parts or 'text' not in parts[0]:
            logging.error(f"[Gemini] 'text' not found in response parts. Full candidate: {candidates[0]}")
            raise Exception('[Gemini] Malformed response: text not found in parts')
        
        text = parts[0]['text']
        # print(f"[Gemini] Response text to be parsed: '{text}'") # print を print に変更
        logging.info(f"[Gemini] Response text to be parsed: '{text}'")

        cleaned_text = text.strip()
        if cleaned_text.startswith("```json"):
            cleaned_text = cleaned_text[7:]
        if cleaned_text.startswith("```"):
            cleaned_text = cleaned_text[3:]
        if cleaned_text.endswith("```"):
            cleaned_text = cleaned_text[:-3]
        cleaned_text = cleaned_text.strip()

        # print(f"[Gemini] Cleaned text for JSON parsing: '{cleaned_text}'") # print を print に変更
        logging.info(f"[Gemini] Cleaned text for JSON parsing: '{cleaned_text}'")
        
        if not cleaned_text:
            logging.error("[Gemini] Cleaned text is empty, cannot parse JSON.")
            raise json.JSONDecodeError("Cleaned text is empty", "", 0)

        return json.loads(cleaned_text)
    except json.JSONDecodeError as e:
        logging.error(f"[Gemini] JSONDecodeError: {e}. Raw text was: '{text}'")
        logging.error(f"[Gemini] Full response on JSONDecodeError: {response.json()}")
        raise
    except Exception as e:
        logging.error(f"[Gemini] An unexpected error occurred during text extraction or parsing: {e}")
        logging.error(f"[Gemini] Full response on unexpected error: {response.json()}")
        raise


def generate_image_url(image_prompt: str, doc_id: str) -> str:
    """
    Vertex AIで画像生成し、Firebase StorageにアップロードしてURLを返す
    """
    # print(f"[VertexAI] Generating image for: {image_prompt}") # print を print に変更
    logging.info(f"[VertexAI] Generating image for doc_id='{doc_id}', prompt='{image_prompt}'")
    model = ImageGenerationModel.from_pretrained("imagegeneration@006")

    try:
        response_img = model.generate_images( # response 変数名を response_img に変更 (Gemini APIの response と区別)
            prompt=image_prompt,
            number_of_images=1
        )

        if not response_img or not hasattr(response_img, 'images') or not response_img.images:
            # Log the full response object if images are not found
            logging.error(f"[VertexAI] No images generated or unexpected response structure for doc_id='{doc_id}'. Prompt='{image_prompt}'. Full Vertex AI response object: {response_img}")
            raise Exception(f"[VertexAI] No images generated for doc_id='{doc_id}' (prompt='{image_prompt}')")
        
        image_bytes = response_img.images[0]._image_bytes # Assuming this is the correct way to get bytes

        if not image_bytes:
             logging.error(f"[VertexAI] Image bytes are empty for doc_id='{doc_id}'. Prompt='{image_prompt}'. Image object: {response_img.images[0]}")
             raise Exception(f"[VertexAI] Image bytes are empty for doc_id='{doc_id}' (prompt='{image_prompt}')")

    except Exception as e:
        logging.error(f"[VertexAI] Exception during image generation for doc_id='{doc_id}'. Prompt='{image_prompt}'. Error: {e}", exc_info=True)
        # Re-raise to ensure the function fails as expected.
        # If the original exception was one of our custom ones, re-raise it directly.
        if str(e).startswith("[VertexAI]"):
             raise
        else:
             # Wrap SDK or other unexpected errors for clarity
             raise Exception(f"[VertexAI] SDK or unexpected error for doc_id='{doc_id}'. Original error: {e}") from e

    with tempfile.NamedTemporaryFile(delete=False, suffix=".png") as tmp:
        tmp.write(image_bytes)
        tmp_path = tmp.name
    # print(f"[Storage] Temporary image saved: {tmp_path}") # print を print に変更
    logging.info(f"[Storage] Temporary image saved: {tmp_path}")

    if not FIREBASE_STORAGE_BUCKET:
        logging.error("[Storage] FIREBASE_STORAGE_BUCKET environment variable is not set.")
        raise ValueError("FIREBASE_STORAGE_BUCKET is not set")

    bucket = storage_client.bucket(FIREBASE_STORAGE_BUCKET)
    blob = bucket.blob(f"ingredients/{doc_id}.png")
    blob.upload_from_filename(tmp_path, content_type="image/png")
    blob.make_public()

    # print(f"[Storage] Uploaded image URL: {blob.public_url}") # print を print に変更
    logging.info(f"[Storage] Uploaded image URL: {blob.public_url}")
    return blob.public_url


def decode_firestore_event_data(data):
    if isinstance(data, bytes):
        doc_event = data_pb2.DocumentEventData()
        doc_event.ParseFromString(data)
        return MessageToDict(doc_event)
    if isinstance(data, dict):
        # print("[Decode] data is dict") # print を print に変更
        logging.info("[Decode] data is dict")
        return data
    if isinstance(data, str):
        # print("[Decode] data is str; try json.loads") # print を print に変更
        logging.info("[Decode] data is str; try json.loads")
        try:
            return json.loads(data)
        except Exception as e:
            logging.error(f"[Decode] json.loads error: {e}")
            raise
    logging.error(f"[Decode] Unknown data type: {type(data)}")
    raise ValueError("Unsupported cloud_event.data type")


@functions_framework.cloud_event
def on_create_ingredient_master(cloud_event: CloudEvent):
    # print(f"Received event with ID: {cloud_event['id']} and data {cloud_event.data}") # print を print に変更
    logging.info(f"Received event with ID: {cloud_event['id']}")
    # Log raw event data for deep debugging, adjust level if too verbose for production
    logging.debug(f"Full cloud_event.data for event ID {cloud_event['id']}: {cloud_event.data}")

    doc_id = "unknown_doc_id_at_start" # Initialize for use in except block if extraction fails

    try:
        event_data = decode_firestore_event_data(cloud_event.data)
        # Log the decoded event data to understand its structure
        logging.debug(f"Decoded event_data for event ID {cloud_event['id']}: {json.dumps(event_data)}")

        # Robustly extract doc_id
        try:
            doc_path = event_data['value']['name']
            doc_id = doc_path.split("/")[-1]
        except (KeyError, TypeError, AttributeError, IndexError) as e:
            logging.error(f"Failed to extract doc_id from event_data. Error: {e}. Event data: {json.dumps(event_data)}", exc_info=True)
            return # Stop processing if doc_id cannot be determined

        fields = event_data.get('value', {}).get('fields', {}) # Use .get for safer access
        name = fields.get("name", {}).get("stringValue", "")
        category = fields.get("category", {}).get("stringValue", "")

        # print(f"[Parsed] name={name}, category={category}, doc_id={doc_id}") # print を print に変更
        logging.info(f"[Parsed] name='{name}', category='{category}', doc_id='{doc_id}'")
        
        if not name:
            logging.warning(f"Ingredient name is empty for doc_id: {doc_id}. Skipping further processing.")
            # Optionally, update Firestore with an error status for the document
            # firestore_client.collection('ingredients_master').document(doc_id).update({"processing_error": "Ingredient name was empty"})
            return

        result = generate_kana_and_synonyms(name, category)
        kana = result.get("kana", "")
        synonyms = result.get("synonyms", [])
        image_prompt = result.get("image_prompt", "")
        logging.info(f"For doc_id='{doc_id}', image_prompt from Gemini: '{image_prompt}'")

        image_url = "" # Initialize image_url
        if image_prompt:
            logging.info(f"For doc_id='{doc_id}', attempting to generate image with prompt: '{image_prompt}'")
            # Exceptions from generate_image_url will be caught by the outer try-except block
            image_url = generate_image_url(image_prompt, doc_id)
            logging.info(f"For doc_id='{doc_id}', image generation call completed. Resulting image_url: '{image_url}'")
        else:
            logging.warning(f"Image prompt was empty for doc_id: {doc_id} (name: {name}). No image will be generated.")
        
        logging.info(f"For doc_id='{doc_id}', proceeding to Firestore update. Final image_url value before get: '{image_url}'")

        doc_ref = firestore_client.collection('ingredients_master').document(doc_id)
        
        # === Diagnostic GET before UPDATE ===
        logging.info(f"Checking existence of document: {doc_ref.path}")
        doc_snapshot = doc_ref.get()

        if doc_snapshot.exists:
            logging.info(f"[Firestore] Document {doc_id} exists. Proceeding with update.")
            update_payload = {
                "kana": kana,
                "synonyms": synonyms,
                "imageUrl": image_url
            }
            doc_ref.update(update_payload)
            # print(f"[Firestore] Updated: kana={kana}, synonyms={synonyms}, imageUrl={image_url}") # print を print に変更
            logging.info(f"[Firestore] Successfully updated document {doc_id} with: {json.dumps(update_payload)}")
        else:
            # This is the critical log for the user's reported 404 issue
            logging.error(f"[Firestore] CRITICAL: Document {doc_id} (path: {doc_ref.path}) was NOT FOUND right before update attempt. This is unexpected for an onCreate trigger. The document might have been deleted prematurely, or there's a consistency delay.")
            # If the document is not found, the original update() would have failed with 404.
            # By returning here, we avoid that specific 404 and the subsequent error handling's update attempt.
            return 

    except Exception as e:
        logging.error(f"[Error] Exception during processing for doc_id '{doc_id}': {e}", exc_info=True)
        if doc_id != "unknown_doc_id_at_start":
            try:
                logging.info(f"Error handler: Attempting to get document {doc_id} for error update.") # ADDED
                error_doc_ref = firestore_client.collection('ingredients_master').document(doc_id)
                doc_exists = error_doc_ref.get().exists
                logging.info(f"Error handler: Document {doc_id} exists: {doc_exists}.") # ADDED

                if doc_exists:
                    logging.info(f"Attempting to mark error on document {doc_id} due to exception: {e}")
                    error_update_data = {
                        "processing_error": str(e),
                        "kana": kana if 'kana' in locals() and kana else "", 
                        "synonyms": synonyms if 'synonyms' in locals() and synonyms else [],
                        "imageUrl": image_url if 'image_url' in locals() and image_url else ""
                    }
                    error_doc_ref.update(error_update_data)
                    logging.info(f"Marked error on document {doc_id}: {json.dumps(error_update_data)}")
                else:
                    logging.warning(f"Document {doc_id} not found when attempting to write error status. Original error: {e}")
            except Exception as inner_e:
                logging.error(f"Error handler: Exception during Firestore error update for {doc_id}: {inner_e}", exc_info=True) # MODIFIED
        else:
            logging.error(f"doc_id was '{doc_id}' (not properly extracted), cannot mark error on document. Original error: {e}")
        
        logging.info(f"Error handler: Reached end of main exception block for {doc_id}. Returning.") # ADDED
        return
