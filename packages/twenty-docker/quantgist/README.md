# QuantGist + Twenty CRM (Docker)

Hybrid setup: **Twenty in Docker**, **OpenClaw on the Mac host**.

## 1. Start Twenty

```bash
cd packages/twenty-docker
cp .env.example .env   # if .env does not exist — set ENCRYPTION_KEY, APP_SECRET, PG_DATABASE_PASSWORD
docker compose up -d
curl -fsS http://localhost:3000/healthz
```

## 2. Create workspace (one-time)

Open http://localhost:3000 and complete signup for your QuantGist workspace.

## 3. Create API key and wire OpenClaw

In Twenty: **Settings → APIs & Webhooks → Create key** (Admin or a role with People/Companies/Opportunities/Notes/Tasks).

Save the token:

```bash
mkdir -p ~/.openclaw/credentials
chmod 700 ~/.openclaw/credentials
# paste key only — no trailing newline required
nano ~/.openclaw/credentials/twenty-quantgist-api-key.txt
```

Or run the helper (after signup):

```bash
bash packages/twenty-docker/quantgist/bootstrap-api-key.sh
```

Add to `~/.openclaw/.env`:

```bash
export TWENTY_QUANTGIST_API_KEY="$(cat ~/.openclaw/credentials/twenty-quantgist-api-key.txt)"
```

Smoke test:

```bash
bash packages/twenty-docker/quantgist/smoke-mcp.sh
```

## 4. OpenClaw

`~/.openclaw/openclaw.json` should include `mcp.servers.twenty` pointing at `http://localhost:3000/mcp`.

Restart the OpenClaw gateway after changing MCP config.

## 5. Social campaigns (strategic framework + Postiz)

Agents run **strategic campaigns** — every post maps to audience, goal, pillar, and funnel stage. No ad-hoc posting.

| Doc | Purpose |
|-----|---------|
| `CAMPAIGN_STRATEGY.md` | Audiences, goals, pillars, funnel, weekly OS |
| `CONTENT_MATRIX.md` | Content matrix tables |
| `CANVA_MULTIMEDIA_WORKFLOW.md` | Canva API + templates |
| `SOCIAL_CAMPAIGNS_RUNBOOK.md` | Postiz ops, feedback loop |
| `campaigns/templates/` | product-launch, brand-awareness, lead-generation, event-promotion |
| `campaigns/SCHEMA.md` | `campaign.json` schema |

```bash
bash packages/twenty-docker/quantgist/bootstrap-postiz-env.sh
bash packages/twenty-docker/quantgist/smoke-campaign-workflow.sh
```

Validate and schedule example (product launch):

```bash
bash packages/twenty-docker/quantgist/validate-campaign.sh campaigns/example-jun-2026-signals-launch/
bash packages/twenty-docker/quantgist/campaigns/example-jun-2026-signals-launch/schedule-campaign.sh --dry-run
bash packages/twenty-docker/quantgist/campaigns/example-jun-2026-signals-launch/schedule-campaign.sh
```

Canva (optional): `bash packages/twenty-docker/quantgist/bootstrap-canva-env.sh`

Feedback: Telegram topic 5 (G_marketing) or Discord `#qg_marketing`.

## 6. In-app AI agents

Import prompts from `agents-manifest.json` via **Settings → AI**, or register on OpenClaw (`QG_MARKETING`, `QG_SOCIAL_MEDIA_MANAGER`, etc.).

## CRM operations

| Doc | Purpose |
|-----|---------|
| `DEPLOY_MAC.md` | Production `crm.quantgist.com` on Mac Docker + Cloudflare |
| `CRM_DATA_MODEL.md` | Person fields, Campaign object, Growth Pipeline |
| `setup-crm-ui-checklist.sh` | Print UI setup steps |
| `sync-campaign-to-twenty.sh` | Push `campaign.json` → Twenty via API |
| `FIRST_CAMPAIGN_RUNBOOK.md` | First live campaign end-to-end |
| `INTEGRATION_CHECKLIST.md` | Wiring status |

## MCP URL

| From | URL |
|------|-----|
| Production (OpenClaw) | `https://crm.quantgist.com/mcp` |
| Local dev | `http://localhost:3000/mcp` |
