/**
 * Cloudflare Worker: Postiz publish webhook → QuantGist CRM
 *
 * Deploy to Cloudflare Workers and register URL in Postiz UI:
 *   https://<worker>.workers.dev/webhooks/postiz-published
 *
 * Secrets (wrangler secret put):
 *   CRM_LEAD_INGEST_SECRET
 *
 * Vars:
 *   QUANTGIST_API_URL = https://api.quantgist.com/v1
 */

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (request.method !== 'POST') {
      return new Response('Method not allowed', { status: 405 });
    }

    if (url.pathname !== '/webhooks/postiz-published') {
      return new Response('Not found', { status: 404 });
    }

    const ingestKey = request.headers.get('X-Crm-Ingest-Key');
    if (ingestKey && ingestKey !== env.CRM_LEAD_INGEST_SECRET) {
      return new Response('Unauthorized', { status: 401 });
    }

    let body;
    try {
      body = await request.json();
    } catch {
      return new Response('Invalid JSON', { status: 400 });
    }

    const apiUrl = env.QUANTGIST_API_URL || 'https://api.quantgist.com/v1';

    const crmResponse = await fetch(`${apiUrl}/crm/webhooks/postiz-published`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Crm-Ingest-Key': env.CRM_LEAD_INGEST_SECRET,
      },
      body: JSON.stringify(body),
    });

    const text = await crmResponse.text();
    return new Response(text, {
      status: crmResponse.status,
      headers: { 'Content-Type': 'application/json' },
    });
  },
};
