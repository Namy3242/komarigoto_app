import functions_framework
from flask import request, jsonify
import os
import requests

# Google Gemini APIのエンドポイントとAPIキー（環境変数で管理）
GEMINI_API_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent"
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY")

@functions_framework.http
def recipe_suggest(request):
    """
    POSTで {"ingredients": ["卵", "トマト", ...]} を受け取り、
    Gemini APIでレシピ案を生成し、JSONで返す。
    """
    try:
        data = request.get_json()
        ingredients = data.get("ingredients", [])
        if not ingredients:
            return jsonify({"error": "ingredients required"}), 400

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
            return jsonify({"error": "Gemini API error", "detail": res.text}), 500
        gemini_data = res.json()
        # Geminiの返答からJSON部分を抽出
        import re, json as pyjson
        text = gemini_data["candidates"][0]["content"]["parts"][0]["text"]
        # JSON配列部分を抽出
        match = re.search(r'\[.*\]', text, re.DOTALL)
        if not match:
            return jsonify({"error": "No recipe JSON found", "raw": text}), 500
        recipes = pyjson.loads(match.group(0))
        return jsonify({"recipes": recipes})
    except Exception as e:
        return jsonify({"error": str(e)}), 500
