import functions_framework
from flask import request, jsonify, make_response
import os
import requests
import logging
import re
import json as pyjson
import traceback
from typing import List
import sys
import base64

# ログのフォーマットを設定して、エンコーディングの問題に対応
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[logging.StreamHandler(sys.stdout)]
)

# Google Gemini APIのエンドポイントとAPIキー（環境変数で管理）
GEMINI_API_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-05-20:generateContent"
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY")

# .envから環境変数を読み込む
# WordPress 投稿設定 (環境変数から)  
WORDPRESS_URL = os.environ.get('WORDPRESS_URL')  
WORDPRESS_USER = os.environ.get('WORDPRESS_USER')  
WORDPRESS_APP_PASSWORD = os.environ.get('WORDPRESS_APP_PASSWORD')  

def generate_blog_content(title: str) -> str:
    """
    Gemini APIでタイトルからSEO対策済みブログ記事をHTMLで生成
    """
    # SEO対策プロンプト（autogenblog2wpを参考に）
    prompt = f"""
【プロンプト例】
今日は「 {title}」について、料理ブロガー向けの収益化記事を作成してください。

ターゲット：忙しい共働き夫婦（30-40代）
悩み：時短で美味しい夕食を作りたい
収益目標：1記事あたり月1000円
アフィリエイト商品：３点含める

記事構成：
1. 導入（悩み共感）→ 300文字
2. 基本レシピ → 800文字
3. 時短テクニック → 600文字
4. 失敗しないコツ → 500文字
5. アレンジ3選 → 600文字
6. おすすめ商品紹介 → 400文字
7. まとめ → 200文字

各セクションで自然にアフィリエイト商品を紹介し、読者の購買意欲を高める文章にしてください。

【出力形式】

・HTML形式（<h2>や<ul>、<li>、<p>、<strong>などのタグを適切に使う）のみで出力してください。
・タイトルは<h1>タグで、各セクションの見出しは<h2>タグで表現してください。
・アフィリエイト商品は<strong>タグで強調し、リンクは<a>タグで設定してください。
・箇条書きは<ul>と<li>タグを使ってください。
・コードブロックは<pre>タグで囲み、<code>タグを使ってください。
・画像は<img>タグで挿入し、alt属性を設定してください。
・SEO対策のため、キーワードは太字（<strong>）で強調してください。
・記事全体を通して、読者が共感しやすいように、親しみやすい口調で書いてください。
・記事の最後には、読者に行動を促すCTA（Call to Action）を含めてください。
・REST APIで自動投稿するため、contentフィールドに直接HTMLを設定できるように回答してください。
・改行や段落もHTMLタグで表現してください。

"""
    payload = {"contents": [{"parts": [{"text": prompt}]}]}
    response = requests.post(f"{GEMINI_API_URL}?key={GEMINI_API_KEY}", json=payload, timeout=120)
    response.raise_for_status()
    result = response.json()
    text = result["candidates"][0]["content"]["parts"][0]["text"]
    return text.strip()

def generate_bulk_post_data(titles: List[str]) -> List[dict]:
    """
    複数のタイトルから一括で投稿データを生成し返します
    生成項目: title, slug, meta_description, tags, content
    """
    prompt = "以下のJSON配列形式で出力してください。余計な説明やマークダウンは不要です。\n[\n"
    for t in titles:
        prompt += f'  {{"title": "{t}"}},\n'
    prompt += "]\n各要素に以下のフィールドを含めてください: title, slug, meta_description, tags, content\n"
    payload = {"contents": [{"parts": [{"text": prompt}]}]}
    try:
        logging.info('Gemini API 一括投稿データ生成開始: %d件', len(titles))
        res = requests.post(f"{GEMINI_API_URL}?key={GEMINI_API_KEY}", json=payload, timeout=120)
        res.raise_for_status()
        text = res.json()["candidates"][0]["content"]["parts"][0]["text"]
        logging.info('Gemini API レスポンス長: %d文字', len(text))
    except Exception as e:
        logging.exception('Gemini API 呼び出し例外: %s', e)
        raise
    match = re.search(r"\[[\s\S]*\]", text)
    json_text = match.group(0) if match else text
    try:
        data = pyjson.loads(json_text)
        logging.info('一括投稿データ生成成功: %d件', len(data))
        return data
    except pyjson.JSONDecodeError as e:
        logging.error('JSON解析エラー: %s, text: %s', e, json_text[:500])
        raise

