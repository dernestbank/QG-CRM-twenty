#!/usr/bin/env bash
# Export a PNG from a Canva brand template (requires OAuth access token).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CANVA_ENV_FILE="${HOME}/.openclaw/credentials/canva-quantgist.env"
INTEGRATIONS_FILE="${SCRIPT_DIR}/integrations.json"

usage() {
  cat <<'EOF'
Export campaign image from Canva brand template.

Usage:
  bash canva-export-from-template.sh --template <key> [--post-id <id>] [--headline <text>]

Reads template designId from integrations.json → canva.templates.
Prints export URL to stdout on success.

Requires: CANVA_ACCESS_TOKEN (run canva-oauth-bootstrap.sh first)
EOF
}

TEMPLATE_KEY=""
POST_ID=""
HEADLINE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --template) TEMPLATE_KEY="$2"; shift 2 ;;
    --post-id) POST_ID="$2"; shift 2 ;;
    --headline) HEADLINE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "${TEMPLATE_KEY}" ]]; then
  usage >&2
  exit 1
fi

if [[ ! -f "${CANVA_ENV_FILE}" ]]; then
  echo "Canva not configured" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "${CANVA_ENV_FILE}"

if [[ -z "${CANVA_ACCESS_TOKEN:-}" ]]; then
  echo "No CANVA_ACCESS_TOKEN — run canva-oauth-bootstrap.sh" >&2
  exit 1
fi

DESIGN_ID="$(jq -r --arg key "${TEMPLATE_KEY}" '.canva.templates[$key].designId // empty' "${INTEGRATIONS_FILE}")"
if [[ -z "${DESIGN_ID}" || "${DESIGN_ID}" == PLACEHOLDER* ]]; then
  echo "Template ${TEMPLATE_KEY} has no real designId in integrations.json" >&2
  exit 1
fi

API_BASE="${CANVA_API_BASE_URL:-https://api.canva.com/rest/v1}"
HEADLINE="${HEADLINE:-QuantGist}"

# Autofill job — field names depend on template; adjust when templates are registered
AUTOFILL_BODY="$(python3 - "${DESIGN_ID}" "${HEADLINE}" <<'PY'
import json
import sys

design_id, headline = sys.argv[1:3]
payload = {
    "brand_template_id": design_id,
    "data": {
        "headline": {"type": "text", "text": headline},
        "subhead": {"type": "text", "text": "QuantGist Market Signals"},
    },
}
print(json.dumps(payload))
PY
)"

JOB_RESPONSE="$(curl -sS -X POST "${API_BASE}/autofills" \
  -H "Authorization: Bearer ${CANVA_ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${AUTOFILL_BODY}")"

JOB_ID="$(echo "${JOB_RESPONSE}" | python3 -c "import json,sys; print(json.load(sys.stdin).get('job',{}).get('id',''))" 2>/dev/null || true)"
if [[ -z "${JOB_ID}" ]]; then
  echo "Autofill failed: ${JOB_RESPONSE}" >&2
  exit 1
fi

# Poll autofill job (max ~60s)
DESIGN_EXPORT_ID=""
for _ in $(seq 1 12); do
  sleep 5
  STATUS_RESPONSE="$(curl -sS -H "Authorization: Bearer ${CANVA_ACCESS_TOKEN}" \
    "${API_BASE}/autofills/${JOB_ID}")"
  STATUS="$(echo "${STATUS_RESPONSE}" | python3 -c "import json,sys; print(json.load(sys.stdin).get('job',{}).get('status',''))" 2>/dev/null || true)"
  if [[ "${STATUS}" == "success" ]]; then
    DESIGN_EXPORT_ID="$(echo "${STATUS_RESPONSE}" | python3 -c "import json,sys; print(json.load(sys.stdin).get('job',{}).get('result',{}).get('design',{}).get('id',''))" 2>/dev/null || true)"
    break
  fi
  if [[ "${STATUS}" == "failed" ]]; then
    echo "Autofill job failed: ${STATUS_RESPONSE}" >&2
    exit 1
  fi
done

if [[ -z "${DESIGN_EXPORT_ID}" ]]; then
  echo "Autofill timed out for job ${JOB_ID}" >&2
  exit 1
fi

EXPORT_RESPONSE="$(curl -sS -X POST "${API_BASE}/exports" \
  -H "Authorization: Bearer ${CANVA_ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"design_id\":\"${DESIGN_EXPORT_ID}\",\"format\":{\"type\":\"png\",\"width\":1200,\"height\":630}}")"

EXPORT_JOB_ID="$(echo "${EXPORT_RESPONSE}" | python3 -c "import json,sys; print(json.load(sys.stdin).get('job',{}).get('id',''))" 2>/dev/null || true)"
EXPORT_URL=""
for _ in $(seq 1 12); do
  sleep 5
  EXPORT_STATUS="$(curl -sS -H "Authorization: Bearer ${CANVA_ACCESS_TOKEN}" \
    "${API_BASE}/exports/${EXPORT_JOB_ID}")"
  EXPORT_STATE="$(echo "${EXPORT_STATUS}" | python3 -c "import json,sys; print(json.load(sys.stdin).get('job',{}).get('status',''))" 2>/dev/null || true)"
  if [[ "${EXPORT_STATE}" == "success" ]]; then
    EXPORT_URL="$(echo "${EXPORT_STATUS}" | python3 -c "import json,sys; d=json.load(sys.stdin); urls=d.get('job',{}).get('result',{}).get('urls',[]); print(urls[0] if urls else '')" 2>/dev/null || true)"
    break
  fi
done

if [[ -z "${EXPORT_URL}" ]]; then
  echo "Export failed for design ${DESIGN_EXPORT_ID}" >&2
  exit 1
fi

echo "${EXPORT_URL}"
