import functions_framework
from cloudevents.http import CloudEvent
import logging
import json
from google.cloud import firestore
from ingredient_master_on_create import decode_firestore_event_data, generate_image_url

# Firestore client
firestore_client = firestore.Client()

@functions_framework.cloud_event
def on_create_recipe(cloud_event: CloudEvent):
    logging.info(f"Received recipe creation event ID: {cloud_event['id']}")
    try:
        event_data = decode_firestore_event_data(cloud_event.data)
        doc_path = event_data['value']['name']
        doc_id = doc_path.split('/')[-1]
        fields = event_data['value']['fields']
        # タイトル画像生成
        title = fields.get('title', {}).get('stringValue', '')
        title_prompt = title
        title_image_url = generate_image_url(title_prompt, f"recipe_{doc_id}_title")
        # ステップごとの画像生成
        steps_array = fields.get('steps', {}).get('arrayValue', {}).get('values', [])
        step_image_urls = []
        for idx, step in enumerate(steps_array):
            desc = step.get('stringValue', '')
            if not desc:
                continue
            prompt = desc
            url = generate_image_url(prompt, f"recipe_{doc_id}_step_{idx}")
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
