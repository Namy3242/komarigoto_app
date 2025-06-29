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
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime

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

# Firebase初期化
try:
    firebase_admin.initialize_app()
    db = firestore.client()
    logging.info("Firebase initialized successfully")
except Exception as e:
    logging.error("Firebase initialization failed: %s", e)
    db = None

def generate_blog_content(title: str) -> str:
    """
    Gemini APIでタイトルからSEO対策済みブログ記事をHTMLで生成
    """
    # SEO対策プロンプト（autogenblog2wpを参考に）
    prompt = f"""
あなたは共働き子育て世代をターゲットとしたレシピブログ記事を執筆してください。以下の要素を盛り込み、読者が「いつか作ってみたい！」「今日の献立に役立つ！」と思えるような、役立つ情報満載の記事を生成してください。

プロンプト本文
レシピタイトル案:

{title}

記事の構成要素:

はじめに：共感と導入

共働き子育て世代の「時間がない」「献立に悩む」といった共通の悩みに寄り添う言葉で読者の心を掴む。両学長のような関西弁で。

しかし、たまにはこだわった料理も楽しみたい！というニーズに応えるレシピです。

使用する食材リスト

使用する食材のいろんな場面で活用できる下ごしらえや調理方法

美味しく仕上げるためのひと手間やコツ
調味料の黄金比: 例: 定番の調味料で簡単に味が決まる比率。
ワンランクアップの秘訣: 例: 隠し味、仕上げにかける調味料、盛り付けのポイント。
アレンジレシピの提案: 例: 今回のレシピをベースに、別の食材や調味料で楽しめるバリエーション。

実用的なレシピ提案

読者が「これなら自分にもできる！」「今日の献立に役立つ！」と思えるような、役立つ情報満載の記事を生成してください。

食材の豆知識：賢く美味しく！

栄養面: 例: この食材に含まれる栄養素とその効能（特に子供に良いものなど）。

旬の食材の魅力: 例: 旬の食材を使うメリットや、取り入れ方。

基本的な調理スキル: 例: 炒め物のコツ、煮物の味の染み込ませ方、火加減の調整。

読者が「あるある」と感じるような、日々の育児や料理に関するちょっとしたエピソード。

今回のレシピのポイントを簡潔にまとめる。

読者が料理に対して前向きな気持ちになれるようなメッセージ。

「また次回のレシピでお会いしましょう！」といった締めの言葉。

【出力形式】

・HTML形式（<h2>や<ul>、<li>、<p>、<strong>などのタグを適切に使う）のみで出力してください。
・タイトルは<h1>タグで、各セクションの見出しは<h2>タグで表現してください。
・箇条書きは<ul>と<li>タグを使ってください。
・コードブロックは<pre>タグで囲み、<code>タグを使ってください。
・記事全体を通して、読者が共感しやすいように、親しみやすい口調で書いてください。
・記事の最後には、読者に行動を促すCTA（Call to Action）を含めてください。
・REST APIで自動投稿するため、contentフィールドに直接HTMLを設定できるように回答してください。
・改行や段落もHTMLタグで表現してください。
・説明やマークダウン、HTML以外の出力は不要です。
・出力結果に```html```を含めず回答してください。

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
        
        # 材料判定リクエストの処理
        if data.get('action') == 'judge_ingredients':
            recipe_ingredients = data.get('recipe_ingredients', [])
            stock_ingredients = data.get('stock_ingredients', [])
            
            needed_ingredients = judge_needed_ingredients(recipe_ingredients, stock_ingredients)
            
            resp = jsonify({
                "needed_ingredients": needed_ingredients
            })
            return add_cors_headers(resp)
        
        # リクエストからパラメータ取得
        ingredients = data.get("ingredients", [])
        meal_type = data.get("mealType", "夕食")
        extra_cond = data.get("extraCondition", "")
        generate_blog = data.get("generateBlog", False)  # ブログ記事生成フラグ
        generate_external = data.get("generateExternal", False)  # 在庫外レシピ生成フラグ
        
        # 在庫外レシピ生成の場合は、ingredientsが空でもOK
        if not ingredients and not generate_external:
            resp = jsonify({"error": "ingredients required"})
            return add_cors_headers(resp), 400
        
        # ブログ記事生成の場合
        if generate_blog:
            return handle_blog_generation(ingredients, extra_cond)
        
        # 在庫外レシピ生成の場合
        if generate_external:
            return handle_external_recipe_generation(meal_type, extra_cond)
        
        # レシピ生成の場合（既存の処理）
        return handle_recipe_generation(ingredients, meal_type, extra_cond)
        
    except Exception as e:
        logging.error('メイン処理エラー: %s', e)
        resp = jsonify({"error": "Internal server error", "detail": str(e)})
        return add_cors_headers(resp), 500
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
            
        # レシピ生成は完了しているので、すぐにレスポンスを返す
        resp = jsonify({"recipes": recipes})
        
        # ブログ投稿は非同期で処理（レスポンスをブロックしない）
        titles = [recipe.get('title') for recipe in recipes if recipe.get('title')]
        if titles:
            import threading
            def async_blog_posting():
                logging.info('ブログ自動投稿（非同期）: %s 件', len(titles))
                try:                
                    logging.info('ブログ記事データ生成を開始します')
                    bulk_post_data = [generate_blog_content(titles[0])]
                    logging.info('ブログ記事データ生成完了: %d件', len(bulk_post_data))
                    
                    # 既存のブログ投稿処理...
                    for post_data in bulk_post_data:
                        if isinstance(post_data, str):
                            post_data = {"title": titles[0], "content": post_data, "status": "publish"}
                        
                        # WordPress投稿とFirestore保存
                        post_to_wordpress(post_data)
                        save_post_to_firestore(post_data)
                        
                except Exception as e:
                    logging.error('非同期ブログ投稿エラー: %s', e)
            
            thread = threading.Thread(target=async_blog_posting)
            thread.start()
        
        return add_cors_headers(resp)
        
    except Exception as e:
        logging.error('レシピ生成エラー: %s', e)
        resp = jsonify({"error": "Recipe generation failed", "detail": str(e)})
        return add_cors_headers(resp), 500

def post_to_wordpress_blog(title, content):
    """
    簡略化されたWordPress投稿関数
    """
    post_data = {
        "title": title,
        "content": content,
        "status": "publish"
    }
    return post_to_wordpress(post_data)

def save_post_to_firestore(post_data: dict) -> bool:
    """
    投稿データをFirestoreに保存
    """
    if db is None:
        logging.error("Firestore client is not initialized")
        return False
    
    try:
        # よみもの記事用のドキュメントデータを準備
        yomimono_data = {
            'title': post_data.get('title', '無題'),
            'content': post_data.get('content', ''),
            'excerpt': post_data.get('excerpt', ''),
            'status': post_data.get('status', 'publish'),
            'date': datetime.now(),
            'author': '料理AI',
            'categories': post_data.get('categories', ['レシピ']),
            'tags': post_data.get('tags', []),
            'featured_media': post_data.get('featured_media', ''),
            'created_at': firestore.SERVER_TIMESTAMP,
            'updated_at': firestore.SERVER_TIMESTAMP
        }
        
        # Firestoreの'yomimono'コレクションに保存
        doc_ref = db.collection('yomimono').add(yomimono_data)
        logging.info("Yomimono data saved to Firestore with ID: %s", doc_ref[1].id)
        return True
        
    except Exception as e:
        logging.error("Failed to save post to Firestore: %s", e)
        return False

# --- ここからon_create_ingredient_masterのエントリポイントを追加 ---
from ingredient_master_on_create import on_create_ingredient_master
from recipe_on_create import on_create_recipe
# --- ここまで追加 ---

def clean_html_content(content: str) -> str:
    """
    HTMLコンテンツから余計なマークダウン記号を削除
    """
    if not isinstance(content, str):
        return content
    
    # 冒頭の ```html を削除
    if content.strip().startswith('```html'):
        content = content.strip()[7:].strip()
    
    # 末尾の ``` を削除
    if content.strip().endswith('```'):
        content = content.strip()[:-3].strip()
    
    return content

def handle_blog_generation(ingredients, extra_cond):
    """
    食材情報を使ってブログ記事を生成し、FirestoreとWordPressに投稿
    """
    try:
        # 食材を使ったブログ記事のプロンプト生成
        prompt = f"""
