# Postiz ↔ OpenClaw Agents Bridge

Routes **Postiz Agents UI** (`https://smm.quantgist.com/agents`) to OpenClaw `QG_MARKETING` and `QG_SOCIAL_MEDIA_MANAGER` instead of the built-in Mastra `postiz` assistant.

## Architecture

```
Browser → CopilotKit → POST /api/copilot/agent (Postiz NestJS)
  → OpenAIAdapter(baseURL=OpenClaw Gateway /v1)
  → model: openclaw/QG_MARKETING | openclaw/QG_SOCIAL_MEDIA_MANAGER
  → OpenClaw agent run (Codex OAuth — no OPENAI_API_KEY in Postiz)
```

| Layer | Role |
|-------|------|
| Postiz `CopilotController` | When `POSTIZ_OPENCLAW_BRIDGE=enabled`, skips Mastra; proxies to Gateway |
| OpenClaw Gateway | `POST /v1/chat/completions` with agent-first model ids |
| LLM auth | `openai-codex` OAuth (primary), fallbacks in `openclaw.json` |

## LLM provider fallback (OAuth — no raw OpenAI key)

Postiz does **not** store `OPENAI_API_KEY`. OpenClaw resolves models:

| Priority | Provider | Model | Agents |
|----------|----------|-------|--------|
| 1 | `openai-codex` OAuth | `gpt-5.5` | QG_MARKETING, QG_SOCIAL_MEDIA_MANAGER |
| 2 | `openai-codex` OAuth | `gpt-5.3-codex` | fallback |
| 3 | `xai` OAuth | `grok-4.3` | QG_SOCIAL_MEDIA_MANAGER only |

Configure OAuth: `openclaw configure` (Codex + xAI profiles in `~/.openclaw/openclaw.json` → `auth.profiles`).

## One-time setup

```bash
# 1. Bootstrap bridge (patches postiz.env + openclaw.json)
bash packages/twenty-docker/quantgist/bootstrap-postiz-agent-chat.sh --apply

# 2. Hot-patch running container (if image not rebuilt yet)
bash packages/twenty-docker/quantgist/bootstrap-postiz-agent-chat.sh --apply --live-patch

# 3. Rebuild Postiz image for UI agent dropdown (recommended)
cd /Volumes/ExtHDD/github/QG-ecosystem/SM-postiz-app
# copilot.controller.ts + agent.chat.tsx patches are in repo
docker compose build postiz && docker compose up -d --force-recreate postiz
```

## Credentials (never commit)

| File | Purpose |
|------|---------|
| `~/.openclaw/credentials/postiz-openclaw-gateway-token.txt` | Gateway bearer token (auto-created from `openclaw.json`) |
| `~/.openclaw/openclaw.json` | `gateway.http.endpoints.chatCompletions.enabled: true` |

## Select agent in UI

After frontend rebuild (`NEXT_PUBLIC_POSTIZ_OPENCLAW_BRIDGE=enabled`):

1. Open https://smm.quantgist.com/agents
2. Use dropdown: **QG Marketing** vs **QG Social Media Manager**
3. Selection stored in cookie `postizOpenClawAgent` and sent as `x-postiz-openclaw-agent`

Without rebuild, set default in `postiz.env`:

```bash
POSTIZ_OPENCLAW_AGENT=QG_SOCIAL_MEDIA_MANAGER
```

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `Agent 'postiz' was not found` | Frontend still sends `agent=postiz` (image not rebuilt) | `bash apply-postiz-openclaw-live-patch.sh` (patches backend + frontend JS) |
| Chat hangs / 404 from gateway | `gateway.http.endpoints.chatCompletions.enabled` not true | `bash bootstrap-postiz-agent-chat.sh --apply` then `openclaw gateway restart` |
| `/v1/models` returns HTML not JSON | chatCompletions endpoint disabled | Same as above — verify JSON model list after restart |

**Note:** `NEXT_PUBLIC_POSTIZ_OPENCLAW_BRIDGE` is baked at frontend build time. Until image rebuild, use the frontend live patch in `apply-postiz-openclaw-live-patch.sh`.

## Test

```bash
# Gateway models list (must return JSON, not HTML)
curl -s -H "Authorization: Bearer $(cat ~/.openclaw/credentials/postiz-openclaw-gateway-token.txt)" \
  -H "Accept: application/json" \
  http://127.0.0.1:18789/v1/models | head

# Direct agent
openclaw agent --agent QG_MARKETING --message "Summarize active Postiz campaigns"

# UI: New chat → "What channels are connected?"
```

## Session keys

Format: `agent:<agentId>:postiz-<orgId>-<threadId>`

OpenClaw maintains conversation state per Postiz org + CopilotKit thread.

## Mastra / built-in assistant

Set `POSTIZ_OPENCLAW_BRIDGE=disabled` and restore `OPENAI_API_KEY` to use the original Postiz scheduling assistant (not recommended for QuantGist — use OpenClaw bridge).

## Related

- `SOCIAL_CAMPAIGNS_RUNBOOK.md` — campaign ops
- `SM-postiz-app/apps/backend/src/api/routes/copilot.controller.ts` — bridge implementation
- OpenClaw docs: [OpenAI chat completions](https://docs.openclaw.ai/gateway/openai-http-api)
