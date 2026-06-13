#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CANVA_ENV_FILE="${HOME}/.openclaw/credentials/canva-quantgist.env"
PASS=0
FAIL=0

pass() { echo "  OK: $*"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $*" >&2; FAIL=$((FAIL + 1)); }

echo "=== Canva Connect smoke test ==="
echo ""

if [[ ! -f "${CANVA_ENV_FILE}" ]]; then
  fail "Missing ${CANVA_ENV_FILE}"
  echo "Run: bash ${SCRIPT_DIR}/bootstrap-canva-env.sh"
  exit 1
fi

chmod 600 "${CANVA_ENV_FILE}" 2>/dev/null || true
# shellcheck disable=SC1090
source "${CANVA_ENV_FILE}"

if [[ -n "${CANVA_CLIENT_ID:-}" && "${CANVA_CLIENT_ID}" != REPLACE_* ]]; then
  pass "Client ID configured (${#CANVA_CLIENT_ID} chars)"
else
  fail "CANVA_CLIENT_ID missing"
fi

if [[ -n "${CANVA_CLIENT_SECRET:-}" && "${CANVA_CLIENT_SECRET}" != REPLACE_* ]]; then
  pass "Client secret configured (${#CANVA_CLIENT_SECRET} chars)"
else
  fail "CANVA_CLIENT_SECRET missing"
fi

API_BASE="${CANVA_API_BASE_URL:-https://api.canva.com/rest/v1}"

if [[ -z "${CANVA_ACCESS_TOKEN:-}" ]]; then
  fail "No access token — OAuth required"
  echo ""
  echo "Next: bash ${SCRIPT_DIR}/canva-oauth-bootstrap.sh"
  echo "Summary: ${PASS} passed, ${FAIL} failed"
  exit 1
fi

# Introspect token
HTTP_CODE="$(curl -sS -o /tmp/canva-introspect.json -w '%{http_code}' \
  -X POST "${API_BASE}/oauth/introspect" \
  -H "Authorization: Bearer ${CANVA_ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{}' 2>/dev/null || echo '000')"

if [[ "${HTTP_CODE}" == "200" ]]; then
  pass "Token introspect HTTP 200"
  ACTIVE="$(python3 -c "import json; print(json.load(open('/tmp/canva-introspect.json')).get('active', False))" 2>/dev/null || echo 'false')"
  if [[ "${ACTIVE}" == "True" || "${ACTIVE}" == "true" ]]; then
    pass "Access token active"
  else
    fail "Access token not active — refresh or re-run OAuth"
  fi
else
  # Fallback: list user profile / designs endpoint
  HTTP_CODE="$(curl -sS -o /tmp/canva-user.json -w '%{http_code}' \
    -H "Authorization: Bearer ${CANVA_ACCESS_TOKEN}" \
    "${API_BASE}/users/me" 2>/dev/null || echo '000')"
  if [[ "${HTTP_CODE}" == "200" ]]; then
    pass "GET /users/me HTTP 200"
  else
    fail "API auth check failed (HTTP ${HTTP_CODE}) — token may be expired"
    echo "  Next: bash ${SCRIPT_DIR}/canva-oauth-bootstrap.sh --refresh" >&2
    head -c 200 /tmp/canva-user.json 2>/dev/null || true
    echo ""
  fi
fi

rm -f /tmp/canva-introspect.json /tmp/canva-user.json 2>/dev/null || true

echo ""
echo "Summary: ${PASS} passed, ${FAIL} failed"
[[ "${FAIL}" -eq 0 ]]
