#!/usr/bin/env bash
# Minimal HTTP server to capture Canva OAuth redirect and exchange code automatically.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PORT="${CANVA_OAUTH_CALLBACK_PORT:-8765}"
PATH_PREFIX="/oauth/canva/callback"

echo "Listening on http://127.0.0.1:${PORT}${PATH_PREFIX}"
echo "Complete authorization in browser; this server will exchange the code and exit."
echo ""

python3 - "${PORT}" "${PATH_PREFIX}" "${SCRIPT_DIR}/canva-oauth-bootstrap.sh" <<'PY'
import http.server
import sys
import threading
import urllib.parse
import subprocess

port = int(sys.argv[1])
path_prefix = sys.argv[2]
bootstrap = sys.argv[3]

class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        if not parsed.path.startswith(path_prefix):
            self.send_response(404)
            self.end_headers()
            return
        params = urllib.parse.parse_qs(parsed.query)
        code = (params.get("code") or [""])[0]
        error = (params.get("error") or [""])[0]
        if error:
            body = f"<h1>Canva OAuth error</h1><p>{error}</p>"
            status = 400
        elif not code:
            body = "<h1>Missing code</h1>"
            status = 400
        else:
            try:
                subprocess.run(
                    ["bash", bootstrap, "--exchange", code],
                    check=True,
                )
                body = "<h1>Canva OAuth success</h1><p>Tokens saved. You can close this tab.</p>"
                status = 200
                threading.Thread(target=self.server.shutdown, daemon=True).start()
            except subprocess.CalledProcessError as exc:
                body = f"<h1>Exchange failed</h1><pre>{exc}</pre>"
                status = 500
        self.send_response(status)
        self.send_header("Content-Type", "text/html")
        self.end_headers()
        self.wfile.write(body.encode())

    def log_message(self, fmt, *args):
        print(fmt % args)

server = http.server.HTTPServer(("127.0.0.1", port), Handler)
server.serve_forever()
PY
