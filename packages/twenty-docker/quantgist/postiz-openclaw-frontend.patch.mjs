#!/usr/bin/env node
// Hot-patch Postiz frontend build: remove agent:"postiz" for OpenClaw bridge.
import fs from 'fs';
import { execSync } from 'child_process';

const container = 'postiz';
const searchRoot = '/app/apps/frontend/.next';
const AGENT_POSTIZ_PATTERN =
  /agent:"postiz",properties:\{integrations:([a-z])\}/g;
const buildReplacement = (integrationsVar) =>
  `headers:{"x-postiz-openclaw-agent":"QG_MARKETING"},properties:{integrations:${integrationsVar},openclawAgent:"QG_MARKETING"}`;

let files = [];
try {
  const output = execSync(
    `docker exec ${container} find ${searchRoot} -name '*.js' -print`,
    { encoding: 'utf8', maxBuffer: 10 * 1024 * 1024 }
  );
  for (const filePath of output.trim().split('\n').filter(Boolean)) {
    const snippet = execSync(`docker exec ${container} grep -l 'agent:"postiz"' '${filePath}' 2>/dev/null || true`, {
      encoding: 'utf8',
    });
    if (snippet.trim()) {
      files.push(filePath);
    }
  }
} catch {
  console.error('Failed to list patch targets in container');
  process.exit(1);
}

if (files.length === 0) {
  console.log('No agent:"postiz" targets found (already patched?)');
  process.exit(0);
}

let patchedCount = 0;
for (const filePath of files) {
  const localPath = `/tmp/postiz-frontend-patch-${patchedCount}.js`;
  execSync(`docker cp ${container}:${filePath} ${localPath}`);
  let source = fs.readFileSync(localPath, 'utf8');

  if (!AGENT_POSTIZ_PATTERN.test(source)) {
    if (source.includes('x-postiz-openclaw-agent')) {
      console.log('Already patched:', filePath);
      continue;
    }
    console.error('Unexpected content in', filePath);
    process.exit(1);
  }

  AGENT_POSTIZ_PATTERN.lastIndex = 0;
  source = source.replace(AGENT_POSTIZ_PATTERN, (match, integrationsVar) =>
    buildReplacement(integrationsVar)
  );

  fs.writeFileSync(localPath, source);
  execSync(`docker cp ${localPath} ${container}:${filePath}`);
  fs.unlinkSync(localPath);
  patchedCount += 1;
  console.log('Patched', filePath);
}

console.log(`Frontend OpenClaw patch complete (${patchedCount} files)`);
