#!/usr/bin/env bash
set -euo pipefail

CREDENTIALS_FILE="${HOME}/.openclaw/credentials/twenty-quantgist-api-key.txt"
MCP_URL="${TWENTY_MCP_URL:-http://localhost:3000/mcp}"

if [[ ! -f "${CREDENTIALS_FILE}" ]]; then
  echo "Missing ${CREDENTIALS_FILE}"
  exit 1
fi

API_KEY="$(tr -d '\n' < "${CREDENTIALS_FILE}")"

curl -fsS -X POST "${MCP_URL}" \
  -H "Authorization: Bearer ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' \
  | head -c 2000

echo ""
echo "MCP smoke test OK"
