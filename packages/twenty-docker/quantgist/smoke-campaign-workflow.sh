#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FAILURES=0

fail() { echo "  ✗ FAIL: $1" >&2; FAILURES=$((FAILURES + 1)); }
pass() { echo "  ✓ OK: $1"; }

echo "=== QuantGist Social Campaign Workflow Smoke Test ==="
echo "$(date -u +%FT%TZ)"
echo ""

echo "── 1. Twenty CRM (Docker) ──"
if bash "${SCRIPT_DIR}/smoke-mcp.sh" >/dev/null 2>&1; then
  pass "Twenty MCP tools/list"
else
  fail "Twenty MCP — run bootstrap-api-key.sh and ensure docker compose is up"
fi
echo ""

echo "── 2. Postiz (X + Facebook) ──"
if bash "${SCRIPT_DIR}/smoke-postiz.sh" >/dev/null 2>&1; then
  pass "Postiz stack + X/Facebook integrations"
else
  fail "Postiz — see smoke-postiz.sh output"
fi
echo ""

echo "── 3. OpenClaw agent wiring ──"
OPENCLAW_JSON="${HOME}/.openclaw/openclaw.json"
if [[ -f "${OPENCLAW_JSON}" ]]; then
  if jq -e '.agents.list[] | select(.id=="QG_MARKETING")' "${OPENCLAW_JSON}" >/dev/null 2>&1; then
    pass "QG_MARKETING agent registered in openclaw.json"
  else
    fail "QG_MARKETING not in openclaw.json agents.list"
  fi
  if jq -e '.mcp.servers.twenty' "${OPENCLAW_JSON}" >/dev/null 2>&1; then
    pass "Twenty MCP server registered"
  else
    fail "mcp.servers.twenty missing in openclaw.json"
  fi
else
  echo "  ℹ  openclaw.json not found — skip host agent checks"
fi
echo ""

echo "── 4. Feedback channels (config only) ──"
INTEGRATIONS="${SCRIPT_DIR}/integrations.json"
if [[ -f "${INTEGRATIONS}" ]]; then
  TG_TOPIC="$(jq -r '.feedbackChannels.telegram.marketingTopicId' "${INTEGRATIONS}")"
  DC_CH="$(jq -r '.feedbackChannels.discord.marketingChannelId' "${INTEGRATIONS}")"
  pass "Telegram marketing topic ${TG_TOPIC} documented"
  pass "Discord marketing channel ${DC_CH} documented"
fi
BOT_TOKEN_FILE="${HOME}/.openclaw/credentials/discord-bot-token.txt"
if [[ -f "${BOT_TOKEN_FILE}" ]]; then
  HTTP=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
    -H "Authorization: Bot $(tr -d '[:space:]' < "${BOT_TOKEN_FILE}")" \
    "https://discord.com/api/v10/users/@me" 2>/dev/null || echo "000")
  if [[ "${HTTP}" == "200" ]]; then
    pass "Discord bot token valid"
  else
    fail "Discord bot auth HTTP ${HTTP}"
  fi
else
  echo "  ℹ  Discord bot token not found — feedback via Telegram only"
fi
echo ""

echo "── 5. Example campaign assets ──"
CAMPAIGN_DIR="${SCRIPT_DIR}/campaigns/example-jun-2026-signals-launch"
if [[ -f "${CAMPAIGN_DIR}/campaign.json" ]] && [[ -f "${CAMPAIGN_DIR}/posts-schedule.json" ]]; then
  pass "Example campaign files present"
else
  fail "Example campaign missing under campaigns/"
fi
echo ""

echo "=== Summary ==="
if [[ "${FAILURES}" -eq 0 ]]; then
  echo "✅ Campaign workflow ready — agents can schedule via Postiz (X + Facebook)"
else
  echo "⚠️  ${FAILURES} check(s) failed"
  exit 1
fi
