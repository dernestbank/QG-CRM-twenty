# First Live Campaign Runbook

End-to-end: campaign JSON → Postiz drafts → Twenty Campaign → publish → UTM attribution.

## Prerequisites

- [ ] Twenty CRM data model configured (`bash setup-crm-ui-checklist.sh`)
- [ ] `CRM_LEAD_INGEST_SECRET` set in backend Coolify + web env
- [ ] Postiz channels connected (X, Facebook)
- [ ] `postiz integrations:list` returns integrations

## 1. Validate campaign

```bash
cd /Volumes/ExtHDD/github/QG-ecosystem/QG-CRM-twenty
bash packages/twenty-docker/quantgist/validate-campaign.sh \
  packages/twenty-docker/quantgist/campaigns/jun-2026-lead-generation/
```

## 2. Sync to Twenty CRM

```bash
export CRM_LEAD_INGEST_SECRET="<your-secret>"
bash packages/twenty-docker/quantgist/sync-campaign-to-twenty.sh \
  packages/twenty-docker/quantgist/campaigns/jun-2026-lead-generation/
```

Verify Campaign object in https://crm.quantgist.com

## 3. Schedule Postiz drafts

```bash
bash packages/twenty-docker/quantgist/campaigns/jun-2026-lead-generation/schedule-campaign.sh
```

Review in Postiz: https://smm.quantgist.com/launches

## 4. Biweekly human review

Approve copy, graphics, and UTM links in each post. Every CTA must include:

```
https://quantgist.com/waitlist?utm_source={platform}&utm_medium=social&utm_campaign=jun-2026-lead-generation
```

## 5. Publish approved posts

```bash
bash packages/twenty-docker/quantgist/campaigns/jun-2026-lead-generation/schedule-campaign.sh --publish
```

## 6. Register Postiz webhook (optional)

Deploy Cloudflare Worker from `quantgist/workers/` and register in Postiz UI.
Publish events will create Notes on the Campaign record.

## 7. Verify attribution

1. Click a published post CTA (or test UTM link)
2. Submit waitlist form
3. Confirm in Twenty:
   - Person with `leadSource=Website`, UTM fields populated
   - Linked to Campaign `jun-2026-lead-generation`
   - Task: Follow up within 24 hours

## 8. Agent CRM note

QG_MARKETING logs campaign publish summary to Twenty (mandatory per `ops/TWENTY_CRM.md`).
