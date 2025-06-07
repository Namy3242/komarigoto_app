import requests
import logging
import os
import base64

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

WORDPRESS_URL = os.environ.get('WORDPRESS_URL', 'https://namy-village.com/wp-json/wp/v2/posts')
WORDPRESS_USER = os.environ.get('WORDPRESS_USER', 'nemine')
WORDPRESS_APP_PASSWORD = os.environ.get('WORDPRESS_APP_PASSWORD', 'gIBV zTSm wBEs 0kPo UjBa sWMm')

def test_wordpress_connection():
    if not all([WORDPRESS_URL, WORDPRESS_USER, WORDPRESS_APP_PASSWORD]):
        logging.error('WordPress設定が未定義です')
        return

    headers = {
        'Authorization': 'Basic ' + base64.b64encode(f"{WORDPRESS_USER}:{WORDPRESS_APP_PASSWORD}".encode()).decode(),
        'Content-Type': 'application/json',
    }

    try:
        logging.info('WordPress接続テストを開始します: %s', WORDPRESS_URL)
        response = requests.get(WORDPRESS_URL, headers=headers, timeout=30)
        logging.info('ステータスコード: %d', response.status_code)
        logging.info('レスポンス: %s', response.text[:500])

        if response.status_code == 200:
            logging.info('WordPress接続成功')
        elif response.status_code == 403:
            logging.warning('403 Forbidden: 認証情報を確認してください')
        else:
            logging.error('接続失敗: ステータスコード %d', response.status_code)
    except Exception as e:
        logging.exception('WordPress接続テスト中にエラーが発生しました: %s', e)

if __name__ == '__main__':
    test_wordpress_connection()
