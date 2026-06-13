#!/usr/bin/env bash
# Sync campaign.json to Twenty CRM Campaign object via QuantGist API.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CAMPAIGN_DIR="${1:-}"
DRY_RUN=0

usage() {
  cat <<'EOF'
Sync a campaign directory to Twenty CRM.

Usage:
  bash sync-campaign-to-twenty.sh <campaign-directory> [--dry-run]

Requires:
  CRM_LEAD_INGEST_SECRET in environment or ~/.openclaw/.env
  QUANTGIST_API_URL (default https://api.quantgist.com/v1)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *)
      if [[ -z "${CAMPAIGN_DIR}" ]]; then
        CAMPAIGN_DIR="$1"
      fi
      shift
      ;;
  esac
done

if [[ -z "${CAMPAIGN_DIR}" || ! -f "${CAMPAIGN_DIR}/campaign.json" ]]; then
  echo "ERROR: campaign.json not found in ${CAMPAIGN_DIR:-<missing>}" >&2
  usage
  exit 1
fi

if [[ -f "${HOME}/.openclaw/.env" ]]; then
  # shellcheck disable=SC1091
  set -a
  source "${HOME}/.openclaw/.env"
  set +a
fi

API_URL="${QUANTGIST_API_URL:-https://api.quantgist.com/v1}"
INGEST_SECRET="${CRM_LEAD_INGEST_SECRET:-}"

if [[ -z "${INGEST_SECRET}" ]]; then
  echo "ERROR: CRM_LEAD_INGEST_SECRET not set" >&2
  exit 1
fi

PAYLOAD="$(jq '{
  id: .id,
  name: .name,
  campaignType: .campaignType,
  status: .status,
  platforms: .platforms,
  strategy: .strategy,
  startDate: (.startDate // null),
  endDate: (.endDate // null)
}' "${CAMPAIGN_DIR}/campaign.json")"

echo "Syncing campaign: $(jq -r '.name' "${CAMPAIGN_DIR}/campaign.json")"

if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "[dry-run] POST ${API_URL}/crm/campaigns/sync"
  echo "${PAYLOAD}" | jq .
  exit 0
fi

HTTP_CODE="$(
  curl -sS -o /tmp/qg-crm-sync-response.json -w "%{http_code}" \
    -X POST "${API_URL}/crm/campaigns/sync" \
    -H "Content-Type: application/json" \
    -H "X-Crm-Ingest-Key: ${INGEST_SECRET}" \
    -d "${PAYLOAD}"
)"

if [[ "${HTTP_CODE}" -ge 400 ]]; then
  echo "ERROR: CRM sync failed (${HTTP_CODE})" >&2
  cat /tmp/qg-crm-sync-response.json >&2
  exit 1
fi

cat /tmp/qg-crm-sync-response.json | jq .
echo "OK: Campaign synced to Twenty"
