#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
QUANTGIST_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
POSTS_FILE="${SCRIPT_DIR}/posts-schedule.json"
CAMPAIGN_FILE="${SCRIPT_DIR}/campaign.json"
DRY_RUN=0
POST_TYPE="draft"
WITH_CANVA=0

usage() {
  cat <<'EOF'
Schedule example campaign posts to Postiz (X + Facebook).

Usage:
  bash schedule-campaign.sh [--dry-run] [--publish] [--with-canva]

Options:
  --dry-run     Print postiz commands without executing
  --publish     Schedule for publish (default: draft for biweekly review)
  --with-canva  Attach media from posts-schedule.json media.exportUrl (or generate via Canva when configured)

Requires: postiz CLI, bootstrap-postiz-env.sh credentials
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --publish) POST_TYPE="schedule"; shift ;;
    --with-canva) WITH_CANVA=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

# shellcheck disable=SC1090
source "${QUANTGIST_DIR}/bootstrap-postiz-env.sh" >/dev/null

X_ID="$(jq -r '.integrationIds.x' "${CAMPAIGN_FILE}")"
FB_ID="$(jq -r '.integrationIds.facebook' "${CAMPAIGN_FILE}")"
POST_COUNT="$(jq '.posts | length' "${POSTS_FILE}")"
FIRST_DATE="$(jq -r '[.posts[].scheduledAt] | map(split("T")[0]) | min' "${POSTS_FILE}")"
LAST_DATE="$(jq -r '[.posts[].scheduledAt] | map(split("T")[0]) | max' "${POSTS_FILE}")"
CALENDAR_LINKS="$(python3 - "${FIRST_DATE}" "${LAST_DATE}" <<'PY'
import calendar
import datetime
import sys

first_date = datetime.date.fromisoformat(sys.argv[1])
last_date = datetime.date.fromisoformat(sys.argv[2])
week_start = first_date - datetime.timedelta(days=first_date.weekday())
week_end = week_start + datetime.timedelta(days=6)
month_start = first_date.replace(day=1)
month_last = calendar.monthrange(first_date.year, first_date.month)[1]
month_end = first_date.replace(day=month_last)
base = "https://smm.quantgist.com/launches"
print(
    f"{base}?startDate={week_start}&endDate={week_end}&display=week",
    f"{base}?startDate={month_start}&endDate={month_end}&display=month",
    f"{base}?display=list",
    sep="\n",
)
PY
)"

echo "Campaign: $(jq -r '.name' "${CAMPAIGN_FILE}")"
echo "Type: ${POST_TYPE} | Posts: ${POST_COUNT} | Platforms: X + Facebook"
echo "Schedule range: ${FIRST_DATE} → ${LAST_DATE} (UTC dates)"
echo ""

for INDEX in $(seq 0 $((POST_COUNT - 1))); do
  POST_ID="$(jq -r ".posts[${INDEX}].id" "${POSTS_FILE}")"
  SCHEDULED_AT="$(jq -r ".posts[${INDEX}].scheduledAt" "${POSTS_FILE}")"
  X_CONTENT="$(jq -r ".posts[${INDEX}].x.content" "${POSTS_FILE}")"
  FB_CONTENT="$(jq -r ".posts[${INDEX}].facebook.content" "${POSTS_FILE}")"
  MEDIA_URL="$(jq -r '.posts['"${INDEX}"'].media.exportUrl // empty' "${POSTS_FILE}")"

  if [[ "${WITH_CANVA}" -eq 1 && -z "${MEDIA_URL}" ]]; then
    CANVA_TEMPLATE="$(jq -r '.posts['"${INDEX}"'].media.canvaTemplate // empty' "${POSTS_FILE}")"
    if [[ -n "${CANVA_TEMPLATE}" && -f "${QUANTGIST_DIR}/canva-export-from-template.sh" ]]; then
      MEDIA_URL="$(bash "${QUANTGIST_DIR}/canva-export-from-template.sh" \
        --template "${CANVA_TEMPLATE}" \
        --post-id "${POST_ID}" 2>/dev/null || true)"
    fi
  fi

  echo "── ${POST_ID} @ ${SCHEDULED_AT} ──"
  if [[ -n "${MEDIA_URL}" ]]; then
    echo "  media: ${MEDIA_URL}"
  fi

  X_CMD=(
    postiz posts:create
    -c "${X_CONTENT}"
    -s "${SCHEDULED_AT}"
    -i "${X_ID}"
    --type "${POST_TYPE}"
    --settings '{"who_can_reply_post":"everyone"}'
  )
  FB_CMD=(
    postiz posts:create
    -c "${FB_CONTENT}"
    -s "${SCHEDULED_AT}"
    -i "${FB_ID}"
    --type "${POST_TYPE}"
  )
  if [[ -n "${MEDIA_URL}" ]]; then
    X_CMD+=(-m "${MEDIA_URL}")
    FB_CMD+=(-m "${MEDIA_URL}")
  fi

  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "  [dry-run] ${X_CMD[*]}"
    echo "  [dry-run] ${FB_CMD[*]}"
  else
    echo "  → X"
    "${X_CMD[@]}"
    echo "  → Facebook"
    "${FB_CMD[@]}"
  fi
  echo ""
done

echo "Done."
echo ""

if [[ "${DRY_RUN}" -eq 0 ]]; then
  SYNC_SCRIPT="${QUANTGIST_DIR}/sync-campaign-to-twenty.sh"
  if [[ -x "${SYNC_SCRIPT}" || -f "${SYNC_SCRIPT}" ]]; then
    echo "Syncing campaign to Twenty CRM..."
    bash "${SYNC_SCRIPT}" "${SCRIPT_DIR}" || echo "WARN: Twenty CRM sync failed (non-fatal)" >&2
  fi
fi

echo ""
echo "Posts are on the calendar for ${FIRST_DATE}–${LAST_DATE}."
echo "Default week view shows TODAY's ISO week only — click → or use a link below:"
while IFS= read -r link; do
  echo "  ${link}"
done <<< "${CALENDAR_LINKS}"
echo ""
echo "List view → Draft tab shows all upcoming drafts (any date)."
if [[ "${POST_TYPE}" == "draft" ]]; then
  echo "Draft posts appear on the calendar grid; use --publish after biweekly review."
fi
