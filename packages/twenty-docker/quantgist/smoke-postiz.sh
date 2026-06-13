#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INTEGRATIONS_FILE="${SCRIPT_DIR}/integrations.json"
FAILURES=0

fail() { echo "  ✗ FAIL: $1" >&2; FAILURES=$((FAILURES + 1)); }
pass() { echo "  ✓ OK: $1"; }

# shellcheck disable=SC1090
source "${SCRIPT_DIR}/bootstrap-postiz-env.sh" >/dev/null

POSTIZ_UI_URL="${POSTIZ_API_URL%/api}"

echo "=== QuantGist Postiz Smoke Test ==="
echo "$(date -u +%FT%TZ)"
echo ""

HTTP_UI=$(curl -s -o /dev/null -w "%{http_code}" --max-time 15 "${POSTIZ_UI_URL}/" 2>/dev/null || echo "000")
if [[ "${HTTP_UI}" =~ ^[23] ]]; then
  pass "Postiz UI ${POSTIZ_UI_URL} → HTTP ${HTTP_UI}"
else
  fail "Postiz UI ${POSTIZ_UI_URL} → HTTP ${HTTP_UI}"
fi

HTTP_API=$(curl -s -o /dev/null -w "%{http_code}" --max-time 15 \
  "${POSTIZ_API_URL}/auth/can-register" 2>/dev/null || echo "000")
if [[ "${HTTP_API}" == "200" ]]; then
  pass "Postiz API ${POSTIZ_API_URL}/auth/can-register → HTTP 200"
else
  fail "Postiz API can-register → HTTP ${HTTP_API}"
fi

if command -v postiz >/dev/null 2>&1; then
  INTEGRATIONS_JSON="$(postiz integrations:list 2>/dev/null || true)"
  if [[ -n "${INTEGRATIONS_JSON}" ]]; then
    pass "postiz integrations:list succeeded"
    X_ID="$(python3 -c "import json,sys; d=json.loads(sys.stdin.read().split('Connected Integrations:')[-1].strip() or '[]'); print(next((i['id'] for i in d if i.get('identifier')=='x'), ''))" <<< "${INTEGRATIONS_JSON}" 2>/dev/null || true)"
    FB_ID="$(python3 -c "import json,sys; d=json.loads(sys.stdin.read().split('Connected Integrations:')[-1].strip() or '[]'); print(next((i['id'] for i in d if i.get('identifier')=='facebook'), ''))" <<< "${INTEGRATIONS_JSON}" 2>/dev/null || true)"
    if [[ -n "${X_ID}" ]]; then
      pass "X integration connected (${X_ID})"
    else
      fail "X integration not found — reconnect in Postiz UI"
    fi
    if [[ -n "${FB_ID}" ]]; then
      pass "Facebook integration connected (${FB_ID})"
    else
      fail "Facebook integration not found — reconnect in Postiz UI"
    fi
    if echo "${INTEGRATIONS_JSON}" | grep -q '"identifier": "linkedin-page"'; then
      pass "LinkedIn Page connected (optional)"
    else
      echo "  ℹ  LinkedIn Page not connected (expected until CMA approved)"
    fi
  else
    fail "postiz integrations:list returned empty"
  fi
else
  fail "postiz CLI not installed — npm install -g postiz"
fi

if [[ -f "${INTEGRATIONS_FILE}" ]]; then
  pass "integrations.json present at ${INTEGRATIONS_FILE}"
else
  fail "integrations.json missing"
fi

echo ""
if [[ "${FAILURES}" -eq 0 ]]; then
  echo "✅ Postiz smoke test passed"
else
  echo "⚠️  ${FAILURES} check(s) failed"
  exit 1
fi
