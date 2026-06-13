# QuantGist Campaign Strategy Framework

Strategic foundation for agent-driven social campaigns. Every post must map to **audience + goal + pillar + funnel stage** before scheduling.

**Positioning:** Traders and developers turn market news, macro events, and trading data into backtestable trading intelligence.

## 1. Brand overview

| Field | Value |
|-------|-------|
| Brand | QuantGist |
| Tagline | Market intelligence you can backtest |
| Voice | Data-driven, authoritative, premium fintech |
| Compliance | No financial advice, no guaranteed returns (`QG_COMPLIANCE_RULES`) |
| Active platforms | X, Facebook (LinkedIn Page pending CMA) |
| System of record | Postiz (`integrations.json`) |
| CRM | Twenty (campaign Notes, Opportunities, leads) |

## 2. Target audiences

| Audience ID | Who | What they care about | Example content |
|-------------|-----|----------------------|-----------------|
| `retail-traders` | Individual traders, swing/day traders | Actionable context, sentiment, macro catalysts | Market pulse alerts, chart insights, “what moved today” |
| `algo-quants` | Algo traders, quants, systematic funds | APIs, data pipelines, backtests, signal quality | API feature cards, backtest snippets, integration guides |
| `prop-firm-traders` | Prop firm challengers and funded traders | Risk rules, event volatility, fast macro reads | Volatility alerts, session prep threads, risk framing |
| `fintech-builders` | Developers building trading tools | SDKs, webhooks, architecture, build-in-public | Founder updates, technical threads, case studies |
| `investors-partners` | Angels, VCs, strategic partners | Traction, roadmap, market thesis | Milestone posts, market thesis threads, partnership CTAs |

Agents pick **one primary** and optionally **one secondary** audience per campaign (`campaign.json` → `strategy.audience`).

## 3. Goals and KPIs

| Goal ID | Objective | Primary KPIs | Owner |
|---------|-----------|--------------|-------|
| `brand-awareness` | Reach traders/devs who don't know QuantGist | Impressions, profile visits, follower growth | QG_ENGAGEMENT_ANALYST |
| `lead-generation` | Drive signups, demos, waitlist | Link clicks, landing conversions, CRM leads | QG_MARKETING |
| `product-launch` | Ship and adopt a feature/product | Feature page visits, activation, mentions | QG_CAMPAIGN_OPERATOR |
| `education` | Teach markets + platform usage | Saves, shares, thread depth, time on site | QG_CONTENT_CREATOR |
| `community` | Feedback, replies, Discord/Telegram growth | Reply rate, community joins, survey responses | QG_HR / QG_MARKETING |
| `event-promotion` | Registrations for webinars, launches, AMAs | RSVP clicks, calendar adds, live attendance | QG_CAMPAIGN_OPERATOR |

Set `strategy.goal` and `kpis` in `campaign.json`. QG_ENGAGEMENT_ANALYST reports against these after each biweekly review.

## 4. Content pillars

| Pillar ID | Focus | Best formats |
|-----------|-------|--------------|
| `market-intelligence` | Macro, news, sentiment, catalysts | Chart insight, market news alert, threads |
| `trading-education` | Concepts, risk, execution | Carousels, threads, quote cards |
| `product-education` | Features, workflows, how-to | API feature card, demo clips, screenshots |
| `case-studies` | User outcomes, backtests | Case study template, before/after charts |
| `founder-building-in-public` | Roadmap, shipping, lessons | Quote card, short video, X threads |
| `community-content` | Polls, AMAs, feedback loops | Polls, questions, event banners |

Every post in `posts-schedule.json` must include `matrix.pillar`.

## 5. Funnel stages

```
Awareness → Education → Proof → Conversion → Retention
```

| Stage ID | Purpose | Typical CTAs | Agent owner |
|----------|---------|--------------|-------------|
| `awareness` | Reach new audience | Follow, share, learn more | QG_CONTENT_CREATOR |
| `education` | Explain value and usage | Read thread, save post | QG_CONTENT_CREATOR |
| `proof` | Social proof, case studies | See results, view backtest | QG_MARKETING |
| `conversion` | Signup, demo, trial | quantgist.com, waitlist | QG_CAMPAIGN_OPERATOR |
| `retention` | Keep users engaged | Discord, changelog, feedback | QG_HR |

Map each post slot to `matrix.funnelStage`. Campaigns should span at least 3 funnel stages unless single-purpose (e.g. event day).

