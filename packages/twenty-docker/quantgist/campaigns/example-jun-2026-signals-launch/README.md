# Example Campaign — Market Signals Launch (Jun 2026)

**Strategic product-launch example** with full `campaign.json` metadata. Demonstrates audience × goal × pillar × funnel mapping for every post.

Based on template: `campaigns/templates/product-launch/`

## Files

| File | Purpose |
|------|---------|
| `campaign.json` | Strategic metadata, contentMatrix, KPIs, roles |
| `posts-schedule.json` | Three posts with `matrix` blocks (pl-01, pl-02, pl-06) |
| `schedule-campaign.sh` | Schedules via Postiz CLI |

## Validate before scheduling

```bash
bash packages/twenty-docker/quantgist/validate-campaign.sh campaigns/example-jun-2026-signals-launch/
```

## Agent workflow

1. **QG_MARKETING** — owns `campaignType: product-launch`, audience, KPIs
2. **QG_CONTENT_CREATOR** — copy per matrix row (or use `posts-schedule.json`)
3. **QG_MARKETING** — compliance review (`QG_COMPLIANCE_RULES`)
4. **QG_SOCIAL_MEDIA_MANAGER** — schedule drafts:

```bash
bash packages/twenty-docker/quantgist/campaigns/example-jun-2026-signals-launch/schedule-campaign.sh --dry-run
bash packages/twenty-docker/quantgist/campaigns/example-jun-2026-signals-launch/schedule-campaign.sh
```

5. **QG_CAMPAIGN_OPERATOR** — `postiz posts:list`
6. **QG_ENGAGEMENT_ANALYST** — report KPIs by `matrix.rowId` after biweekly review

## Funnel coverage

| Post | Matrix row | Funnel stage |
|------|------------|--------------|
| post-1-market-pulse | pl-01 | awareness |
| post-2-how-it-works | pl-02 | education |
| post-3-build-in-public | pl-06 | retention |

## Related docs

- `CAMPAIGN_STRATEGY.md` — framework
- `CONTENT_MATRIX.md` — pl-* rows
- `SOCIAL_CAMPAIGNS_RUNBOOK.md` — Postiz ops
