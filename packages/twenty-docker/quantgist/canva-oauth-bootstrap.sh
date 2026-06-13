#!/usr/bin/env bash
# Generate Canva OAuth URL (PKCE) and optionally exchange authorization code for tokens.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CANVA_ENV_FILE="${HOME}/.openclaw/credentials/canva-quantgist.env"
PKCE_FILE="${HOME}/.openclaw/credentials/canva-oauth-pkce.json"

usage() {
  cat <<'EOF'
Canva Connect OAuth bootstrap (Authorization Code + PKCE).

Usage:
  bash canva-oauth-bootstrap.sh              # Print authorize URL; saves PKCE verifier
  bash canva-oauth-bootstrap.sh --exchange <code>  # Exchange code for tokens
  bash canva-oauth-bootstrap.sh --refresh    # Refresh access token using stored refresh token

Prerequisites:
  - CANVA_CLIENT_ID + CANVA_CLIENT_SECRET in ~/.openclaw/credentials/canva-quantgist.env
  - Redirect URI registered in Canva developer portal (default: http://127.0.0.1:8765/oauth/canva/callback)
EOF
}

if [[ ! -f "${CANVA_ENV_FILE}" ]]; then
  echo "Missing ${CANVA_ENV_FILE} — run bootstrap-canva-env.sh first" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "${CANVA_ENV_FILE}"

REDIRECT_URI="${CANVA_REDIRECT_URI:-http://127.0.0.1:8765/oauth/canva/callback}"
SCOPES="${CANVA_SCOPES:-design:content:read design:content:write asset:read asset:write brandtemplate:content:read brandtemplate:meta:read}"
AUTH_BASE="${CANVA_AUTH_BASE_URL:-https://www.canva.com/api/oauth}"
API_BASE="${CANVA_API_BASE_URL:-https://api.canva.com/rest/v1}"

generate_pkce() {
  python3 - <<'PY'
import base64
import hashlib
import json
import os
import secrets

verifier = base64.urlsafe_b64encode(secrets.token_bytes(32)).decode("utf-8").rstrip("=")
challenge = base64.urlsafe_b64encode(
    hashlib.sha256(verifier.encode("utf-8")).digest()
).decode("utf-8").rstrip("=")
state = secrets.token_urlsafe(16)
print(json.dumps({"code_verifier": verifier, "code_challenge": challenge, "state": state}))
PY
}

exchange_code() {
  local auth_code="$1"
  if [[ ! -f "${PKCE_FILE}" ]]; then
    echo "Missing ${PKCE_FILE} — run without --exchange first" >&2
    exit 1
  fi
  local code_verifier
  code_verifier="$(python3 -c "import json; print(json.load(open('${PKCE_FILE}'))['code_verifier'])")"
  local basic_auth
  basic_auth="$(printf '%s:%s' "${CANVA_CLIENT_ID}" "${CANVA_CLIENT_SECRET}" | base64 | tr -d '\n')"

  local response
  response="$(curl -sS -X POST "${API_BASE}/oauth/token" \
    -H "Authorization: Basic ${basic_auth}" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    --data-urlencode "grant_type=authorization_code" \
    --data-urlencode "code=${auth_code}" \
    --data-urlencode "code_verifier=${code_verifier}" \
    --data-urlencode "redirect_uri=${REDIRECT_URI}")"

  local access_token refresh_token
  access_token="$(echo "${response}" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('access_token',''))" 2>/dev/null || true)"
  refresh_token="$(echo "${response}" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('refresh_token',''))" 2>/dev/null || true)"

  if [[ -z "${access_token}" ]]; then
    echo "Token exchange failed:" >&2
    echo "${response}" >&2
    exit 1
  fi

  python3 - "${CANVA_ENV_FILE}" "${access_token}" "${refresh_token}" <<'PY'
import re
import sys

path, access, refresh = sys.argv[1:4]
text = open(path).read()

def set_var(name, value):
    global text
    pattern = rf'^{name}=.*$'
    replacement = f'{name}={value}'
    if re.search(pattern, text, flags=re.M):
        text = re.sub(pattern, replacement, text, count=1, flags=re.M)
    else:
        text += f'\n{replacement}\n'

set_var('CANVA_ACCESS_TOKEN', access)
if refresh:
    set_var('CANVA_REFRESH_TOKEN', refresh)
