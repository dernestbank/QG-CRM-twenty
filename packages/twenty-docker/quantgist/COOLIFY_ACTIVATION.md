# Coolify Activation — CRM + Lead Ingest

Set these in Coolify UI only. **Never commit secrets to git.**

## API backend (`api.quantgist.com`)

| Variable | Value |
|----------|-------|
| `CRM_SYNC_ENABLED` | `true` |
| `CRM_MARKETING_FIELDS_ENABLED` | `true` (after Twenty UI marketing fields exist) |
| `CRM_LEAD_INGEST_SECRET` | *(64-char hex — set in Coolify UI)* |
| `TWENTY_API_URL` | `https://crm.quantgist.com` |
| `TWENTY_API_KEY` | *(from Twenty Settings → APIs & Webhooks)* |

Redeploy API after saving.

## Web frontend (`quantgist.com`)

| Variable | Value |
|----------|-------|
| `CRM_LEAD_INGEST_SECRET` | same as API |
| `NEXT_PUBLIC_POSTHOG_KEY` | *(PostHog project key)* |
| `NEXT_PUBLIC_POSTHOG_HOST` | `https://us.i.posthog.com` |

Redeploy web after saving.

## Verify after redeploy

```bash
ssh coolify
API=$(docker ps --format '{{.Names}}' | grep '^api-')
docker exec $API printenv CRM_SYNC_ENABLED
docker exec $API uv run python scripts/backfill_users_to_crm.py --probe
docker exec $API uv run python scripts/backfill_users_to_crm.py --dry-run
docker exec $API uv run python scripts/backfill_users_to_crm.py
```

## Mac OpenClaw (`~/.openclaw/.env`)

```bash
export CRM_LEAD_INGEST_SECRET="<same-as-coolify>"
export TWENTY_QUANTGIST_API_KEY="$(cat ~/.openclaw/credentials/twenty-quantgist-api-key.txt)"
```

Then: `openclaw gateway restart`
