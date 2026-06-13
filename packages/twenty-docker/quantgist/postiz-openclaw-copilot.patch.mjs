#!/usr/bin/env node
import fs from 'fs';

const path = process.argv[2];
if (!path) {
  console.error('Usage: node postiz-openclaw-copilot.patch.mjs <copilot.controller.js>');
  process.exit(1);
}

let source = fs.readFileSync(path, 'utf8');

if (source.includes('openclaw/')) {
  console.log('Already patched');
  process.exit(0);
}

const patchedAgent = `async agent(req, res, organization) {
        const bridgeEnabled = process.env.POSTIZ_OPENCLAW_BRIDGE === 'enabled';
        const gatewayToken = (process.env.OPENCLAW_GATEWAY_TOKEN || '').trim();
        if (bridgeEnabled) {
            if (!gatewayToken) {
                common_1.Logger.warn('OpenClaw bridge enabled but OPENCLAW_GATEWAY_TOKEN is missing');
                return;
            }
            const agentHeader = req.headers['x-postiz-openclaw-agent'];
            const propertyAgent = req?.body?.variables?.properties?.openclawAgent;
            const envAgent = (process.env.POSTIZ_OPENCLAW_AGENT || 'QG_MARKETING').trim();
            const allowed = new Set(['QG_MARKETING', 'QG_SOCIAL_MEDIA_MANAGER']);
            const agentId = (typeof agentHeader === 'string' && allowed.has(agentHeader))
                ? agentHeader
                : (typeof propertyAgent === 'string' && allowed.has(propertyAgent))
                    ? propertyAgent
                    : (allowed.has(envAgent) ? envAgent : 'QG_MARKETING');
            const threadId = req?.body?.threadId || req?.body?.variables?.threadId || 'main';
            const sessionKey = 'agent:' + agentId.toLowerCase() + ':postiz-' + organization.id + '-' + threadId;
            const gatewayUrl = (process.env.OPENCLAW_GATEWAY_URL || 'http://host.docker.internal:18789/v1').trim();
            const OpenAI = require('openai').default;
            const openai = new OpenAI({
                apiKey: gatewayToken,
                baseURL: gatewayUrl,
                defaultHeaders: {
                    'x-openclaw-session-key': sessionKey,
                    'x-openclaw-message-channel': 'postiz',
                },
            });
            const runtime = new runtime_1.CopilotRuntime();
            const copilotRuntimeHandler = (0, runtime_1.copilotRuntimeNextJSAppRouterEndpoint)({
                endpoint: '/copilot/agent',
                runtime,
                serviceAdapter: new runtime_1.OpenAIAdapter({
                    openai,
                    model: 'openclaw/' + agentId,
                }),
            });
            return copilotRuntimeHandler.handleRequest(req, res);
        }
        if (process.env.OPENAI_API_KEY === undefined ||
            process.env.OPENAI_API_KEY === '') {
            common_1.Logger.warn('OpenAI API key not set, chat functionality will not work');
            return;
        }
        const mastra = await this._mastraService.mastra();
        const requestContext = new di_1.RequestContext();
        requestContext.set('integrations', req?.body?.variables?.properties?.integrations || []);
        requestContext.set('organization', JSON.stringify(organization));
        requestContext.set('ui', 'true');
        const agents = mastra_1.MastraAgent.getLocalAgents({
            resourceId: organization.id,
            mastra,
            requestContext: requestContext,
        });
        const runtime = new runtime_1.CopilotRuntime({
            agents,
        });
        const copilotRuntimeHandler = (0, runtime_1.copilotRuntimeNextJSAppRouterEndpoint)({
            endpoint: '/copilot/agent',
            runtime,
            serviceAdapter: new runtime_1.OpenAIAdapter({
                model: 'gpt-4.1',
            }),
        });
        return copilotRuntimeHandler.handleRequest(req, res);
    }`;

const pattern =
  /async agent\(req, res, organization\) \{[\s\S]*?return copilotRuntimeHandler\.handleRequest\(req, res\);\s*\}/;

if (!pattern.test(source)) {
  console.error('Patch target not found');
  process.exit(1);
}

source = source.replace(pattern, patchedAgent);
fs.writeFileSync(path, source);
console.log('Patched', path);
