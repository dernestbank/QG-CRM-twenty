#!/usr/bin/env bash
# Verify Twenty CRM data model via probe + optional Campaign REST check.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKEND_DIR="${QUANTGIST_BACKEND_DIR:-/Volumes/ExtHDD/github/QuantGist-webapp/backend}"

echo "=== QuantGist CRM Data Model Verification ==="
echo ""

if [[ ! -d "${BACKEND_DIR}" ]]; then
  echo "ERROR: Backend not found at ${BACKEND_DIR}"
  exit 1
fi

cd "${BACKEND_DIR}"
PROBE_EXIT=0
DEBUG=false uv run python scripts/backfill_users_to_crm.py --probe || PROBE_EXIT=$?

echo ""
if [[ "${PROBE_EXIT}" -eq 0 ]]; then
  echo "✅ Probe passed — core + marketing Person fields present."
elif [[ "${PROBE_EXIT}" -eq 2 ]]; then
  echo "⚠️  Run UI setup: bash ${SCRIPT_DIR}/setup-crm-ui-checklist.sh"
  echo "   Manual steps required at https://crm.quantgist.com"
else
  echo "❌ Probe failed — check TWENTY_API_URL / TWENTY_API_KEY"
fi

# Optional Campaign object check
if [[ -f "${HOME}/.openclaw/credentials/twenty-quantgist-api-key.txt" ]]; then
  API_KEY="$(tr -d '[:space:]' < "${HOME}/.openclaw/credentials/twenty-quantgist-api-key.txt")"
  HTTP_CODE="$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer ${API_KEY}" \
    "https://crm.quantgist.com/rest/campaigns?limit=1" 2>/dev/null || echo "000")"
  if [[ "${HTTP_CODE}" == "200" ]]; then
    echo "✅ Campaign object reachable (GET /rest/campaigns → 200)"
  else
    echo "⚠️  Campaign object check: GET /rest/campaigns → HTTP ${HTTP_CODE}"
    echo "   Create Campaign custom object in Twenty UI (see CRM_DATA_MODEL.md)"
  fi
fi

exit "${PROBE_EXIT}"