以下の食材を使った料理に関するブログ記事を日本語で作成してください。
在庫食材: {', '.join(ingredients)}
"""
        if extra_cond:
            prompt += f"テーマ・条件: {extra_cond}\n"
        
        prompt += """
共働き子育て世代をターゲットとして、以下の要素を含む魅力的なブログ記事を生成してください：
読者が共感しやすいように、親しみやすい口調で書いてください。

1. 親しみやすいタイトル（30文字程度）
2. 使用する食材リスト（在庫食材から選択）
3. 使用する食材のいろんな場面で活用できる下ごしらえや調理方法
4. 美味しく仕上げるためのひと手間やコツ
5. 実用的なレシピ提案

【重要：レシピ提案の制約】
- 材料名は必ず上記の「在庫食材」から正確に選択してください
- 材料名の表記は在庫リストと完全に一致するか、以下のような同義語を使用してください：
  * 「豚肉」「豚バラ肉」「豚こま切れ」→すべて「豚肉」系として表記統一
  * 「ニンジン」「人参」「にんじん」→「ニンジン」で統一
  * 「ジャガイモ」「じゃがいも」「馬鈴薯」→「ジャガイモ」で統一
- 調味料（醤油、塩、胡椒、みりん、酒、砂糖、油など）は在庫にあるものとして使用可能
- 水も自由に使用可能

