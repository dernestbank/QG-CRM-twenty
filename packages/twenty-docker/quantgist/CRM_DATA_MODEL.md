# QuantGist Twenty CRM Data Model

> Configure in Twenty UI: **Settings → Data model**. API field names below must match
> exactly — the backend sync and lead ingest services use these names.

## Person (contacts)

### Existing sync fields (API users)

| API name | Type | Source |
|----------|------|--------|
| `qgUserId` | TEXT | QuantGist user UUID |
| `planCustom` | SELECT/TEXT | `free`, `starter`, `pro`, `team`, `enterprise` |
| `subscriptionStatus` | SELECT/TEXT | Stripe: `active`, `trialing`, `past_due`, `cancelled` |
| `signupDate` | DATE_TIME | Account created_at |

### Marketing funnel fields

| API name | Type | Values |
|----------|------|--------|
| `leadSource` | SELECT | LinkedIn, X, YouTube, Website, Webinar, Referral, Discord |
| `audienceSegment` | SELECT | Retail Trader, Algo Trader, Prop Trader, Developer, Investor, Partner |
| `productInterest` | MULTI_SELECT | Macro News API, Economic Calendar, NQ Dataset, Trading Indicators, Backtesting Tool |
| `funnelStage` | SELECT | New, Warm, Hot, Trial, Customer, Inactive |
| `nextAction` | TEXT | e.g. Send API demo |
| `utmSource` | TEXT | UTM source param |
| `utmCampaign` | TEXT | UTM campaign param |
| `activatedAt` | DATE_TIME | First API call |
| `lastApiCallAt` | DATE_TIME | Most recent API usage |

### Person setup checklist

1. Settings → Data model → Person → Add **core** fields first: `qgUserId`, `planCustom`, `subscriptionStatus`, `signupDate`.
2. Run `uv run python scripts/backfill_users_to_crm.py --probe` — core fields must pass.
3. Set `CRM_SYNC_ENABLED=true` on API backend, then backfill existing users:
   ```bash
   uv run python scripts/backfill_users_to_crm.py --dry-run
   uv run python scripts/backfill_users_to_crm.py
   # Or via admin API:
   curl -X POST https://api.quantgist.com/v1/admin/crm/backfill-users \
     -H "X-Admin-Key: $ADMIN_SECRET_KEY" -H "Content-Type: application/json" \
     -d '{"dry_run": false}'
   ```
4. Add marketing fields when ready; set `CRM_MARKETING_FIELDS_ENABLED=true`.

### User sync triggers (backend → CRM)

| Event | Sync |
|-------|------|
| `POST /v1/auth/register` | New user → Person (merges with waitlist Person by email) |
| Google OAuth new user | Same via Celery |
| `POST /v1/auth/login` | Catch-up sync for users missing from CRM |
| Stripe billing webhook | Plan/subscription update |
| Waitlist form | Person via lead ingest (before account exists) |

---

## Company

Use standard Twenty Company object. Link to Person when waitlist or contact form includes `company`.

| Use case | Example |
|----------|---------|
| Prop trading firm | B2B customer |
| Fintech startup | API customer |
| University lab | Research user |

---

## Campaign (custom object)

Create object **Campaign** (singular label: Campaign, plural: Campaigns).

| API name | Type | Notes |
|----------|------|-------|
| `name` | TEXT | Human-readable name |
| `campaignType` | SELECT | product-launch, brand-awareness, lead-generation, event-promotion |
| `goal` | TEXT | awareness / leads / trials / revenue |
| `status` | SELECT | planning, active, paused, completed |
| `startDate` | DATE | Campaign start |
| `endDate` | DATE | Campaign end |
| `primaryAudience` | SELECT | Same values as `audienceSegment` |
| `utmCampaign` | TEXT | Matches Postiz UTM `utm_campaign` |
| `postizCampaignId` | TEXT | `campaign.json` `id` slug |
| `platforms` | TEXT | Comma-separated: X, LinkedIn, Facebook |
| `canvaDesignId` | TEXT | Optional Canva design reference |

### Relations

| Relation | Type | Label |
|----------|------|-------|
| Campaign → Person | MANY_TO_MANY | Leads from campaign |
| Campaign → Opportunity | ONE_TO_MANY | Deals from campaign |

REST endpoint after creation: `POST /rest/campaigns`

---

## Opportunity (deals)

### Pipeline: QuantGist Growth Pipeline

Configure stages in Settings → Objects → Opportunity:

| Stage | Definition | Owner action |
|-------|------------|--------------|
| Captured Lead | Form submit, download, event signup | Add source + interest |
| Segmented | Classified by audience | Tag segment |
| Qualified | Real business opportunity | Assign owner |
| Nurturing | Educational sequence | Email / community invite |
| Demo / Trial | Testing API or dashboard | Send onboarding |
| Conversion | Paid or subscribed | Close deal |
| Retention | Active customer | Upsell, support |

Twenty stores stage API values in UPPER_SNAKE_CASE (e.g. `CAPTURED_LEAD`). Map UI labels accordingly.



---

## Task

Standard Twenty Task object. Created automatically on waitlist submit:

- Title: `Follow up: {firstName} {lastName} — waitlist`
- Due: 24 hours from capture
- Body: role, use case, UTM, campaign link

REST: `POST /rest/tasks`

---

## Note

Standard Twenty Note. Used for:

- Postiz publish events (platform, post ID, URL)
- Contact form inquiry body
- Social lead intake from agents

REST: `POST /rest/notes` + note target linking to Person or Campaign.

---

## Tags (recommended)

Use Person SELECT fields above instead of Twenty native tags for consistency.
Optional native tags for quick filters: `API Launch`, `Webinar`, `Lead Magnet`.

---

## Validation

```bash
# From QuantGist-webapp repo
cd backend && uv run python scripts/backfill_users_to_crm.py --probe

# From QG-CRM-twenty repo
bash packages/twenty-docker/quantgist/smoke-mcp.sh
```

Expected probe output: `reachable: true` and all `expected_custom_fields` present in `person_fields`.
