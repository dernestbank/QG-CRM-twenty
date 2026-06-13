#!/usr/bin/env bash
# Wire Postiz Agents chat to OpenClaw (Codex OAuth) — no raw OpenAI API key.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CREDENTIALS_DIR="${HOME}/.openclaw/credentials"
GATEWAY_TOKEN_FILE="${CREDENTIALS_DIR}/postiz-openclaw-gateway-token.txt"
OPENCLAW_JSON="${HOME}/.openclaw/openclaw.json"
POSTIZ_ENV="${POSTIZ_ENV_FILE:-/Volumes/ExtHDD/github/QG-ecosystem/SM-postiz-app/postiz.env}"
DEFAULT_AGENT="${POSTIZ_OPENCLAW_AGENT:-QG_MARKETING}"
APPLY=0
LIVE_PATCH=0

usage() {
  cat <<'EOF'
Enable Postiz Agents chat via OpenClaw bridge (OAuth LLM — no OPENAI_API_KEY).

Usage:
  bash bootstrap-postiz-agent-chat.sh                    # Dry-run status
  bash bootstrap-postiz-agent-chat.sh --apply            # Patch env + openclaw.json + restart
  bash bootstrap-postiz-agent-chat.sh --apply --live-patch # Also hot-patch running container JS

Options:
  --agent <id>    QG_MARKETING (default) | QG_SOCIAL_MEDIA_MANAGER

See: packages/twenty-docker/quantgist/POSTIZ_OPENCLAW_BRIDGE.md
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    --apply)
      APPLY=1
      shift
      ;;
    --live-patch)
      LIVE_PATCH=1
      shift
      ;;
    --agent)
      DEFAULT_AGENT="${2:-}"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ ! "${DEFAULT_AGENT}" =~ ^(QG_MARKETING|QG_SOCIAL_MEDIA_MANAGER)$ ]]; then
  echo "Invalid agent: ${DEFAULT_AGENT}" >&2
  exit 1
fi

mkdir -p "${CREDENTIALS_DIR}"
chmod 700 "${CREDENTIALS_DIR}" 2>/dev/null || true

if [[ ! -f "${GATEWAY_TOKEN_FILE}" ]]; then
  if [[ -f "${OPENCLAW_JSON}" ]]; then
    python3 - "${OPENCLAW_JSON}" "${GATEWAY_TOKEN_FILE}" <<'PY'
import json, sys
path, out = sys.argv[1:3]
cfg = json.load(open(path))
token = (cfg.get("gateway") or {}).get("auth", {}).get("token", "")
if not token:
    sys.exit(1)
open(out, "w").write(token + "\n")
PY
    chmod 600 "${GATEWAY_TOKEN_FILE}"
    echo "Created ${GATEWAY_TOKEN_FILE} from openclaw.json"
  else
    echo "Missing ${GATEWAY_TOKEN_FILE} and ${OPENCLAW_JSON}" >&2
    exit 1
  fi
fi

GATEWAY_TOKEN="$(tr -d '[:space:]' < "${GATEWAY_TOKEN_FILE}")"
echo "Gateway token: *** (${#GATEWAY_TOKEN} chars)"
echo "Default agent: ${DEFAULT_AGENT}"

if [[ -f "${OPENCLAW_JSON}" ]]; then
  python3 - "${OPENCLAW_JSON}" <<'PY'
import json, sys
path = sys.argv[1]
cfg = json.load(open(path))
gateway = cfg.setdefault("gateway", {})
http = gateway.setdefault("http", {})
endpoints = http.setdefault("endpoints", {})
chat = endpoints.setdefault("chatCompletions", {})
chat["enabled"] = True
if not chat.get("enabled"):
    raise SystemExit("Failed to enable gateway.http.endpoints.chatCompletions")
