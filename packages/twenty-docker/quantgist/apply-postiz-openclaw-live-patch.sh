#!/usr/bin/env bash
# Hot-patch running Postiz container CopilotController for OpenClaw bridge (no image rebuild).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONTROLLER_PATH="/app/apps/backend/dist/apps/backend/src/api/routes/copilot.controller.js"
PATCH_FILE="/tmp/postiz-openclaw-copilot.patch.mjs"

if ! docker ps --format '{{.Names}}' | grep -qx postiz; then
  echo "Postiz container not running" >&2
  exit 1
fi

docker cp "${SCRIPT_DIR}/postiz-openclaw-copilot.patch.mjs" "postiz:${PATCH_FILE}"
docker exec postiz cp "${CONTROLLER_PATH}" "${CONTROLLER_PATH}.bak"
docker exec postiz node "${PATCH_FILE}" "${CONTROLLER_PATH}"

# Patch is written to disk; reload backend only if port 3000 is free (avoid EADDRINUSE orphans).
if docker exec postiz pm2 pid backend >/dev/null 2>&1; then
  BACKEND_PID="$(docker exec postiz sh -c "ss -tlnp | grep ':3000' | sed -n 's/.*pid=\\([0-9]*\\).*/\\1/p' | head -1" 2>/dev/null || true)"
  if [[ -n "${BACKEND_PID}" ]]; then
    docker exec postiz sh -c "kill -9 ${BACKEND_PID} 2>/dev/null; sleep 1; pm2 restart backend"
  else
    docker exec postiz pm2 restart backend
  fi
else
  echo "PM2 backend not running yet — patch on disk; docker restart postiz to load"
fi

echo "Patching frontend (remove agent:postiz for OpenClaw bridge)..."
node "${SCRIPT_DIR}/postiz-openclaw-frontend.patch.mjs"

# Avoid `pm2 restart frontend` — it can orphan next-server on :4200 (EADDRINUSE loop).
# Patched chunks are served on next request; recreate container if UI is stale.
echo "Frontend patch applied in-place (no PM2 restart — avoids port 4200 conflict)"

echo "OpenClaw live patch applied (backend + frontend)"
