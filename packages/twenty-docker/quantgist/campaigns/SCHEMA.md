# campaign.json Schema

Required fields for agent validation before `schedule-campaign.sh`. Run:

```bash
bash packages/twenty-docker/quantgist/validate-campaign.sh <campaign-directory>
```

## Top-level fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | yes | Unique slug, kebab-case |
| `name` | string | yes | Human-readable campaign name |
| `campaignType` | enum | yes | `product-launch`, `brand-awareness`, `lead-generation`, `event-promotion` |
| `status` | enum | yes | `draft`, `active`, `completed`, `archived` |
| `owner` | string | yes | Agent ID (e.g. `QG_MARKETING`) |
| `operators` | string[] | yes | Agent IDs with schedule rights |
| `platforms` | string[] | yes | Subset of `x`, `facebook` (active only) |
| `excludedPlatforms` | string[] | no | e.g. `linkedin-page` |
| `integrationIds` | object | yes | Map platform → Postiz integration ID |
| `brand` | object | yes | Brand context (see below) |
| `strategy` | object | yes | Audience, goal, positioning (see below) |
| `kpis` | object | yes | Targets and measurement |
| `contentMatrix` | array | yes | Matrix rows for this campaign |
| `canva` | object | no | Template refs (recommended) |
| `roles` | object | yes | Agent role assignments |
| `weeklyPlan` | object | yes | Mon–Fri focus |
| `postizUiReviewUrl` | string | no | Default Postiz calendar URL |
| `biweeklyReviewCadence` | string | no | Human review note |

## brand

```json
{
  "positioning": "Traders and developers turn market news...",
  "voice": "data-driven, authoritative, premium fintech",
  "complianceRef": "QG_COMPLIANCE_RULES"
}
```

## strategy

```json
{
  "audience": {
    "primary": "algo-quants",
    "secondary": "retail-traders"
  },
  "goal": "product-launch",
  "positioning": "One-line campaign positioning",
  "message": "Core message for all posts",
  "contentPillars": ["market-intelligence", "product-education"],
  "channels": ["x", "facebook"],
  "funnelMapping": ["awareness", "education", "proof", "conversion"]
}
```

### Audience IDs

`retail-traders`, `algo-quants`, `prop-firm-traders`, `fintech-builders`, `investors-partners`

### Goal IDs

`brand-awareness`, `lead-generation`, `product-launch`, `education`, `community`, `event-promotion`

### Pillar IDs

`market-intelligence`, `trading-education`, `product-education`, `case-studies`, `founder-building-in-public`, `community-content`

## kpis

```json
{
  "primary": "feature-page-visits",
  "targets": {
    "impressions": 50000,
    "linkClicks": 500,
    "conversions": 50
  },
  "measurement": "postiz analytics + Twenty CRM leads tagged with campaign id",
  "reviewCadence": "biweekly"
}
```

## contentMatrix[] row

```json
{
  "rowId": "pl-01",
  "audience": "retail-traders",
  "goal": "product-launch",
  "pillar": "market-intelligence",
  "format": "market-news-alert",
  "platforms": ["x", "facebook"],
  "funnelStage": "awareness",
  "cta": "learn-more",
  "canvaTemplate": "market-news-alert",
  "scheduledDay": "monday"
}
```

## roles

```json
{
  "strategist": "QG_MARKETING",
  "contentWriter": "QG_CONTENT_CREATOR",
  "designer": "QG_CONTENT_CREATOR",
  "smm": "QG_SOCIAL_MEDIA_MANAGER",
  "campaignOperator": "QG_CAMPAIGN_OPERATOR",
  "analyst": "QG_ENGAGEMENT_ANALYST"
}
```

## weeklyPlan

```json
{
  "monday": "Plan — finalize matrix rows",
  "tuesday": "Copy + Canva assets",
  "wednesday": "Video clip (optional)",
  "thursday": "Schedule Postiz drafts",
  "friday": "KPI snapshot"
}
```

## posts-schedule.json

| Field | Required | Description |
|-------|----------|-------------|
| `posts` | yes | Array of post objects |
| `posts[].id` | yes | Unique post slug |
| `posts[].scheduledAt` | yes | ISO 8601 UTC |
| `posts[].matrix` | yes | Must match a `contentMatrix` row |
| `posts[].x.content` | if platform x | Max 280 chars recommended |
| `posts[].facebook.content` | if platform facebook | Longer form |
| `posts[].media` | no | Canva export URLs |
| `posts[].tags` | no | Freeform tags |

### posts[].matrix

```json
{
  "rowId": "pl-01",
  "audience": "retail-traders",
  "goal": "product-launch",
  "pillar": "market-intelligence",
  "format": "market-news-alert",
  "funnelStage": "awareness",
  "cta": "learn-more"
}
```

## UTM links (required in post copy)

Every post CTA URL must include UTM parameters matching the campaign `id`:

```
https://quantgist.com/waitlist?utm_source={platform}&utm_medium=social&utm_campaign={campaign.id}
```

- `{platform}` = `x`, `facebook`, or `linkedin`
- `{campaign.id}` = top-level `id` from `campaign.json` (e.g. `jun-2026-lead-generation`)

`validate-campaign.sh` warns when `utm_campaign` does not match campaign `id`.

## Validation rules

1. `campaignType` must be one of four primary types.
2. `strategy.audience.primary` must be a valid audience ID.
3. `strategy.goal` must align with `campaignType` (warnings only for mismatch).
4. Every `contentMatrix` row must have unique `rowId`.
5. Every post `matrix.rowId` must exist in `contentMatrix`.
6. Every post must include platform blocks for each entry in `platforms`.
7. `integrationIds` must match `integrations.json` for active platforms.
