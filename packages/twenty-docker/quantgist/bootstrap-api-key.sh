#!/usr/bin/env bash
set -euo pipefail

CREDENTIALS_FILE="${HOME}/.openclaw/credentials/twenty-quantgist-api-key.txt"
COMPOSE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

if [[ -f "${CREDENTIALS_FILE}" ]] && [[ -s "${CREDENTIALS_FILE}" ]]; then
  echo "API key file already exists: ${CREDENTIALS_FILE}"
  exit 0
fi

WORKSPACE_ID="$(
  docker exec twenty-db-1 psql -U postgres -d default -tAc \
    'SELECT id FROM core.workspace ORDER BY "createdAt" ASC LIMIT 1;' 2>/dev/null | tr -d '[:space:]'
)"

if [[ -z "${WORKSPACE_ID}" ]]; then
  echo "No workspace found. Complete signup at http://localhost:3000 first."
  echo "Then create an API key in Settings → APIs & Webhooks and save it to:"
  echo "  ${CREDENTIALS_FILE}"
  exit 1
fi

echo "Workspace ID: ${WORKSPACE_ID}"
echo "Generating API key via Twenty CLI (development mode only)..."

TOKEN_LINE="$(
  docker exec twenty-server-1 node dist/command/command.js workspace:generate-api-key \
    --workspace-id "${WORKSPACE_ID}" \
    --name "QuantGist OpenClaw MCP" 2>&1 | grep '^TOKEN:' || true
)"

if [[ -z "${TOKEN_LINE}" ]]; then
  echo "CLI generation failed (production image or no admin role)."
  echo "Create a key in the UI and save it to: ${CREDENTIALS_FILE}"
  exit 1
fi

TOKEN="${TOKEN_LINE#TOKEN:}"

mkdir -p "$(dirname "${CREDENTIALS_FILE}")"
chmod 700 "$(dirname "${CREDENTIALS_FILE}")"
printf '%s' "${TOKEN}" > "${CREDENTIALS_FILE}"
chmod 600 "${CREDENTIALS_FILE}"

echo "Wrote API key to ${CREDENTIALS_FILE}"
echo "Add to ~/.openclaw/.env:"
echo "  export TWENTY_QUANTGIST_API_KEY=\"\$(cat ${CREDENTIALS_FILE})\""