読者が「これなら自分にもできる！」「今日の献立に役立つ！」と思えるような、役立つ情報満載の記事を生成してください。

HTML形式で出力し、以下のタグを適切に使用してください：
- <h1>タイトル</h1>
- <h2>見出し</h2>
- <p>段落</p>
- <ul><li>箇条書き</li></ul>
- <strong>強調</strong>

説明やマークダウン、HTML以外の出力は不要です。
出力結果に```html```を含めず回答してください。
"""
        
        payload = {"contents": [{"parts": [{"text": prompt}]}]}
        
        logging.info('ブログ記事生成開始: 食材=%s', ingredients)
        res = requests.post(f"{GEMINI_API_URL}?key={GEMINI_API_KEY}", json=payload, timeout=120)
        res.raise_for_status()
        
        gemini_data = res.json()
        html_content = gemini_data["candidates"][0]["content"]["parts"][0]["text"].strip()
        
        # タイトルを抽出
        title_match = re.search(r'<h1>(.*?)</h1>', html_content)
        title = title_match.group(1) if title_match else f"食材活用レシピ - {', '.join(ingredients[:3])}"
        
        # Firestoreに保存
        if db:
            doc_ref = db.collection('yomimono').document()
            doc_ref.set({
                'title': title,
                'content': html_content,
                'ingredients': ingredients,
                'created_at': datetime.now(),
                'status': 'published'
            })
            logging.info('ブログ記事をFirestoreに保存完了: %s', title)
        
        # WordPressに非同期投稿
        import threading
        def async_wordpress_posting():
            try:
                post_to_wordpress_blog(title, html_content)
            except Exception as e:
                logging.error('WordPress投稿エラー: %s', e)
        
        thread = threading.Thread(target=async_wordpress_posting)
        thread.start()
        
        resp = jsonify({"message": "Blog post generated successfully", "title": title})
        return add_cors_headers(resp)
        
    except Exception as e:
        logging.error('ブログ記事生成エラー: %s', e)
        resp = jsonify({"error": "Blog generation failed", "detail": str(e)})
        return add_cors_headers(resp), 500

def handle_external_recipe_generation(meal_type, extra_cond):
    """
    在庫外レシピ生成処理（新しい食材を使用）
    """
    # Geminiへのプロンプト生成（在庫外レシピ用）
    prompt = f"""