open(path, 'w').write(text)
PY

  chmod 600 "${CANVA_ENV_FILE}"
  bash "${SCRIPT_DIR}/bootstrap-canva-env.sh" >/dev/null
  echo "Tokens saved to ${CANVA_ENV_FILE}"
  echo "Run: bash ${SCRIPT_DIR}/smoke-canva.sh"
}

refresh_tokens() {
  local refresh_token="${CANVA_REFRESH_TOKEN:-}"
  if [[ -z "${refresh_token}" ]]; then
    echo "No CANVA_REFRESH_TOKEN found in ${CANVA_ENV_FILE}" >&2
    exit 1
  fi
  local basic_auth
  basic_auth="$(printf '%s:%s' "${CANVA_CLIENT_ID}" "${CANVA_CLIENT_SECRET}" | base64 | tr -d '\n')"

  local response
  response="$(curl -sS -X POST "${API_BASE}/oauth/token" \
    -H "Authorization: Basic ${basic_auth}" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    --data-urlencode "grant_type=refresh_token" \
    --data-urlencode "refresh_token=${refresh_token}")"

  local access_token new_refresh_token
  access_token="$(echo "${response}" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('access_token',''))" 2>/dev/null || true)"
  new_refresh_token="$(echo "${response}" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('refresh_token',''))" 2>/dev/null || true)"

  if [[ -z "${access_token}" ]]; then
    echo "Token refresh failed:" >&2
    echo "${response}" >&2
    exit 1
  fi

  python3 - "${CANVA_ENV_FILE}" "${access_token}" "${new_refresh_token:-$refresh_token}" <<'PY'
import re
import sys

path, access, refresh = sys.argv[1:4]
text = open(path).read()

def set_var(name, value):
    global text
    pattern = rf'^{name}=.*$'
    replacement = f'{name}={value}'
    if re.search(pattern, text, flags=re.M):
        text = re.sub(pattern, replacement, text, count=1, flags=re.M)
    else:
        text += f'\n{replacement}\n'

set_var('CANVA_ACCESS_TOKEN', access)
set_var('CANVA_REFRESH_TOKEN', refresh)
open(path, 'w').write(text)
PY

  chmod 600 "${CANVA_ENV_FILE}"
  bash "${SCRIPT_DIR}/bootstrap-canva-env.sh" >/dev/null
  echo "Tokens refreshed in ${CANVA_ENV_FILE}"
  echo "Run: bash ${SCRIPT_DIR}/smoke-canva.sh"
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ "${1:-}" == "--exchange" ]]; then
  if [[ -z "${2:-}" ]]; then
    echo "Usage: $0 --exchange <authorization_code>" >&2
    exit 1
  fi
  exchange_code "$2"
  exit 0
fi

if [[ "${1:-}" == "--refresh" ]]; then
  refresh_tokens
  exit 0
fi

PKCE_JSON="$(generate_pkce)"
echo "${PKCE_JSON}" > "${PKCE_FILE}"
chmod 600 "${PKCE_FILE}"

CODE_CHALLENGE="$(echo "${PKCE_JSON}" | python3 -c "import json,sys; print(json.load(sys.stdin)['code_challenge'])")"
STATE="$(echo "${PKCE_JSON}" | python3 -c "import json,sys; print(json.load(sys.stdin)['state'])")"
SCOPE_PARAM="$(python3 -c "import urllib.parse; print(urllib.parse.quote('${SCOPES}'))")"

AUTH_URL="${AUTH_BASE}/authorize?code_challenge=${CODE_CHALLENGE}&code_challenge_method=s256&scope=${SCOPE_PARAM}&response_type=code&client_id=${CANVA_CLIENT_ID}&state=${STATE}&redirect_uri=$(python3 -c "import urllib.parse; print(urllib.parse.quote('${REDIRECT_URI}'))")"

echo "1. Register redirect URI in Canva developer portal:"
echo "   ${REDIRECT_URI}"
echo ""
echo "2. Open this URL in a browser and authorize:"
echo "${AUTH_URL}"
echo ""
echo "3. Option A — auto exchange (recommended):"
echo "   bash ${SCRIPT_DIR}/canva-oauth-callback-server.sh"
echo "   (then open the authorize URL above)"
echo ""
echo "3. Option B — manual: copy the 'code' query param and run:"
echo "   bash ${SCRIPT_DIR}/canva-oauth-bootstrap.sh --exchange '<code>'"
