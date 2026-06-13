# Deploy Postiz → CRM Cloudflare Worker

## Prerequisites

- Cloudflare account with Workers enabled
- Same `CRM_LEAD_INGEST_SECRET` as Coolify API

## One-time setup

```bash
cd packages/twenty-docker/quantgist/workers
npx wrangler@4 login
npx wrangler@4 secret put CRM_LEAD_INGEST_SECRET
# paste secret when prompted (same as Coolify API)
npx wrangler@4 deploy -c wrangler.postiz-webhook.toml
```

Deployed URL pattern: `https://quantgist-postiz-crm-webhook.<account>.workers.dev`

## Register in Postiz

1. Open https://smm.quantgist.com → Settings → Webhooks
2. URL: `https://quantgist-postiz-crm-webhook.<account>.workers.dev/webhooks/postiz-published`
3. Events: post published

## Verify

```bash
curl -sS -X POST "https://quantgist-postiz-crm-webhook.<account>.workers.dev/webhooks/postiz-published" \
  -H "Content-Type: application/json" \
  -H "X-Crm-Ingest-Key: $CRM_LEAD_INGEST_SECRET" \
  -d '{"postId":"test","integrationId":"test","content":"smoke test"}'
```

Expect HTTP 200 from worker (API may return 4xx for invalid payload — worker should forward).
