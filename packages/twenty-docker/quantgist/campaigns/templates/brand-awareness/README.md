# Template — Brand Awareness

Grow reach and recognition among traders and developers. Copy to `campaigns/<id>/` and customize.

## When to use

- New market entry or repositioning
- Sustained top-of-funnel without a specific product ship
- Growing @quantgist following before a launch

## Required customization

1. `strategy.positioning` and `strategy.message`
2. `kpis.targets` — impressions, profile visits, follower growth
3. Matrix rows `ba-01` through `ba-05` (drop rows you will not schedule)
4. `posts-schedule.json` — align each post `matrix.rowId` with `contentMatrix`

## Validate and schedule

```bash
bash packages/twenty-docker/quantgist/validate-campaign.sh campaigns/<your-campaign>/
```

Copy `schedule-campaign.sh` from `campaigns/example-jun-2026-signals-launch/`.

Matrix reference: `CONTENT_MATRIX.md` (brand-awareness section).
