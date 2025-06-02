import functions_framework
from cloudevents.http import CloudEvent
import logging
import json
from google.cloud import firestore
from ingredient_master_on_create import decode_firestore_event_data, generate_image_url
import requests
import os

# Firestore client
firestore_client = firestore.Client()

# Gemini API settings (from env or default)
GEMINI_API_URL = os.environ.get('GEMINI_API_URL', 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-05-20:generateContent')
GEMINI_API_KEY = os.environ.get('GEMINI_API_KEY')

def generate_image_prompt(text: str, label: str, title: str) -> str:
    """
    Gemini APIで料理写真向けの英語プロンプトを生成
    """
    if label == 'レシピタイトル':
        prompt = f"以下のレシピタイトルから料理写真に適した英語の画像説明文を生成してください。\n{text}"
    else:
        # 手順や材料などの説明文の場合
        if label.startswith('手順'):
            prompt = f"以下はレシピタイトルが{title}の料理の{label}を示す。適した英語の画像説明文を生成してください。\n{text}"
        else:
            # その他のケース（例：材料）
            # ここでは材料の説明文を想定
            # 例: "以下の材料から料理写真に適した英語の画像説明文を生成してください。"
            prompt = f"以下の{label}から料理写真に適した英語の画像説明文を生成してください。\n{text}"
    payload = {"contents": [{"parts": [{"text": prompt}]}]}
    res = requests.post(f"{GEMINI_API_URL}?key={GEMINI_API_KEY}", json=payload, timeout=30)
    res.raise_for_status()
    cands = res.json().get('candidates', [])
    if not cands:
        raise Exception(f"[Gemini] No prompt candidate for {label}")
    raw = cands[0]['content']['parts'][0]['text']
    cleaned = raw.strip()
    if cleaned.startswith("```json"):
        cleaned = cleaned[6:]
    cleaned = cleaned.strip('```').strip()
    return cleaned

@functions_framework.cloud_event
def on_create_recipe(cloud_event: CloudEvent):
    logging.info(f"Received recipe creation event ID: {cloud_event['id']}")
    try:
        event_data = decode_firestore_event_data(cloud_event.data)
        doc_path = event_data['value']['name']
        doc_id = doc_path.split('/')[-1]
        fields = event_data['value']['fields']
        # タイトル画像生成：まずプロンプトをGeminiで生成
        title = fields.get('title', {}).get('stringValue', '')
        if title:
            title_prompt = generate_image_prompt(title, 'レシピタイトル', title)
            title_image_url = generate_image_url(title_prompt, f"recipe_{doc_id}_title")
        else:
            title_image_url = ''
        # ステップごとの画像生成
        steps_array = fields.get('steps', {}).get('arrayValue', {}).get('values', [])
        step_image_urls = []
        for idx, step in enumerate(steps_array):
            desc = step.get('stringValue', '')
            if not desc:
                continue
            # Geminiでステップ向けの画像プロンプトを生成
            step_prompt = generate_image_prompt(desc, f'手順{idx+1}/{len(steps_array)}', title)
            url = generate_image_url(step_prompt, f"recipe_{doc_id}_step_{idx}")
            step_image_urls.append(url)
        # Firestoreに更新
        recipe_ref = firestore_client.document(doc_path)
        recipe_ref.update({
            'titleImageUrl': title_image_url,
            'stepImageUrls': step_image_urls
        })
        logging.info(f"Recipe {doc_id} images generated and Firestore updated.")
    except Exception as e:
        logging.error(f"Error in on_create_recipe: {e}", exc_info=True)
    return