def post_to_wordpress(post_data: dict) -> bool:
    """
    WordPressに記事を投稿
    """
    if not all([WORDPRESS_URL, WORDPRESS_USER, WORDPRESS_APP_PASSWORD]):
        logging.error('WordPress設定が未定義です')
        return False

    api_url = WORDPRESS_URL
    if not api_url.endswith('/posts'):
        if not api_url.endswith('/'):
            api_url += '/'
        if not api_url.endswith('wp-json/wp/v2/posts'):
            if 'wp-json/wp/v2' in api_url:
                api_url = api_url.rstrip('/') + '/posts'
            else:
                api_url = api_url.rstrip('/') + '/wp-json/wp/v2/posts'

    # 投稿内容を修正
    # 追加項目を生成AIで作成
    slug = post_data.get('title', '無題').lower().replace(' ', '-')
    excerpt = post_data.get('content', '').split('.')[0]  # 最初の文を抜粋として使用
    categories = [1]  # 仮のカテゴリーID

    # タグ関連の処理を削除
    payload = {
        "title": post_data.get('title', '無題'),
        "content": post_data.get('content', 'デフォルトの投稿内容です。'),
        "status": post_data.get('status', 'publish'),
        # "tag": 'recipe',
        # "categories": ['cook'],
    }

    headers = {
        'Authorization': 'Basic ' + base64.b64encode(f"{WORDPRESS_USER}:{WORDPRESS_APP_PASSWORD}".encode()).decode(),
        'Content-Type': 'application/json',
    }

    try:
        logging.info('WordPress投稿開始: %s', post_data.get('title'))
        res = requests.post(api_url, auth=(WORDPRESS_USER, WORDPRESS_APP_PASSWORD), json=payload, timeout=120)

        # 詳細なレスポンスログを追加
        logging.info('レスポンスステータスコード: %d', res.status_code)
        logging.info('レスポンスヘッダー: %s', res.headers)
        logging.info('レスポンス内容: %s', res.text[:500])

        if res.status_code in (200, 201):
            logging.info('WordPress投稿成功: %s', post_data.get('title'))
            return True
        else:
            logging.error('WordPress投稿エラー: ステータスコード %d, レスポンス: %s', res.status_code, res.text[:500])
            return False
    except Exception as e:
        logging.exception('WordPress投稿例外: %s', e)
        return False

def test_wordpress_connection():
    """
    WordPress接続テストを行い、接続成功時にログを記録します。
    """
    if not all([WORDPRESS_URL, WORDPRESS_USER, WORDPRESS_APP_PASSWORD]):
        logging.error('WordPress設定が未定義です')
        return False

    headers = {
        'Authorization': 'Basic ' + base64.b64encode(f"{WORDPRESS_USER}:{WORDPRESS_APP_PASSWORD}".encode()).decode(),
        'Content-Type': 'application/json',
    }

    try:
        logging.info('WordPress接続テストを開始します: %s', WORDPRESS_URL)
        response = requests.get(WORDPRESS_URL, headers=headers, timeout=120)
        logging.info('ステータスコード: %d', response.status_code)
        logging.info('レスポンス: %s', response.text[:500])

        if response.status_code == 200:
            logging.info('WordPress接続成功')
            return True
        elif response.status_code == 403:
            logging.warning('403 Forbidden: 認証情報を確認してください')
            return False
        else:
            logging.error('接続失敗: ステータスコード %d', response.status_code)
            return False
    except Exception as e:
        logging.exception('WordPress接続テスト中にエラーが発生しました: %s', e)
        return False

