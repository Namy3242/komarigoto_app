import functions_framework
from flask import request, jsonify, make_response
import os
import requests

# Google Gemini APIのエンドポイントとAPIキー（環境変数で管理）
GEMINI_API_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-05-20:generateContent"
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY")

@functions_framework.http
def recipe_suggest(request):
    """
    POSTで {"ingredients": ["卵", "トマト", ...]} を受け取り、
    Gemini APIでレシピ案を生成し、JSONで返す。
    CORS対応のため、レスポンスヘッダーにAccess-Control-Allow-Originを付与。
    """
    # OPTIONSメソッド（CORSプリフライト）対応
    if request.method == 'OPTIONS':
        response = make_response()
        response.headers['Access-Control-Allow-Origin'] = '*'
        response.headers['Access-Control-Allow-Methods'] = 'POST, OPTIONS'
        response.headers['Access-Control-Allow-Headers'] = 'Content-Type, X-API-KEY'
        response.headers['Access-Control-Max-Age'] = '3600'
        return response
    try:
        data = request.get_json()
        ingredients = data.get("ingredients", [])
        if not ingredients:
            resp = jsonify({"error": "ingredients required"})
            resp.headers['Access-Control-Allow-Origin'] = '*'
            return resp, 400
        # Geminiへのプロンプト生成
        prompt = f"""
        以下の食材だけを使って作れる家庭料理のレシピを3件、日本語で提案してください。
        食材: {', '.join(ingredients)}
        各レシピはタイトル・説明・材料・手順を含めてJSON配列で返してください。
        例: [{{"title": "○○", "description": "○○", "ingredients": ["○○"], "steps": ["○○"]}}, ...]
        """
        payload = {
            "contents": [{"parts": [{"text": prompt}]}]
        }
        res = requests.post(
            f"{GEMINI_API_URL}?key={GEMINI_API_KEY}",
            json=payload,
            timeout=30
        )
        if res.status_code != 200:
            resp = jsonify({"error": "Gemini API error", "detail": res.text})
            resp.headers['Access-Control-Allow-Origin'] = '*'
            return resp, 500
        gemini_data = res.json()
        # Geminiの返答からJSON部分を抽出
        import re, json as pyjson
        text = gemini_data["candidates"][0]["content"]["parts"][0]["text"]
        match = re.search(r'\[.*\]', text, re.DOTALL)
        if not match:
            resp = jsonify({"error": "No recipe JSON found", "raw": text})
            resp.headers['Access-Control-Allow-Origin'] = '*'
            return resp, 500
        recipes = pyjson.loads(match.group(0))
        resp = jsonify({"recipes": recipes})
        resp.headers['Access-Control-Allow-Origin'] = '*'
        return resp
    except Exception as e:
        resp = jsonify({"error": str(e)})
        resp.headers['Access-Control-Allow-Origin'] = '*'
        return resp, 500

# --- ここからon_create_ingredient_masterのエントリポイントを追加 ---
from on_create_ingredient_master import on_create_ingredient_master
# --- ここまで追加 ---