## 6. Channel strategy

| Channel | Role | Content types | Status |
|---------|------|---------------|--------|
| X (`x`) | Fast takes, charts, threads | Short copy, chart insight, threads | ✅ Active |
| Facebook (`facebook`) | Longer context, community | Expanded copy, carousels | ✅ Active |
| LinkedIn Page (`linkedin-page`) | Professional, B2B | Case studies, thought leadership | ❌ Blocked (CMA) |
| Discord / Telegram | Community, feedback | AMAs, polls, support routing | Community only (not Postiz) |

Platform-specific copy lives in `posts-schedule.json` under `x`, `facebook`, etc. See `integrations.json` for integration IDs.

## 7. Campaign types

Four primary templates under `campaigns/templates/`:

| Type ID | Use when | Template path |
|---------|----------|---------------|
| `product-launch` | Shipping a feature or product | `campaigns/templates/product-launch/` |
| `brand-awareness` | Growing reach and recognition | `campaigns/templates/brand-awareness/` |
| `lead-generation` | Driving signups and demos | `campaigns/templates/lead-generation/` |
| `event-promotion` | Webinars, AMAs, conference days | `campaigns/templates/event-promotion/` |

**Agent rule:** QG_MARKETING selects campaign type + primary audience before any copy work. No ad-hoc posts outside an active campaign folder.

## 8. Campaign document structure (11 sections)

Every campaign folder must satisfy these sections (in `campaign.json` or linked docs):

1. Brand overview — `brand` block
2. Audience — `strategy.audience`
3. Goals — `strategy.goal` + `kpis`
4. Strategy — `strategy.positioning`, `strategy.message`, `strategy.channels`
5. Pillars — `strategy.contentPillars`
6. Matrix — `contentMatrix` (rows) + per-post `matrix` in schedule
7. Types — `campaignType`
8. Canva workflow — `canva.templates`
9. Roles — `roles` (agent assignments)
10. KPIs — `kpis` (targets + measurement)
11. Weekly plan — `weeklyPlan`

Validate with `bash packages/twenty-docker/quantgist/validate-campaign.sh <campaign-dir>`.

## 9. Team roles (agent mapping)

| Role | Agent | Responsibilities |
|------|-------|------------------|
| Marketing Strategist | `QG_MARKETING` | Pick type, audience, goal; approve matrix; CRM logging |
| Content Writer | `QG_CONTENT_CREATOR` | Copy per matrix row; platform variants |
| Designer | `QG_CONTENT_CREATOR` + Canva API | Template selection, asset briefs (`CANVA_MULTIMEDIA_WORKFLOW.md`) |
| Video Editor | `QG_CONTENT_CREATOR` | Short clips for Wed slot (optional; external tool) |
| SMM | `QG_SOCIAL_MEDIA_MANAGER` | Postiz schedule/publish per funnel calendar |
| Campaign Operator | `QG_CAMPAIGN_OPERATOR` | Batch launch, `schedule-campaign.sh`, queue verify |
| Growth / Analytics | `QG_ENGAGEMENT_ANALYST` | KPI tracking, optimization notes |

## 10. Weekly operating system

| Day | Focus | Lead agent |
|-----|-------|------------|
| Monday | Plan — pick campaign type, audience, matrix rows | QG_MARKETING |
| Tuesday | Copy + graphics — drafts + Canva variations | QG_CONTENT_CREATOR |
| Wednesday | Video — short demos or founder clips (if needed) | QG_CONTENT_CREATOR |
| Thursday | Schedule — Postiz drafts, verify queue | QG_SOCIAL_MEDIA_MANAGER |
| Friday | Analytics — KPI snapshot, feedback for next week | QG_ENGAGEMENT_ANALYST |
| Weekend | Community — Discord/Telegram engagement | QG_HR / QG_MARKETING |

Biweekly **human** Postiz review remains the approval gate (`SOCIAL_CAMPAIGNS_RUNBOOK.md`).

## 11. Related docs

| Doc | Purpose |
|-----|---------|
| `CONTENT_MATRIX.md` | Audience × goal × pillar × format × platform × CTA |
| `CANVA_MULTIMEDIA_WORKFLOW.md` | Template catalog and API automation |
| `campaigns/SCHEMA.md` | `campaign.json` required fields |
| `SOCIAL_CAMPAIGNS_RUNBOOK.md` | Postiz ops, feedback loop |
| `integrations.json` | Platform IDs, Canva placeholders |