def add_cors_headers(response):
    response.headers['Access-Control-Allow-Origin'] = '*'
    response.headers['Access-Control-Allow-Methods'] = 'POST, OPTIONS'
    response.headers['Access-Control-Allow-Headers'] = 'Content-Type, X-API-KEY'
    response.headers['Access-Control-Max-Age'] = '3600'
    return response

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
        return add_cors_headers(response)
    try:
        data = request.get_json()
        # リクエストからパラメータ取得
        ingredients = data.get("ingredients", [])
        meal_type = data.get("mealType", "夕食")
        extra_cond = data.get("extraCondition", "")
        if not ingredients:
            resp = jsonify({"error": "ingredients required"})
            return add_cors_headers(resp), 400
        # Geminiへのプロンプト生成
        prompt = f"""
以下の食事タイプに合うレシピを、在庫食材のみで3件、日本語で提案してください。
食事タイプ: {meal_type}
"""
        if extra_cond:
            prompt += f"追加条件: {extra_cond}\n"
        prompt += f"食材: {', '.join(ingredients)}\n"
        prompt += (
            "必ず以下の英語キーでJSON配列として出力してください。\n"
            "[\n"
            "  {\n"
            "    \"title\": string,\n"
            "    \"description\": string,\n"
            "    \"ingredients\": string[] または string の配列,\n"
            "    \"steps\": string[] または string の配列\n"
            "  }, ...\n"
            "]\n"
            "日本語で内容を記述し、キーは必ず英語（title, description, ingredients, steps）で統一してください。\n"
            "手順は2-5ステップくらいで時短を意識したものとしてください。\n"
            "説明やマークダウン、JSON以外の出力は不要です。"
        )
        
        payload = {
            "contents": [{"parts": [{"text": prompt}]}]
        }
        
        logging.info('Gemini APIリクエスト送信: 食材=%s', ingredients)
        res = requests.post(
            f"{GEMINI_API_URL}?key={GEMINI_API_KEY}",
            json=payload,
            timeout=120
        )
        logging.info('Gemini APIレスポンス: ステータスコード=%d, Content-Type=%s',
                   res.status_code, res.headers.get('Content-Type'))
        
        if res.status_code != 200:
            error_msg = res.text[:500] if res.text else '[レスポンス内容なし]'
            logging.error('Gemini APIエラー: %s', error_msg)
            resp = jsonify({"error": "Gemini API error", "detail": error_msg})
            return add_cors_headers(resp), 500
            
        gemini_data = res.json()
        # Geminiの返答からJSON部分を抽出
        text = gemini_data["candidates"][0]["content"]["parts"][0]["text"]
        logging.info('Gemini APIレスポンス長: %d文字, プレビュー: %s', 
                   len(text), text[:100].replace('\n', ' '))
        print('Gemini APIレスポンス:', text)  # デバッグ用に最初の300文字を表示
        match = re.search(r'\[.*\]', text, re.DOTALL)
        if not match:
            logging.error('Geminiレスポンスから有効なJSONが見つかりません: %s', text[:300])
            resp = jsonify({"error": "No recipe JSON found", "raw": text[:500]})
            return add_cors_headers(resp), 500
            
        json_text = match.group(0)
        try:
            recipes = pyjson.loads(json_text)
            logging.info('レシピJSON解析成功: %d件のレシピを取得', len(recipes))
        except pyjson.JSONDecodeError as json_err:
            logging.error('レシピJSONの解析に失敗: %s, JSON: %s', json_err, json_text[:300])
            resp = jsonify({"error": "Invalid recipe JSON", "raw": json_text[:500]})
            return add_cors_headers(resp), 500
        # ブログ自動投稿
        titles = [recipe.get('title') for recipe in recipes if recipe.get('title')]
        if titles:
            logging.info('ブログ自動投稿: %s 件', len(titles))
            try:                
                logging.info('ブログ記事データ生成を開始します')
                bulk_post_data = [generate_blog_content([titles[0]])]
                logging.info('ブログ記事データ生成完了: %d件', len(bulk_post_data))
                ##print('生成されたブログ記事データ:', bulk_post_data[:3])  # 最初の3件を表示
                # レスポンス結果を表示するプログレスバー
                total_posts = len(bulk_post_data)
                success_count = 0
                fail_count = 0
                
                # 修正: bulk_post_dataの要素が文字列の場合に対応
                for i, post_data in enumerate(bulk_post_data):
                    if isinstance(post_data, str):
                        post_data = {"title": titles[0], "content": post_data, "status": "publish"}
                    post_title = post_data.get('title', '無題')
                    logging.info('[%d/%d] 記事「%s」を投稿中...', i+1, total_posts, post_title)
                    
                    # WordPress投稿を試行
                    success = post_to_wordpress(post_data)
                    
                    if success:
                        success_count += 1
                        logging.info('✅ WordPress投稿成功: %s', post_title)
                    else:
                        fail_count += 1
                        logging.error('❌ WordPress投稿失敗: %s', post_title)
                
                # 投稿結果のサマリーを出力
                logging.info('投稿結果サマリー: 成功=%d件, 失敗=%d件, 合計=%d件', 
                           success_count, fail_count, total_posts)
            except Exception as e:
                logging.exception('ブログ投稿エラー: %s', e)
        resp = jsonify({"recipes": recipes})
        return add_cors_headers(resp)
    except Exception as e:
        logging.exception("Unhandled exception in recipe_suggest")
        tb = traceback.format_exc()
        resp = jsonify({"error": str(e), "trace": tb})
        return add_cors_headers(resp), 500

# --- ここからon_create_ingredient_masterのエントリポイントを追加 ---
from ingredient_master_on_create import on_create_ingredient_master
from recipe_on_create import on_create_recipe
# --- ここまで追加 ---
