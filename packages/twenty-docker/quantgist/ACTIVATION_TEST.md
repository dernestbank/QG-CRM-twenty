# QuantGist CRM Activation — E2E Test Checklist

Run after Twenty UI setup, Coolify env, and OpenClaw cron configuration.

## Prerequisites

- [ ] Twenty UI fields + Campaign object (`bash verify-crm-data-model.sh` or `bootstrap-crm-data-model.py`)
- [ ] API: `CRM_SYNC_ENABLED=true`, `CRM_LEAD_INGEST_SECRET` set
- [ ] Web: `CRM_LEAD_INGEST_SECRET` set
- [ ] `openclaw gateway restart` after cron changes

## 1. Infrastructure smoke

```bash
bash packages/twenty-docker/quantgist/smoke-mcp.sh
bash packages/twenty-docker/quantgist/smoke-postiz.sh
bash ~/.openclaw/workspace/workspace_QuantGist/ops/smoke_test_postiz.sh
curl -fsS https://api.quantgist.com/health
curl -fsS https://crm.quantgist.com/healthz
```

## 2. User backfill

```bash
cd QuantGist-webapp/backend
uv run python scripts/backfill_users_to_crm.py --probe
uv run python scripts/backfill_users_to_crm.py --dry-run
# Production:
# docker exec $API uv run python scripts/backfill_users_to_crm.py
```

## 3. Lead funnel

| Step | Action | Expected |
|------|--------|----------|
| A | `POST /api/waitlist` with test email + UTM | Person in Twenty, Task created |
| B | `POST /v1/auth/register` same email | Person gets `qgUserId` |
| C | `POST /v1/auth/login` existing user | No duplicate Person |

Direct ingest test:

```bash
curl -sS -X POST https://api.quantgist.com/v1/crm/leads/waitlist \
  -H "Content-Type: application/json" \
  -H "X-Crm-Ingest-Key: $CRM_LEAD_INGEST_SECRET" \
  -d '{"firstName":"Test","lastName":"Activation","email":"test-activation@example.com","utmCampaign":"test-activation"}'
```

## 4. Campaign workflow

```bash
bash packages/twenty-docker/quantgist/validate-campaign.sh \
  packages/twenty-docker/quantgist/campaigns/jun-2026-lead-generation/
export CRM_LEAD_INGEST_SECRET="<secret>"
bash packages/twenty-docker/quantgist/sync-campaign-to-twenty.sh \
  packages/twenty-docker/quantgist/campaigns/jun-2026-lead-generation/ --dry-run
bash packages/twenty-docker/quantgist/campaigns/jun-2026-lead-generation/schedule-campaign.sh --dry-run
```

## 5. PostHog

1. Visit https://quantgist.com with DevTools → Network → filter `posthog`
2. Confirm `$pageview` events
3. Run `bash ops/posthog_weekly_stats.sh` (requires API key in credentials)

## 6. Sunday cron dry-run

Manually invoke each Sunday job message in Discord/Telegram or trigger via OpenClaw cron UI.
Verify entries in Supabase `qg_agent_logs`.

## Pass criteria

- [ ] All smoke tests pass
- [ ] Probe exit 0
- [ ] Waitlist → CRM Person within 30s
- [ ] Register updates same Person with `qgUserId`
- [ ] Campaign sync returns 200
- [ ] PostHog live events visible
- [ ] Sunday dept reports log to `qg_agent_logs`
