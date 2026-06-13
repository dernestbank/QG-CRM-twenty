# Social Campaigns Runbook — QuantGist Agents

Operational guide for **strategic** agent-driven campaigns: **plan with framework → validate → Postiz drafts → biweekly review → feedback → KPI loop**.

## Strategic framework (required)

Every campaign must use the framework — no random posts.

| Doc | Purpose |
|-----|---------|
| `CAMPAIGN_STRATEGY.md` | Audiences, goals, pillars, funnel, weekly OS |
| `CONTENT_MATRIX.md` | Audience × goal × pillar × format × platform × CTA |
| `CANVA_MULTIMEDIA_WORKFLOW.md` | Template catalog + API setup |
| `campaigns/SCHEMA.md` | `campaign.json` required fields |
| `campaigns/templates/` | Four campaign types (copy to `campaigns/<id>/`) |

```bash
# Validate before any schedule
bash packages/twenty-docker/quantgist/validate-campaign.sh campaigns/<campaign-dir>/
```

## Architecture

```
QG_MARKETING (orchestrator)
  ├── QG_CONTENT_CREATOR     → draft copy
  ├── QG_SOCIAL_MEDIA_MANAGER → Postiz schedule/publish (X, Facebook)
  ├── QG_CAMPAIGN_OPERATOR   → batch launches, queue verification
  └── QG_ENGAGEMENT_ANALYST  → Postiz analytics, optimization notes

Postiz (https://smm.quantgist.com)  ← system of record for scheduling
Twenty CRM (MCP)                    ← leads, opportunities, campaign notes
Telegram topic 5 / Discord #qg_marketing ← feedback & adjustments
```

## Active platforms (today)

| Platform | Postiz ID | Status |
|----------|-----------|--------|
| X (@quantgist) | `cmq55s5iy0001qttunmxabaf5` | ✅ Use in campaigns |
| Facebook (QuantGist page) | `cmq4clbth0001qkqsznluxtud` | ✅ Use in campaigns |
| LinkedIn Page (company) | _none_ | ❌ Blocked — skip until CMA approved |
| LinkedIn (personal) | `cmq3r9kon0001pjbed2gzl2v5` | Connected but **not** used for brand campaigns |

See `integrations.json` for canonical IDs.

## Prerequisites (one-time)

1. **Twenty** — Docker up, API key in `~/.openclaw/credentials/twenty-quantgist-api-key.txt`
2. **Postiz** — API key in `~/.openclaw/credentials/postiz-quantgist-api-key.txt`
3. **OpenClaw** — `mcp.servers.twenty` in `~/.openclaw/openclaw.json`, `POSTIZ_*` in `~/.openclaw/.env`
4. **postiz CLI** — `npm install -g postiz` (or use OpenClaw postiz skill)

```bash
bash packages/twenty-docker/quantgist/bootstrap-api-key.sh
bash packages/twenty-docker/quantgist/bootstrap-postiz-env.sh
bash packages/twenty-docker/quantgist/smoke-campaign-workflow.sh
```

## Daily agent loop

### 1. Setup and test

```bash
# Full workflow smoke (Twenty MCP + Postiz + feedback config)
bash packages/twenty-docker/quantgist/smoke-campaign-workflow.sh

# Postiz only
bash packages/twenty-docker/quantgist/smoke-postiz.sh

# Twenty MCP only
bash packages/twenty-docker/quantgist/smoke-mcp.sh
```

### 2. Create or load campaign

1. Pick campaign type: `product-launch`, `brand-awareness`, `lead-generation`, or `event-promotion`.
2. Copy from `campaigns/templates/<type>/` or use `campaigns/example-jun-2026-signals-launch/` (product-launch example).
3. Fill `campaign.json` — audience, goal, contentMatrix, KPIs, roles, weeklyPlan.
4. Edit `posts-schedule.json` — each post needs `matrix` block matching a contentMatrix row.
5. Validate: `bash packages/twenty-docker/quantgist/validate-campaign.sh <dir>/`
6. Default: schedule as **draft** for user review.

### 3. Schedule posts (agents)

```bash
source packages/twenty-docker/quantgist/bootstrap-postiz-env.sh

# Dry run
bash campaigns/example-jun-2026-signals-launch/schedule-campaign.sh --dry-run

# Create drafts in Postiz
bash campaigns/example-jun-2026-signals-launch/schedule-campaign.sh

# Verify queue
postiz posts:list
```

Single post (manual):

