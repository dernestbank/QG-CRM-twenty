# Twenty CRM — Mac Docker Production (`crm.quantgist.com`)

Hybrid setup: **Twenty in Docker on Mac**, exposed via **Cloudflare** to the public.
OpenClaw agents reach CRM via MCP at `https://crm.quantgist.com/mcp`.

Git repo: `/Volumes/ExtHDD/github/QG-ecosystem/QG-CRM-twenty`

## URLs

| Surface | URL |
|---------|-----|
| Production UI | https://crm.quantgist.com |
| Production MCP | https://crm.quantgist.com/mcp |
| Production REST | https://crm.quantgist.com/rest |
| Local dev | http://localhost:3000 |
| Health | https://crm.quantgist.com/healthz |

## Start / restart

```bash
cd /Volumes/ExtHDD/github/QG-ecosystem/QG-CRM-twenty/packages/twenty-docker
cp .env.example .env   # first time only
# Set SERVER_URL=https://crm.quantgist.com, ENCRYPTION_KEY, APP_SECRET, PG_DATABASE_PASSWORD
docker compose up -d
curl -fsS http://localhost:3000/healthz
```

After env changes:

```bash
docker compose down && docker compose up -d
```

## Cloudflare (`crm.quantgist.com`)

| Setting | Value |
|---------|--------|
| DNS | `crm` → Mac IP or Cloudflare Tunnel; **Proxied** |
| SSL/TLS | **Full** |
| Origin | `http://<mac-host>:3000` |
| WebSockets | **On** (MCP / realtime) |
| Cache | Bypass for `/rest/*`, `/mcp`, `/graphql` |

## Environment (`.env`)

```env
SERVER_URL=https://crm.quantgist.com
TAG=latest
# ENCRYPTION_KEY, APP_SECRET, PG_DATABASE_PASSWORD — generate once, never rotate casually
```

API key for agents and backend sync:

```bash
mkdir -p ~/.openclaw/credentials
# Settings → APIs & Webhooks → Create key → save to:
# ~/.openclaw/credentials/twenty-quantgist-api-key.txt
bash packages/twenty-docker/quantgist/bootstrap-api-key.sh
```

Wire OpenClaw (`~/.openclaw/openclaw.json`):

```json
"mcp": {
  "servers": {
    "twenty": {
      "url": "https://crm.quantgist.com/mcp"
    }
  }
}
```

Restart gateway after MCP changes:

```bash
openclaw gateway restart
```

## Backup

Postgres data lives in Docker volume `twenty-docker_db-data` (name may vary — check `docker volume ls`).

```bash
# Snapshot (run from Mac)
docker exec twenty-db-1 pg_dump -U postgres default > ~/backups/twenty-$(date +%Y%m%d).sql

# Restore (destructive — test on staging first)
cat ~/backups/twenty-YYYYMMDD.sql | docker exec -i twenty-db-1 psql -U postgres default
```

Also backup:

- `~/.openclaw/credentials/twenty-quantgist-api-key.txt`
- `.env` secrets (encrypted notes — not git)

## Upgrade

```bash
cd packages/twenty-docker
docker compose pull
docker compose up -d
# Twenty runs migrations on server start; watch logs:
docker compose logs -f server
curl -fsS https://crm.quantgist.com/healthz
bash quantgist/smoke-mcp.sh
```

## Smoke tests

```bash
bash packages/twenty-docker/quantgist/smoke-mcp.sh
bash packages/twenty-docker/quantgist/smoke-postiz.sh
bash packages/twenty-docker/quantgist/smoke-campaign-workflow.sh
```

## Operational risks

| Risk | Mitigation |
|------|------------|
| Mac offline | Cloudflare 502; document restart; consider tunnel auto-reconnect |
| Single point of failure | Same as Postiz (`smm.quantgist.com`) — acceptable per Mac Docker decision |
| API key leak | Rotate in Twenty UI; update credentials file + backend Coolify env |

## Related docs

| Doc | Path |
|-----|------|
| Data model | `quantgist/CRM_DATA_MODEL.md` |
| Integration checklist | `quantgist/INTEGRATION_CHECKLIST.md` |
| OpenClaw CRM ops | `~/.openclaw/workspace/workspace_QuantGist/ops/TWENTY_CRM.md` |
| Backend user sync | `QuantGist-webapp/backend/scripts/backfill_users_to_crm.py` |
