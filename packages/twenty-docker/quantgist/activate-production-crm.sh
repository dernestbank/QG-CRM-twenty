#!/usr/bin/env bash
# Run on Coolify VM after setting env vars in Coolify UI (see COOLIFY_ACTIVATION.md).
set -euo pipefail

API=$(docker ps --format '{{.Names}}' | grep '^api-' | head -1 || true)
if [[ -z "${API}" ]]; then
  echo "ERROR: API container not found"
  echo "Run this on the Coolify VM after the API service is deployed."
  exit 1
fi

echo "=== CRM env check ==="
docker exec "${API}" printenv CRM_SYNC_ENABLED CRM_MARKETING_FIELDS_ENABLED || true
docker exec "${API}" sh -c '[ -n "$CRM_LEAD_INGEST_SECRET" ] && echo CRM_LEAD_INGEST_SECRET=set || echo CRM_LEAD_INGEST_SECRET=unset'

echo ""
echo "=== Probe ==="
docker exec "${API}" uv run python scripts/backfill_users_to_crm.py --probe

echo ""
echo "=== Dry-run backfill ==="
docker exec "${API}" uv run python scripts/backfill_users_to_crm.py --dry-run

read -r -p "Run full backfill? [y/N] " confirm
if [[ "${confirm}" == "y" || "${confirm}" == "Y" ]]; then
  docker exec "${API}" uv run python scripts/backfill_users_to_crm.py
fi

echo "Done."