```bash
# X requires who_can_reply_post
postiz posts:create \
  -c "Post copy" \
  -s "2026-06-16T16:00:00Z" \
  -i "cmq55s5iy0001qttunmxabaf5" \
  --type draft \
  --settings '{"who_can_reply_post":"everyone"}'

# Facebook — no extra settings required
postiz posts:create \
  -c "Longer Facebook copy" \
  -s "2026-06-16T16:00:00Z" \
  -i "cmq4clbth0001qkqsznluxtud" \
  --type draft
```

### 4. Log in Twenty CRM

After scheduling, QG_MARKETING adds a Note (via Twenty MCP) with:

- Campaign ID and name
- Postiz post IDs
- Platforms (X, Facebook)
- Scheduled times
- Link to Postiz calendar: https://smm.quantgist.com/launches

Full CRM patterns: `~/.openclaw/workspace/workspace_QuantGist/ops/TWENTY_CRM.md`

## Biweekly Postiz review (human)

**Cadence:** Every other Monday (adjust in `campaign.json`).

**User steps:**

1. Open the campaign week on the calendar (default view is **this ISO week only** — future posts are hidden until you navigate forward):
   - Example campaign (Jun 16–20): https://smm.quantgist.com/launches?startDate=2026-06-15&endDate=2026-06-21&display=week
   - Or June month view: https://smm.quantgist.com/launches?startDate=2026-06-01&endDate=2026-06-30&display=month
   - Or list view → **Draft** tab (shows all upcoming drafts regardless of week): https://smm.quantgist.com/launches?display=list
2. Review all **draft** and **scheduled** posts for the next two weeks.
3. Edit copy, reschedule, or delete posts in the UI.
4. Approve posts ready to go live (change draft → scheduled, or confirm schedule time).
5. Post feedback in **Telegram topic 5** (G_marketing) or **Discord #qg_marketing** (`1496546435309506662`).

**What agents should schedule as draft first:** New campaigns, controversial topics, or any post touching market commentary. Routine recurring posts may be `--publish` after the first review cycle.

## Feedback loop (Slack / Telegram)

| Channel | Route | Agent |
|---------|-------|-------|
| Telegram group `-1003934105316`, topic **5** | `agentId: QG_MARKETING` | Strategy, approvals, campaign changes |
| Discord `1496546435309506662` | QG_SOCIAL_MEDIA_MANAGER sub-channel | Scheduling errors, publish confirmations |
| Discord `1496554648885006506` | P0 alerts | Failed posts, API outages |

**When user sends feedback** (e.g. "tone down post 2", "move Wednesday post to Thursday"):

1. QG_MARKETING acknowledges in the same channel.
2. QG_SOCIAL_MEDIA_MANAGER updates Postiz (`postiz posts:delete` + recreate, or edit in UI).
3. QG_ENGAGEMENT_ANALYST notes what to improve next cycle.
4. Agent logs task via `log_qg_agent_activity.sh` before closing.

Example Telegram prompt:

> @QG_MARKETING Review complete. Post 2 approved. Post 3 — shorten X version to under 200 chars. Move post 1 to Tuesday 10am ET.

## LinkedIn blocker (do not use until resolved)

LinkedIn **company page** posting requires:

