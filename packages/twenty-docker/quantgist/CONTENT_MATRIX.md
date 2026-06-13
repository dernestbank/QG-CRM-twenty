# QuantGist Content Matrix

The content matrix connects **audience × goal × pillar × format × platform × CTA** so every scheduled post is intentional. Agents must not post outside this mapping.

## How agents use the matrix

```
QG_MARKETING
  → Defines campaign type + audience + goal
  → Selects matrix rows for the campaign (campaign.json → contentMatrix)
QG_CONTENT_CREATOR
  → Writes copy for each row; picks format + Canva template ref
QG_SOCIAL_MEDIA_MANAGER
  → Schedules posts in funnel order (awareness → … → conversion)
QG_ENGAGEMENT_ANALYST
  → Tags analytics back to matrix row IDs for KPI reporting
```

### Per-post requirements (`posts-schedule.json`)

Each post object must include:

```json
"matrix": {
  "rowId": "pl-01",
  "audience": "algo-quants",
  "goal": "product-launch",
  "pillar": "product-education",
  "format": "api-feature-card",
  "funnelStage": "education",
  "cta": "explore-feature"
}
```

Optional: `canvaTemplateId` (from `integrations.json` → `canva.templates`).

## Master matrix (reference rows)

Use these as templates when building `contentMatrix` in `campaign.json`. Copy relevant rows into your campaign and assign `rowId` prefixes by type (`pl-`, `ba-`, `lg-`, `ev-`).

### Product launch (`product-launch`)

| rowId | Audience | Goal | Pillar | Format | Platform | Funnel | CTA |
|-------|----------|------|--------|--------|----------|--------|-----|
| pl-01 | retail-traders | product-launch | market-intelligence | market-news-alert | x, facebook | awareness | learn-more |
| pl-02 | algo-quants | product-launch | product-education | api-feature-card | x, facebook | education | explore-feature |
| pl-03 | fintech-builders | product-launch | founder-building-in-public | quote-card | x | proof | follow-roadmap |
| pl-04 | retail-traders | product-launch | case-studies | case-study | facebook | proof | view-results |
| pl-05 | algo-quants | product-launch | product-education | chart-insight | x | conversion | start-trial |
| pl-06 | retail-traders | community | community-content | poll | x, facebook | retention | reply-feedback |

### Brand awareness (`brand-awareness`)

| rowId | Audience | Goal | Pillar | Format | Platform | Funnel | CTA |
|-------|----------|------|--------|--------|----------|--------|-----|
| ba-01 | retail-traders | brand-awareness | market-intelligence | chart-insight | x | awareness | follow |
| ba-02 | prop-firm-traders | brand-awareness | trading-education | carousel | facebook | education | save-post |
| ba-03 | investors-partners | brand-awareness | founder-building-in-public | quote-card | x, facebook | proof | read-thesis |
| ba-04 | fintech-builders | brand-awareness | product-education | thread | x | education | share |
| ba-05 | retail-traders | brand-awareness | community-content | poll | x | retention | join-discord |

### Lead generation (`lead-generation`)

| rowId | Audience | Goal | Pillar | Format | Platform | Funnel | CTA |
|-------|----------|------|--------|--------|----------|--------|-----|
| lg-01 | algo-quants | lead-generation | product-education | api-feature-card | x, facebook | awareness | learn-more |
| lg-02 | retail-traders | lead-generation | trading-education | carousel | facebook | education | read-guide |
| lg-03 | prop-firm-traders | lead-generation | case-studies | case-study | facebook | proof | see-backtest |
| lg-04 | fintech-builders | lead-generation | product-education | chart-insight | x | conversion | sign-up |
| lg-05 | investors-partners | lead-generation | founder-building-in-public | quote-card | x | conversion | book-demo |

### Event promotion (`event-promotion`)

| rowId | Audience | Goal | Pillar | Format | Platform | Funnel | CTA |
|-------|----------|------|--------|--------|----------|--------|-----|
| ev-01 | retail-traders | event-promotion | market-intelligence | event-banner | x, facebook | awareness | register |
| ev-02 | algo-quants | event-promotion | product-education | api-feature-card | x | education | add-calendar |
| ev-03 | fintech-builders | event-promotion | founder-building-in-public | quote-card | x | proof | share-event |
| ev-04 | retail-traders | event-promotion | community-content | poll | facebook | retention | ask-question |
| ev-05 | all | event-promotion | trading-education | carousel | facebook | conversion | join-live |

## CTA catalog

| CTA ID | Copy pattern | Destination |
|--------|--------------|-------------|
| `learn-more` | "Learn more → quantgist.com" | Homepage |
| `explore-feature` | "Explore [feature] → quantgist.com/[path]" | Feature page |
| `start-trial` | "Try it → quantgist.com/signup" | Signup |
| `sign-up` | "Get started → quantgist.com/signup" | Signup |
| `book-demo` | "Book a demo → quantgist.com/contact" | Contact |
| `register` | "Register → [event URL]" | Event landing |
| `add-calendar` | "Add to calendar → [link]" | Calendar link |
| `join-live` | "Join live → [stream URL]" | Live stream |
| `follow` | "Follow @quantgist for daily context" | Profile |
| `join-discord` | "Join Discord → [invite]" | Discord |
| `reply-feedback` | "Reply with what you want next" | Engagement |
| `view-results` | "See the backtest → quantgist.com" | Case study |

## Format → Canva template mapping

| Format ID | Canva template key | Notes |
|-----------|-------------------|-------|
| `market-news-alert` | `market-news-alert` | Headline + macro tag |
| `chart-insight` | `chart-insight` | Chart screenshot + 1 insight |
| `api-feature-card` | `api-feature-card` | Feature name + code snippet area |
| `quote-card` | `quote-card` | Founder quote |
| `event-banner` | `event-banner` | Date, title, CTA |
| `carousel` | `carousel` | 3–5 slides |
| `case-study` | `case-study` | Result metric + context |
| `thread` | _(text only on X)_ | No Canva required |
| `poll` | _(native X/Facebook)_ | No Canva required |

See `CANVA_MULTIMEDIA_WORKFLOW.md` for API generation steps.

## Validation checklist (before schedule)

- [ ] Every post has `matrix` with all six dimensions + `rowId`
- [ ] `matrix.rowId` exists in campaign `contentMatrix`
- [ ] Funnel stages progress logically across the week
- [ ] At least one post per primary audience (or documented exception in `campaign.json`)
- [ ] CTAs match funnel stage (no `start-trial` on pure awareness without education posts)
- [ ] `validate-campaign.sh` passes

```bash
bash packages/twenty-docker/quantgist/validate-campaign.sh campaigns/my-campaign/
```
