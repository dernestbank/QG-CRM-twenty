#!/usr/bin/env bash
set -euo pipefail

CREDENTIALS_FILE="${HOME}/.openclaw/credentials/postiz-quantgist-api-key.txt"
OPENCLAW_ENV_FILE="${HOME}/.openclaw/.env"
GATEWAY_ENV_FILE="${HOME}/.openclaw/workspace/workspace_QuantGist/ops/postiz-gateway-env.sh"

export POSTIZ_API_URL="${POSTIZ_API_URL:-https://smm.quantgist.com/api}"
[[ "${POSTIZ_API_URL}" == */api ]] || POSTIZ_API_URL="${POSTIZ_API_URL%/}/api"

if [[ -f "${CREDENTIALS_FILE}" ]] && [[ -s "${CREDENTIALS_FILE}" ]]; then
  export POSTIZ_API_KEY="$(tr -d '[:space:]' < "${CREDENTIALS_FILE}")"
elif [[ -f "${OPENCLAW_ENV_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${OPENCLAW_ENV_FILE}"
fi

if [[ -z "${POSTIZ_API_KEY:-}" ]]; then
  echo "Postiz API key missing."
  echo "Generate in Postiz UI: Settings → API"
  echo "Save to: ${CREDENTIALS_FILE}"
  exit 1
fi

if [[ -f "${GATEWAY_ENV_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${GATEWAY_ENV_FILE}"
fi

echo "POSTIZ_API_URL=${POSTIZ_API_URL}"
echo "POSTIZ_API_KEY=*** (${#POSTIZ_API_KEY} chars)"
echo ""
echo "Add to ~/.openclaw/.env if not present:"
echo "  export POSTIZ_API_URL=\"${POSTIZ_API_URL}\""
echo "  export POSTIZ_API_KEY=\"\$(cat ${CREDENTIALS_FILE})\""