1. Verify company on app `252090026` at [LinkedIn Developers](https://www.linkedin.com/developers/apps/252090026/settings)
2. Request **Community Management API** on that app
3. Postiz UI → Add Channel → LinkedIn Page → OAuth

Until `linkedin-page` appears in `postiz integrations:list`, agents must **not** include LinkedIn in campaign schedules. Personal LinkedIn (`cmq3r9kon0001pjbed2gzl2v5`) is Ernest's profile — not for QuantGist brand campaigns.

Details: `~/.openclaw/workspace/workspace_QuantGist/ops/POSTIZ.md`

## Failure handling

| Symptom | Action |
|---------|--------|
| Calendar empty but `postiz posts:list` shows posts | Navigate to the post week (→) or month view; default week view only shows current ISO week. List view → **Draft** for all drafts. |
| Postiz API 502 | Wait 5–7 min; see `ops/POSTIZ.md` backend recovery |
| `integrations:list` empty | Reconnect X/Facebook in Postiz UI |
| Twenty MCP 401 | Regenerate API key, restart OpenClaw gateway |
| Publish failure | Retry once; escalate to QG_MARKETING; post to Discord P0 channel |
| Postiz Agents chat silent | Run `bootstrap-postiz-agent-chat.sh --apply --live-patch` — see § Postiz agent chat |
| Want QG_MARKETING in Postiz UI | OpenClaw bridge — dropdown after image rebuild, or `POSTIZ_OPENCLAW_AGENT` env |
| Canva autofill 401 | Re-run `canva-oauth-bootstrap.sh`; refresh token |

## Weekly operating system

| Day | Focus | Lead |
|-----|-------|------|
| Mon | Plan — type, audience, matrix rows | QG_MARKETING |
| Tue | Copy + Canva graphics | QG_CONTENT_CREATOR |
| Wed | Video (if needed) | QG_CONTENT_CREATOR |
| Thu | Schedule Postiz drafts | QG_SOCIAL_MEDIA_MANAGER |
| Fri | KPI snapshot | QG_ENGAGEMENT_ANALYST |
| Weekend | Community (Discord/Telegram) | QG_HR |

## Canva multimedia (optional)

```bash
bash packages/twenty-docker/quantgist/bootstrap-canva-env.sh
bash packages/twenty-docker/quantgist/canva-oauth-bootstrap.sh   # browser OAuth
bash packages/twenty-docker/quantgist/smoke-canva.sh
```

Credentials: `~/.openclaw/credentials/canva-quantgist.env` (chmod 600, never commit).

Schedule with Canva exports when `media.exportUrl` is set or templates are registered:

```bash
bash campaigns/example-jun-2026-signals-launch/schedule-campaign.sh --with-canva
```

Template IDs: `integrations.json` → `canva.templates`. See `CANVA_MULTIMEDIA_WORKFLOW.md`.

## Postiz agent chat (OpenClaw bridge)

| Path | What you get |
|------|----------------|
| **Postiz UI → Agents** | `QG_MARKETING` or `QG_SOCIAL_MEDIA_MANAGER` via OpenClaw Gateway (Codex OAuth — **no** `OPENAI_API_KEY`) |
| **Telegram topic 5** | `QG_MARKETING` (strategy, campaigns, approvals) |
| **Discord #qg_marketing** | `QG_SOCIAL_MEDIA_MANAGER` + `QG_MARKETING` |
| **OpenClaw CLI** | Any `QG_*` agent with Postiz CLI skill |

Full bridge docs: `POSTIZ_OPENCLAW_BRIDGE.md`

### Enable / fix Postiz Agents chat

```bash
# OAuth LLM via OpenClaw — no raw OpenAI key
bash packages/twenty-docker/quantgist/bootstrap-postiz-agent-chat.sh --apply --live-patch

# Optional: default SMM instead of marketing
bash packages/twenty-docker/quantgist/bootstrap-postiz-agent-chat.sh --apply --agent QG_SOCIAL_MEDIA_MANAGER

# Rebuild Postiz image for UI agent dropdown (SM-postiz-app patches)
cd /Volumes/ExtHDD/github/QG-ecosystem/SM-postiz-app && docker compose build postiz

# Test: https://smm.quantgist.com/agents → New chat → "What channels are connected?"
```

**LLM fallback (OpenClaw, not Postiz):** `openai-codex` OAuth gpt-5.5 → gpt-5.3-codex → `xai` grok-4.3 (SMM agent).

### Postiz MCP (OpenClaw → Postiz, reverse direction)

OpenClaw agents can call Postiz as MCP (`/mcp` on smm.quantgist.com) using the org API key. `startMcp` may be disabled on QuantGist instance for boot stability — see `ops/POSTIZ.md`. CLI remains primary for scheduling.

## Related docs (OpenClaw host)

| Doc | Path |
|-----|------|
| Campaign strategy | `packages/twenty-docker/quantgist/CAMPAIGN_STRATEGY.md` |
| Content matrix | `packages/twenty-docker/quantgist/CONTENT_MATRIX.md` |
| Postiz ops | `~/.openclaw/workspace/workspace_QuantGist/ops/POSTIZ.md` |
| Twenty CRM MCP | `~/.openclaw/workspace/workspace_QuantGist/ops/TWENTY_CRM.md` |
| SMM workspace | `~/.openclaw/workspace/workspace_QuantGist/agents/workspaces/QG_SOCIAL_MEDIA_MANAGER/README.md` |
| Postiz setup | `/Volumes/ExtHDD/github/QG-ecosystem/SM-postiz-app/QUANTGIST_SETUP.md` |

## Smoke test results log

Run and record after infrastructure changes:

```bash
bash packages/twenty-docker/quantgist/smoke-campaign-workflow.sh
```

**2026-06-12:** Campaign validated; 6 Postiz drafts recreated (3 X + 3 Facebook). Canva client credentials set; OAuth pending. Postiz Agents chat blocked on missing OPENAI_API_KEY. Review: https://smm.quantgist.com/launches?startDate=2026-06-15&endDate=2026-06-21&display=week