agents = cfg.setdefault("agents", {}).setdefault("list", [])
ids = {a.get("id") for a in agents}
if "QG_SOCIAL_MEDIA_MANAGER" not in ids:
    agents.append({
        "id": "QG_SOCIAL_MEDIA_MANAGER",
        "workspace": "/Users/nanabee_home/.openclaw/workspace/workspace_QuantGist/agents/workspaces/QG_SOCIAL_MEDIA_MANAGER",
        "model": {
            "primary": "openai/gpt-5.5",
            "fallbacks": ["openai/gpt-5.3-codex", "xai/grok-4.3"],
        },
        "models": {
            "openai/gpt-5.5": {"agentRuntime": {"id": "codex"}},
            "openai/gpt-5.3-codex": {"agentRuntime": {"id": "codex"}},
            "xai/grok-4.3": {},
        },
    })
json.dump(cfg, open(path, "w"), indent=2)
open(path, "w").write(open(path).read() + "\n")
print("Updated openclaw.json")
PY
fi

if [[ ! -f "${POSTIZ_ENV}" ]]; then
  echo "Postiz env not found: ${POSTIZ_ENV}" >&2
  exit 1
fi

set_env_var() {
  local key="$1"
  local value="$2"
  if grep -q "^${key}=" "${POSTIZ_ENV}"; then
    sed -i '' "s|^${key}=.*|${key}=${value}|" "${POSTIZ_ENV}"
  else
    echo "${key}=${value}" >> "${POSTIZ_ENV}"
  fi
}

set_env_var "POSTIZ_OPENCLAW_BRIDGE" "enabled"
set_env_var "POSTIZ_OPENCLAW_AGENT" "${DEFAULT_AGENT}"
set_env_var "OPENCLAW_GATEWAY_URL" "http://host.docker.internal:18789/v1"
set_env_var "OPENCLAW_GATEWAY_TOKEN" "${GATEWAY_TOKEN}"
set_env_var "NEXT_PUBLIC_POSTIZ_OPENCLAW_BRIDGE" "enabled"

if grep -q '^OPENAI_API_KEY=' "${POSTIZ_ENV}"; then
  sed -i '' '/^OPENAI_API_KEY=/d' "${POSTIZ_ENV}"
  echo "Removed OPENAI_API_KEY from ${POSTIZ_ENV}"
fi

chmod 600 "${POSTIZ_ENV}"
echo "Updated ${POSTIZ_ENV}"

echo ""
echo "OAuth LLM fallback chain (OpenClaw agents.list):"
echo "  1. openai-codex OAuth → gpt-5.5"
echo "  2. openai-codex OAuth → gpt-5.3-codex"
echo "  3. xai OAuth → grok-4.3 (QG_SOCIAL_MEDIA_MANAGER)"

if [[ "${APPLY}" -ne 1 ]]; then
  echo ""
  echo "Dry run complete. To apply:"
  echo "  bash $0 --apply"
  exit 0
fi

echo ""
echo "Restarting OpenClaw gateway..."
openclaw gateway restart 2>/dev/null || true
sleep 4

HTTP_CODE="$(curl -sS -o /dev/null -w '%{http_code}' \
  -H "Authorization: Bearer ${GATEWAY_TOKEN}" \
  http://127.0.0.1:18789/v1/models 2>/dev/null || echo 000)"
if [[ "${HTTP_CODE}" == "200" ]]; then
  echo "OpenClaw /v1/models: HTTP 200"
else
  echo "WARN: OpenClaw /v1/models HTTP ${HTTP_CODE}"
fi

if [[ "${LIVE_PATCH}" -eq 1 ]]; then
  bash "${SCRIPT_DIR}/apply-postiz-openclaw-live-patch.sh"
fi

if ! docker ps --format '{{.Names}}' | grep -qx postiz; then
  echo "Postiz container not running — start stack first" >&2
  exit 1
fi

POSTIZ_DIR="$(dirname "${POSTIZ_ENV}")"
echo "Recreating Postiz container..."
docker compose -f "${POSTIZ_DIR}/docker-compose.yaml" up -d --force-recreate --no-deps postiz

echo ""
echo "Test: https://smm.quantgist.com/agents"
echo "Default agent (env): ${DEFAULT_AGENT}"
echo "UI dropdown: rebuild Postiz image after SM-postiz-app frontend patch"
