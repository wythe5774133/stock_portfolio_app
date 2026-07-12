# -*- coding: utf-8 -*-
# 開發用 CORS 代理：模擬 Cloudflare Worker 的路徑格式 /{host}/{path}?query
# 僅供本機測試網頁版，正式環境用 worker/yahoo-proxy.js
import http.server, urllib.request, urllib.error, ssl

# 本機 Python 可能缺 CA bundle；開發代理允許略過驗證（僅限本機測試）
try:
    import certifi
    SSL_CTX = ssl.create_default_context(cafile=certifi.where())
except ImportError:
    SSL_CTX = ssl._create_unverified_context()

ALLOWED = {'query1.finance.yahoo.com', 'query2.finance.yahoo.com'}
UA = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36'

class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        parts = self.path.lstrip('/').split('/', 1)
        host = parts[0]
        if host not in ALLOWED or len(parts) < 2:
            self.send_response(404); self.end_headers(); return
        url = f'https://{host}/{parts[1]}'
        req = urllib.request.Request(url, headers={'User-Agent': UA})
        try:
            with urllib.request.urlopen(req, timeout=15, context=SSL_CTX) as r:
                body = r.read(); code = r.status
                ctype = r.headers.get('Content-Type', 'application/json')
        except urllib.error.HTTPError as e:
            body = e.read(); code = e.code; ctype = 'text/plain'
        except Exception:
            body = b''; code = 502; ctype = 'text/plain'
        self.send_response(code)
        self.send_header('Content-Type', ctype)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(body)
    def log_message(self, *a): pass

http.server.ThreadingHTTPServer(('127.0.0.1', 8787), Handler).serve_forever()
