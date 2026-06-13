#!/usr/bin/env bash
set -euo pipefail

CREDENTIALS_DIR="${HOME}/.openclaw/credentials"
CANVA_ENV_FILE="${CREDENTIALS_DIR}/canva-quantgist.env"
OPENCLAW_ENV_FILE="${HOME}/.openclaw/.env"

echo "QuantGist Canva API bootstrap"
echo "See CANVA_MULTIMEDIA_WORKFLOW.md for full setup."
echo ""

mkdir -p "${CREDENTIALS_DIR}"
chmod 700 "${CREDENTIALS_DIR}"

if [[ ! -f "${CANVA_ENV_FILE}" ]]; then
  cat > "${CANVA_ENV_FILE}" <<'EOF'
# Canva Connect API — QuantGist (NEVER commit)
CANVA_CLIENT_ID=REPLACE_WITH_CLIENT_ID
CANVA_CLIENT_SECRET=REPLACE_WITH_CLIENT_SECRET
CANVA_API_BASE_URL=https://api.canva.com/rest/v1
CANVA_AUTH_BASE_URL=https://www.canva.com/api/oauth
CANVA_REDIRECT_URI=http://127.0.0.1:8765/oauth/canva/callback
CANVA_SCOPES="design:content:read design:content:write asset:read asset:write brandtemplate:content:read brandtemplate:meta:read"
CANVA_ACCESS_TOKEN=
CANVA_REFRESH_TOKEN=
EOF
  chmod 600 "${CANVA_ENV_FILE}"
  echo "Created template: ${CANVA_ENV_FILE}"
  echo "Edit client ID, secret, then run: bash packages/twenty-docker/quantgist/canva-oauth-bootstrap.sh"
  exit 0
fi

chmod 600 "${CANVA_ENV_FILE}"

# shellcheck disable=SC1090
source "${CANVA_ENV_FILE}"

if [[ -z "${CANVA_CLIENT_ID:-}" || "${CANVA_CLIENT_ID}" == REPLACE_* ]]; then
  echo "ERROR: Set CANVA_CLIENT_ID in ${CANVA_ENV_FILE}" >&2
  exit 1
fi

if [[ -z "${CANVA_CLIENT_SECRET:-}" || "${CANVA_CLIENT_SECRET}" == REPLACE_* ]]; then
  echo "ERROR: Set CANVA_CLIENT_SECRET in ${CANVA_ENV_FILE}" >&2
  exit 1
fi

# Legacy single-file exports (agents may read these)
echo "${CANVA_CLIENT_ID}" > "${CREDENTIALS_DIR}/canva-client-id.txt"
echo "${CANVA_CLIENT_SECRET}" > "${CREDENTIALS_DIR}/canva-client-secret.txt"
chmod 600 "${CREDENTIALS_DIR}/canva-client-id.txt" "${CREDENTIALS_DIR}/canva-client-secret.txt"

if [[ -n "${CANVA_ACCESS_TOKEN:-}" ]]; then
  echo "${CANVA_ACCESS_TOKEN}" > "${CREDENTIALS_DIR}/canva-access-token.txt"
  chmod 600 "${CREDENTIALS_DIR}/canva-access-token.txt"
  echo "Access token synced → canva-access-token.txt"
else
  echo "No CANVA_ACCESS_TOKEN yet — run canva-oauth-bootstrap.sh"
fi

if [[ -n "${CANVA_REFRESH_TOKEN:-}" ]]; then
  echo "${CANVA_REFRESH_TOKEN}" > "${CREDENTIALS_DIR}/canva-refresh-token.txt"
  chmod 600 "${CREDENTIALS_DIR}/canva-refresh-token.txt"
fi

ENV_SNIPPET='# Canva Connect API (QuantGist social campaigns)
# Source: ~/.openclaw/credentials/canva-quantgist.env
if [[ -f ~/.openclaw/credentials/canva-quantgist.env ]]; then
  # shellcheck disable=SC1090
  source ~/.openclaw/credentials/canva-quantgist.env
fi
'

if [[ -f "${OPENCLAW_ENV_FILE}" ]] && grep -q 'canva-quantgist.env' "${OPENCLAW_ENV_FILE}" 2>/dev/null; then
  echo "Canva source already present in ${OPENCLAW_ENV_FILE}"
else
  echo ""
  echo "Add to ${OPENCLAW_ENV_FILE}:"
  echo "${ENV_SNIPPET}"
fi

echo ""
echo "Client ID: ${CANVA_CLIENT_ID}"
echo "Redirect URI (register in Canva portal): ${CANVA_REDIRECT_URI:-http://127.0.0.1:8765/oauth/canva/callback}"
echo "Next: bash packages/twenty-docker/quantgist/canva-oauth-bootstrap.sh"
