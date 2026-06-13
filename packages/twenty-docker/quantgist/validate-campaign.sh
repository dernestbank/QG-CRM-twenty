#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INTEGRATIONS_FILE="${SCRIPT_DIR}/integrations.json"

usage() {
  cat <<'EOF'
Validate campaign.json and posts-schedule.json against QuantGist schema.

Usage:
  bash validate-campaign.sh <campaign-directory>

Exit codes:
  0 — valid
  1 — validation errors
EOF
}

if [[ $# -lt 1 ]]; then
  usage >&2
  exit 1
fi

CAMPAIGN_DIR="$(cd "$1" && pwd)"
CAMPAIGN_FILE="${CAMPAIGN_DIR}/campaign.json"
POSTS_FILE="${CAMPAIGN_DIR}/posts-schedule.json"

ERRORS=0

error() {
  echo "ERROR: $*" >&2
  ERRORS=$((ERRORS + 1))
}

warn() {
  echo "WARN: $*" >&2
}

require_jq_field() {
  local file="$1"
  local jq_expr="$2"
  local label="$3"
  local value
  value="$(jq -r "${jq_expr}" "${file}")"
  if [[ "${value}" == "null" || -z "${value}" ]]; then
    error "${label} missing in $(basename "${file}")"
  fi
}

if [[ ! -f "${CAMPAIGN_FILE}" ]]; then
  error "campaign.json not found in ${CAMPAIGN_DIR}"
  echo "Validation failed with ${ERRORS} error(s)."
  exit 1
fi

if ! jq empty "${CAMPAIGN_FILE}" 2>/dev/null; then
  error "campaign.json is not valid JSON"
  echo "Validation failed with ${ERRORS} error(s)."
  exit 1
fi

VALID_TYPES="product-launch brand-awareness lead-generation event-promotion"
VALID_AUDIENCES="retail-traders algo-quants prop-firm-traders fintech-builders investors-partners"
VALID_GOALS="brand-awareness lead-generation product-launch education community event-promotion"
VALID_PILLARS="market-intelligence trading-education product-education case-studies founder-building-in-public community-content"
VALID_FUNNEL="awareness education proof conversion retention"

# Required top-level fields
for field in id name campaignType status owner; do
  require_jq_field "${CAMPAIGN_FILE}" ".${field}" "${field}"
done

CAMPAIGN_TYPE="$(jq -r '.campaignType // empty' "${CAMPAIGN_FILE}")"
if [[ -n "${CAMPAIGN_TYPE}" && ! " ${VALID_TYPES} " =~ " ${CAMPAIGN_TYPE} " ]]; then
  error "campaignType '${CAMPAIGN_TYPE}' not in: ${VALID_TYPES}"
fi

# Strategy block
require_jq_field "${CAMPAIGN_FILE}" '.strategy.audience.primary' 'strategy.audience.primary'
require_jq_field "${CAMPAIGN_FILE}" '.strategy.goal' 'strategy.goal'
require_jq_field "${CAMPAIGN_FILE}" '.strategy.positioning' 'strategy.positioning'
require_jq_field "${CAMPAIGN_FILE}" '.strategy.message' 'strategy.message'

PRIMARY_AUDIENCE="$(jq -r '.strategy.audience.primary // empty' "${CAMPAIGN_FILE}")"
if [[ -n "${PRIMARY_AUDIENCE}" && ! " ${VALID_AUDIENCES} " =~ " ${PRIMARY_AUDIENCE} " ]]; then
  error "strategy.audience.primary '${PRIMARY_AUDIENCE}' invalid"
fi

STRATEGY_GOAL="$(jq -r '.strategy.goal // empty' "${CAMPAIGN_FILE}")"
if [[ -n "${STRATEGY_GOAL}" && ! " ${VALID_GOALS} " =~ " ${STRATEGY_GOAL} " ]]; then
  error "strategy.goal '${STRATEGY_GOAL}' invalid"
fi

PILLAR_COUNT="$(jq '.strategy.contentPillars // [] | length' "${CAMPAIGN_FILE}")"
if [[ "${PILLAR_COUNT}" -lt 1 ]]; then
  error "strategy.contentPillars must have at least one pillar"
fi

# KPIs
require_jq_field "${CAMPAIGN_FILE}" '.kpis.primary' 'kpis.primary'
require_jq_field "${CAMPAIGN_FILE}" '.kpis.targets' 'kpis.targets'

# Content matrix
MATRIX_COUNT="$(jq '.contentMatrix // [] | length' "${CAMPAIGN_FILE}")"
if [[ "${MATRIX_COUNT}" -lt 1 ]]; then
  error "contentMatrix must have at least one row"
fi

# Roles
for role in strategist contentWriter smm campaignOperator analyst; do
  require_jq_field "${CAMPAIGN_FILE}" ".roles.${role}" "roles.${role}"
done

# Weekly plan
for day in monday tuesday wednesday thursday friday; do
  require_jq_field "${CAMPAIGN_FILE}" ".weeklyPlan.${day}" "weeklyPlan.${day}"
done

# Platforms and integration IDs
PLATFORM_COUNT="$(jq '.platforms // [] | length' "${CAMPAIGN_FILE}")"
if [[ "${PLATFORM_COUNT}" -lt 1 ]]; then
  error "platforms must list at least one active platform"
fi

while IFS= read -r platform; do
  [[ -z "${platform}" ]] && continue
  integration_id="$(jq -r ".integrationIds.${platform} // empty" "${CAMPAIGN_FILE}")"
  if [[ -z "${integration_id}" ]]; then
    error "integrationIds.${platform} missing"
  elif [[ -f "${INTEGRATIONS_FILE}" ]]; then
    expected="$(jq -r ".platforms.${platform}.integrationId // empty" "${INTEGRATIONS_FILE}")"
    if [[ -n "${expected}" && "${integration_id}" != "${expected}" ]]; then
      warn "integrationIds.${platform} (${integration_id}) differs from integrations.json (${expected})"
    fi
  fi
done < <(jq -r '.platforms[]?' "${CAMPAIGN_FILE}")

# Validate contentMatrix rows
while IFS= read -r row; do
  row_id="$(echo "${row}" | jq -r '.rowId // empty')"
  for key in audience goal pillar format funnelStage cta; do
    val="$(echo "${row}" | jq -r ".${key} // empty")"
    if [[ -z "${val}" ]]; then
      error "contentMatrix row '${row_id}' missing ${key}"
    fi
  done
  audience="$(echo "${row}" | jq -r '.audience')"
  if [[ ! " ${VALID_AUDIENCES} all " =~ " ${audience} " ]]; then
    error "contentMatrix row '${row_id}' audience '${audience}' invalid"
  fi
  pillar="$(echo "${row}" | jq -r '.pillar')"
  if [[ ! " ${VALID_PILLARS} " =~ " ${pillar} " ]]; then
    error "contentMatrix row '${row_id}' pillar '${pillar}' invalid"
  fi
  funnel="$(echo "${row}" | jq -r '.funnelStage')"
  if [[ ! " ${VALID_FUNNEL} " =~ " ${funnel} " ]]; then
    error "contentMatrix row '${row_id}' funnelStage '${funnel}' invalid"
  fi
done < <(jq -c '.contentMatrix[]?' "${CAMPAIGN_FILE}")

# Duplicate rowIds
DUPE_ROWS="$(jq -r '[.contentMatrix[].rowId] | group_by(.) | map(select(length > 1)) | flatten | unique | .[]' "${CAMPAIGN_FILE}")"
if [[ -n "${DUPE_ROWS}" ]]; then
  while IFS= read -r dupe; do
    [[ -z "${dupe}" ]] && continue
    error "duplicate contentMatrix rowId: ${dupe}"
  done <<< "${DUPE_ROWS}"
fi

# posts-schedule.json
if [[ ! -f "${POSTS_FILE}" ]]; then
  error "posts-schedule.json not found"
else
  if ! jq empty "${POSTS_FILE}" 2>/dev/null; then
    error "posts-schedule.json is not valid JSON"
  else
    POST_COUNT="$(jq '.posts // [] | length' "${POSTS_FILE}")"
    if [[ "${POST_COUNT}" -lt 1 ]]; then
      error "posts-schedule.json must have at least one post"
    fi

    while IFS= read -r post; do
      post_id="$(echo "${post}" | jq -r '.id // empty')"
      require_jq_field <(echo "${post}") '.scheduledAt' "post ${post_id} scheduledAt"
      matrix_row="$(echo "${post}" | jq -r '.matrix.rowId // empty')"
      if [[ -z "${matrix_row}" ]]; then
        error "post '${post_id}' missing matrix.rowId"
      else
        exists="$(jq --arg rid "${matrix_row}" '[.contentMatrix[].rowId] | index($rid) != null' "${CAMPAIGN_FILE}")"
        if [[ "${exists}" != "true" ]]; then
          error "post '${post_id}' matrix.rowId '${matrix_row}' not in contentMatrix"
        fi
      fi
      for key in audience goal pillar format funnelStage cta; do
        val="$(echo "${post}" | jq -r ".matrix.${key} // empty")"
        if [[ -z "${val}" ]]; then
          error "post '${post_id}' missing matrix.${key}"
        fi
      done
      while IFS= read -r platform; do
        [[ -z "${platform}" ]] && continue
        content="$(echo "${post}" | jq -r ".${platform}.content // empty")"
        if [[ -z "${content}" ]]; then
          error "post '${post_id}' missing ${platform}.content (required by campaign platforms)"
        fi
      done < <(jq -r '.platforms[]?' "${CAMPAIGN_FILE}")
    done < <(jq -c '.posts[]?' "${POSTS_FILE}")
  fi
fi

# UTM campaign id should appear in post content URLs
CAMPAIGN_ID="$(jq -r '.id' "${CAMPAIGN_FILE}")"
if [[ -f "${POSTS_FILE}" && "${POST_COUNT:-0}" -gt 0 ]]; then
  while IFS= read -r post; do
    post_id="$(echo "${post}" | jq -r '.id // empty')"
    combined="$(echo "${post}" | jq -r '[.x.content, .facebook.content] | join(" ")')"
    if [[ -n "${combined}" && "${combined}" != *"utm_campaign=${CAMPAIGN_ID}"* ]]; then
      warn "post '${post_id}' missing utm_campaign=${CAMPAIGN_ID} in content URLs"
    fi
  done < <(jq -c '.posts[]?' "${POSTS_FILE}")
fi

if [[ "${ERRORS}" -gt 0 ]]; then
  echo ""
  echo "Validation failed with ${ERRORS} error(s)."
  exit 1
fi

echo "OK: $(jq -r '.name' "${CAMPAIGN_FILE}") (${CAMPAIGN_TYPE})"
echo "  Matrix rows: ${MATRIX_COUNT} | Posts: ${POST_COUNT:-0}"
exit 0