以下の食事タイプに合う新しいレシピを、一般的な食材を使って1件、日本語で提案してください。
食事タイプ: {meal_type}
"""
    if extra_cond:
        prompt += f"追加条件: {extra_cond}\n"
    
    prompt += (
        "【重要な制約】\n"
        "・一般的なスーパーで購入できる食材を使用してください。\n"
        "・材料名は具体的で分かりやすく記載してください（例：「豚バラ肉」「キャベツ」「人参」など）。\n"
        "・基本的な調味料（醤油、塩、胡椒、みりん、酒、砂糖、油など）も含めてください。\n"
        "・新しい食材や普段使わない食材を積極的に取り入れてください。\n"
        "・材料は5-8種類程度で、作りやすいレシピにしてください。\n"
        "\n"
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
        "手順は3-6ステップくらいで詳しく記載してください。\n"
        "説明やマークダウン、JSON以外の出力は不要です。"
    )
    
    payload = {
        "contents": [{"parts": [{"text": prompt}]}]
    }
    
    logging.info('Gemini APIリクエスト送信: 在庫外レシピ生成, 食事タイプ=%s', meal_type)
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
    print('Gemini APIレスポンス:', text)  # デバッグ用
    match = re.search(r'\[.*\]', text, re.DOTALL)
    if not match:
        logging.error('Geminiレスポンスから有効なJSONが見つかりません: %s', text[:300])
        resp = jsonify({"error": "No recipe JSON found", "raw": text[:500]})
        return add_cors_headers(resp), 500
        
    json_text = match.group(0)
    try:
        recipes = pyjson.loads(json_text)
        logging.info('在庫外レシピJSON解析成功: %d件のレシピを取得', len(recipes))
    except pyjson.JSONDecodeError as json_err:
        logging.error('在庫外レシピJSONの解析に失敗: %s, JSON: %s', json_err, json_text[:300])
        resp = jsonify({"error": "Invalid recipe JSON", "raw": json_text[:500]})
        return add_cors_headers(resp), 500
        
    # 在庫外レシピ生成完了
    resp = jsonify({"recipes": recipes})
    return add_cors_headers(resp)

def handle_recipe_generation(ingredients, meal_type, extra_cond):
    """
    既存のレシピ生成処理
    """
    # Geminiへのプロンプト生成
    prompt = f"""
