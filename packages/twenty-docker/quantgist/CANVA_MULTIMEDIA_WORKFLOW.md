# Canva Multimedia Workflow — QuantGist

Automated visual assets for social campaigns via the **Canva Connect API**. Designers define templates once; agents generate variations per campaign matrix row.

## Status

| Item | Status |
|------|--------|
| Canva API credentials | **Client ID/secret set** in `~/.openclaw/credentials/canva-quantgist.env` |
| OAuth access token | **Pending** — run `canva-oauth-bootstrap.sh` (browser authorize) |
| Template IDs in `integrations.json` | Placeholders — replace after Canva brand kit setup |
| Bootstrap script | `bootstrap-canva-env.sh` → sources `canva-quantgist.env` |
| Smoke test | `smoke-canva.sh` |
| Postiz scheduling | `schedule-campaign.sh --with-canva` attaches `media.exportUrl` or generates via API |

## Workflow

```
1. QG_MARKETING     → campaign type + contentMatrix rows
2. QG_CONTENT_CREATOR → copy per row (headline, body, CTA text)
3. Designer / Creator → pick Canva template per format (integrations.json)
4. Canva API        → autofill + export PNG/WebP per variation
5. QG_SOCIAL_MEDIA_MANAGER → `postiz upload-from-url` then `posts:create` (copy + media)
6. QG_MARKETING → sync Campaign to Twenty + store `canvaDesignId` on Campaign record
7. QG_ENGAGEMENT_ANALYST → track KPIs by matrix rowId
```

## Postiz asset handoff

1. `QG_CANVA_DESIGNER` exports asset URL from Canva Connect API
2. `QG_SOCIAL_MEDIA_MANAGER` runs `postiz upload-from-url` before `posts:create`
3. Campaign record in Twenty stores `canvaDesignId` from `posts-schedule.json` `media.canvaDesignId`

## Template catalog

Reusable brand templates (create in Canva Brand Kit, then register IDs in `integrations.json`):

| Template key | Use case | Autofill fields |
|--------------|----------|-----------------|
| `market-news-alert` | Macro headline posts | `headline`, `subhead`, `tag`, `date` |
| `chart-insight` | Chart + one insight | `chart_image_url`, `insight`, `ticker` |
| `api-feature-card` | Feature launches | `feature_name`, `description`, `code_snippet` |
| `quote-card` | Founder / building in public | `quote`, `attribution`, `avatar_url` |
| `event-banner` | Webinars, AMAs | `event_title`, `date_time`, `cta_text`, `url` |
| `carousel` | Education series | `slides[]` (title, body per slide) |
| `case-study` | Proof posts | `metric`, `context`, `logo_url` |

## Setup (one-time)

### 1. Canva developer app

1. Create an app at [Canva Developers](https://www.canva.com/developers/).
2. Enable **Connect API** scopes: `design:content:read`, `design:content:write`, `asset:read`, `asset:write`.
3. Note **Client ID** and **Client Secret**.

### 2. Credentials on OpenClaw host

Primary file (single source of truth):

```bash
~/.openclaw/credentials/canva-quantgist.env   # chmod 600 — NEVER commit
```

```bash
bash packages/twenty-docker/quantgist/bootstrap-canva-env.sh
bash packages/twenty-docker/quantgist/canva-oauth-bootstrap.sh
# Authorize in browser → copy code from redirect URL
bash packages/twenty-docker/quantgist/canva-oauth-bootstrap.sh --exchange '<code>'
bash packages/twenty-docker/quantgist/smoke-canva.sh
```

`bootstrap-canva-env.sh` also syncs legacy paths:

- `~/.openclaw/credentials/canva-client-id.txt`
- `~/.openclaw/credentials/canva-client-secret.txt`
- `~/.openclaw/credentials/canva-access-token.txt` (after OAuth)

Add to `~/.openclaw/.env`:

```bash
if [[ -f ~/.openclaw/credentials/canva-quantgist.env ]]; then
  source ~/.openclaw/credentials/canva-quantgist.env
fi
```

Register redirect URI in Canva developer portal: `http://127.0.0.1:8765/oauth/canva/callback` (or value of `CANVA_REDIRECT_URI`).

### 3. Register template IDs

After creating templates in Canva, copy design template IDs into `integrations.json` → `canva.templates`. Each entry needs `designId` and `brandKitId` when using brand templates.

### 4. OAuth token refresh

Canva access tokens expire. Store refresh token in `canva-refresh-token.txt` and refresh before batch generation (see Canva Connect API docs for `/oauth/token`).

## API operations (agent reference)

Agents do **not** call Canva until credentials exist. When configured:

### Autofill from template

```bash
# Pseudocode — replace DESIGN_ID and fields from matrix row
curl -s -X POST "https://api.canva.com/rest/v1/autofills" \
  -H "Authorization: Bearer ${CANVA_ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "brand_template_id": "DESIGN_ID",
    "data": {
      "headline": { "type": "text", "text": "Fed decision: what changed" },
      "subhead": { "type": "text", "text": "QuantGist Market Signals" }
    }
  }'
```

### Export design

Poll autofill job → export as PNG → upload to Postiz media library or CDN → reference in `posts-schedule.json` → `media.url`.

### Link to campaign

In `posts-schedule.json`:

```json
"media": {
  "canvaTemplate": "market-news-alert",
  "canvaDesignId": "PLACEHOLDER",
  "exportUrl": "https://cdn.quantgist.com/campaigns/..."
}
```

## Agent responsibilities

| Agent | Canva task |
|-------|------------|
| QG_MARKETING | Approve template set per campaign type |
| QG_CONTENT_CREATOR | Supply autofill field values from matrix copy |
| QG_SOCIAL_MEDIA_MANAGER | Attach exported assets when scheduling (if Postiz supports media on integration) |
| QG_CAMPAIGN_OPERATOR | Verify assets exist before `schedule-campaign.sh` |

## Failure handling

| Symptom | Action |
|---------|--------|
| No Canva credentials | Text-only posts OK; note in campaign README; run `bootstrap-canva-env.sh` |
| Autofill 401 | Refresh OAuth token; check scopes |
| Missing template ID | Fall back to text post; log gap in Twenty Note |
| Export timeout | Retry once; use smaller image dimensions |

## Related files

- `integrations.json` — `canva.templates` placeholders
- `bootstrap-canva-env.sh` — credential bootstrap
- `canva-oauth-bootstrap.sh` — PKCE OAuth URL + token exchange
- `smoke-canva.sh` — connectivity check
- `canva-export-from-template.sh` — autofill + PNG export
- `CONTENT_MATRIX.md` — format → template mapping
- `campaigns/templates/*/campaign.json` — per-type `canva.templates` refs
