# Template — Product Launch

Use when shipping a feature or product. Copy this folder to `campaigns/<your-campaign-id>/` and customize.

## Required fields checklist

- [ ] `id`, `name` — unique campaign slug and title
- [ ] `strategy.positioning`, `strategy.message` — launch-specific copy
- [ ] `strategy.audience.primary` — pick from `CAMPAIGN_STRATEGY.md`
- [ ] `kpis.targets` — realistic for launch window
- [ ] `contentMatrix` — keep or adjust rows (see `CONTENT_MATRIX.md` pl-* rows)
- [ ] `posts-schedule.json` — one post per matrix row you schedule; each needs `matrix` block
- [ ] Replace `REPLACE_WITH_ISO_UTC` dates and `[REPLACE]` copy
- [ ] Run validation before scheduling

## Workflow

```bash
cp -r campaigns/templates/product-launch campaigns/my-feature-launch
# Edit campaign.json + posts-schedule.json
cp campaigns/example-jun-2026-signals-launch/schedule-campaign.sh campaigns/my-feature-launch/

bash packages/twenty-docker/quantgist/validate-campaign.sh campaigns/my-feature-launch/
bash campaigns/my-feature-launch/schedule-campaign.sh --dry-run
```

## Strategic reference

| Section | Location |
|---------|----------|
| Audiences, goals, pillars | `CAMPAIGN_STRATEGY.md` |
| Matrix rows pl-01–pl-06 | `CONTENT_MATRIX.md` |
| Canva templates | `CANVA_MULTIMEDIA_WORKFLOW.md` |
| Schema | `campaigns/SCHEMA.md` |

## Example campaign

See `campaigns/example-jun-2026-signals-launch/` for a filled product-launch instance.
