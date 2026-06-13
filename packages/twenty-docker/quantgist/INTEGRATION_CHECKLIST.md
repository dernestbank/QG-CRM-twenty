# QuantGist integration checklist

> Status reviewed 2026-06-12. CRM + SMM + OpenClaw coordination wired in code/docs.

## Done (verified)

- [x] Twenty Docker stack + healthz
- [x] `quantgist/` helpers: bootstrap-api-key.sh, smoke-mcp.sh, agents-manifest.json
- [x] Twenty MCP smoke — `tools/list` HTTP 200 (2026-06-12)
- [x] Postiz X + Facebook connected (`integrations.json`)
- [x] Postiz smoke — API 200, `postiz integrations:list` OK (2026-06-12)
- [x] Social campaign runbook, example campaign, schedule script
- [x] `QG_MARKETING` in openclaw.json with Telegram topic 5 binding
- [x] `mcp.servers.twenty` in openclaw.json
- [x] `POSTIZ_API_URL` + `POSTIZ_API_KEY` in `~/.openclaw/.env`
- [x] OpenClaw ops docs: `workspace_QuantGist/ops/POSTIZ.md`, `TWENTY_CRM.md`
- [x] CRM data model spec: `CRM_DATA_MODEL.md` + `setup-crm-ui-checklist.sh`
- [x] Mac production runbook: `DEPLOY_MAC.md` (`crm.quantgist.com`)
- [x] Lead ingest API: `POST /v1/crm/leads/waitlist`, `/leads/contact`
- [x] Campaign sync: `sync-campaign-to-twenty.sh` + `POST /v1/crm/campaigns/sync`
- [x] Postiz webhook handler: `workers/postiz-publish-webhook.js` (Cloudflare Worker)
- [x] OAuth → CRM enqueue + subscription status in sync task
- [x] OpenClaw crons: Sunday dept reports 09:00–15:00 ET + CEO scorecard (`jobs.json`)
- [x] OpenClaw gateway restarted (2026-06-12)
- [x] Sunday reporting docs: `ops/WEEKLY_REPORTS_SUNDAY.md`, `ops/POSTHOG_WEEKLY_REPORT.md`, `ops/posthog_weekly_stats.sh`
- [x] Activation runbooks: `ACTIVATION_TEST.md`, `COOLIFY_ACTIVATION.md`, `workers/DEPLOY_POSTIZ_WEBHOOK.md`
- [x] CRM probe: core Person fields pass (`qgUserId`, `planCustom`, `subscriptionStatus`, `signupDate`)
- [x] Campaign validate + schedule dry-run (`jun-2026-lead-generation`)

## Still to do (human / ops)

1. **Twenty UI marketing fields + Campaign object** — 9 marketing Person fields + Campaign object still missing (`bash verify-crm-data-model.sh`)
2. **Coolify env** — `CRM_SYNC_ENABLED=true`, `CRM_MARKETING_FIELDS_ENABLED=true`, `CRM_LEAD_INGEST_SECRET` on API + web — see `COOLIFY_ACTIVATION.md`
3. **Production backfill** — `docker exec $API uv run python scripts/backfill_users_to_crm.py` on Coolify VM
4. **PostHog agent credentials** — `~/.openclaw/credentials/posthog-personal-api-key.txt` + `posthog-project-id.txt`
5. **Postiz webhook Worker** — `npx wrangler@4 login` then deploy per `workers/DEPLOY_POSTIZ_WEBHOOK.md`
6. **LinkedIn Page** — blocked on CMA (app `252090026`). X + Facebook until approved.
7. **First live campaign publish** — after human review: `schedule-campaign.sh --publish`

## Smoke tests (run on Mac host)

```bash
bash packages/twenty-docker/quantgist/smoke-mcp.sh
bash packages/twenty-docker/quantgist/smoke-postiz.sh
bash packages/twenty-docker/quantgist/smoke-campaign-workflow.sh
```

## MCP URL for Mac host

| From | URL |
|------|-----|
| OpenClaw on Mac (local Twenty) | `http://localhost:3000/mcp` |
| OpenClaw on Mac (production CRM) | `https://crm.quantgist.com/mcp` |
| OpenClaw in Docker (future) | `http://host.docker.internal:3000/mcp` |

## Twenty CRM

| Item | Value |
|------|--------|
| UI | https://crm.quantgist.com |
| MCP | https://crm.quantgist.com/mcp |
| REST | https://crm.quantgist.com/rest |
| API key | `~/.openclaw/credentials/twenty-quantgist-api-key.txt` |
| Deploy runbook | `quantgist/DEPLOY_MAC.md` |
| Data model | `quantgist/CRM_DATA_MODEL.md` |

## Postiz

| Item | Value |
|------|--------|
| UI | https://smm.quantgist.com/launches |
| API | https://smm.quantgist.com/api |
| X integration | `cmq55s5iy0001qttunmxabaf5` |
| Facebook integration | `cmq4clbth0001qkqsznluxtud` |