以下の食事タイプに合うレシピを、在庫食材のみで1件、日本語で提案してください。
食事タイプ: {meal_type}
"""
    if extra_cond:
        prompt += f"追加条件: {extra_cond}\n"
    prompt += f"利用可能な食材: {', '.join(ingredients)}\n"
    prompt += (
        "【重要な制約】\n"
        "・材料名は必ず上記の「利用可能な食材」から選択してください。\n"
        "・材料名は正確に一致させるか、以下のような表記方法で記載してください：\n"
        "  - 「豚肉」→「豚肉」「豚バラ肉」「豚こま切れ」など具体的に\n"
        "  - 「ニンジン」→「ニンジン」「人参」「にんじん」など表記を統一\n"
        "  - 「ジャガイモ」→「ジャガイモ」「じゃがいも」「馬鈴薯」など\n"
        "・調味料（醤油、塩、胡椒、みりん、酒、砂糖、油など）は在庫にあるものとして使用可能です。\n"
        "・水も自由に使用可能です。\n"
        "\n"
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
        "材料の表記は在庫リストの表記と完全に一致するか、同義語・略称を使用してください。\n"
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
        
    # レシピ生成は完了しているので、すぐにレスポンスを返す
    resp = jsonify({"recipes": recipes})
    
    # ブログ投稿は非同期で処理（レスポンスをブロックしない）
    titles = [recipe.get('title') for recipe in recipes if recipe.get('title')]
    if titles:
        import threading
        def async_blog_posting():
            logging.info('ブログ自動投稿（非同期）: %s 件', len(titles))
            try:                
                logging.info('ブログ記事データ生成を開始します')
                bulk_post_data = [generate_blog_content(titles[0])]
                logging.info('ブログ記事データ生成完了: %d件', len(bulk_post_data))
                
                # WordPress投稿とFirestore保存
                for post_data in bulk_post_data:
                    if isinstance(post_data, str):
                        post_data = {"title": titles[0], "content": post_data, "status": "publish"}
                    
                    # WordPress投稿とFirestore保存
                    post_to_wordpress(post_data)
                    save_post_to_firestore(post_data)
                    
            except Exception as e:
                logging.error('非同期ブログ投稿エラー: %s', e)
        
        thread = threading.Thread(target=async_blog_posting)
        thread.start()
    
    return add_cors_headers(resp)

def judge_needed_ingredients(recipe_ingredients, stock_ingredients):
    """
    Gemini AIを使って、レシピに必要な材料のうち在庫にないものを判定する
    """
    prompt = f"""
あなたは料理の専門家です。以下のレシピ材料リストと現在の在庫リストを比較して、
在庫にない材料（購入が必要な材料）のみを抽出してください。

【レシピに必要な材料】
{', '.join(recipe_ingredients)}

【現在の在庫】
{', '.join(stock_ingredients)}

【判定ルール】
1. 調味料（塩、砂糖、醤油、みそ、酢、油、胡椒、にんにく、生姜など）は在庫にあるものとして扱う
2. 水、湯も在庫にあるものとして扱う
3. 材料名の表記揺れ、同義語、部分一致を考慮する
   例：「豚肉」と「豚バラ肉」、「人参」と「ニンジン」、「じゃがいも」と「ジャガイモ」
4. 基本的な材料（ご飯、パン、卵など）で在庫にある場合は除外する
5. 【重要】個数・数量・単位を除いた食材名のみを抽出する
   例：「豚肉200g」→「豚肉」、「玉ねぎ1個」→「玉ねぎ」、「人参2本」→「人参」
   除外する表現：g、kg、ml、l、個、本、枚、袋、パック、切れ、片、房、束、株、玉など

購入が必要な材料のみを、個数・数量・単位を除いた食材名で、以下のJSON配列形式で出力してください：
["材料名1", "材料名2", ...]

説明やマークダウン、JSON以外の出力は不要です。
"""
    
    payload = {
        "contents": [{"parts": [{"text": prompt}]}]
    }
    
    try:
        res = requests.post(
            f"{GEMINI_API_URL}?key={GEMINI_API_KEY}",
            json=payload,
            timeout=60
        )
        
        if res.status_code != 200:
            logging.error('Gemini API材料判定エラー: %s', res.text)
            return recipe_ingredients  # エラー時は全材料を返す
            
        gemini_data = res.json()
        text = gemini_data["candidates"][0]["content"]["parts"][0]["text"]
        
        # JSON部分を抽出
        match = re.search(r'\[.*\]', text, re.DOTALL)
        if not match:
            logging.error('材料判定レスポンスからJSONが見つかりません: %s', text)
            return recipe_ingredients
            
        json_text = match.group(0)
        needed_ingredients = pyjson.loads(json_text)
        
        logging.info('材料判定結果: %d個の材料が必要', len(needed_ingredients))
        return needed_ingredients
        
    except Exception as e:
        logging.error('材料判定処理でエラー: %s', e)
        return recipe_ingredients  # エラー時は全材料を返す
