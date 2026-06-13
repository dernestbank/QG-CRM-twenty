#!/usr/bin/env python3
"""Bootstrap QuantGist Person marketing fields + Campaign object via Twenty REST metadata API."""

from __future__ import annotations

import json
import os
import sys
import uuid
from typing import Any

import httpx

TWENTY_URL = os.environ.get("TWENTY_API_URL", "https://crm.quantgist.com").rstrip("/")
API_KEY = os.environ.get("TWENTY_API_KEY", "")

PERSON_OBJECT_ID = "2e54934f-90fa-4b8a-9db7-4382cbca43df"


def option(label: str, value: str, position: int, color: str = "blue") -> dict[str, Any]:
    return {
        "id": str(uuid.uuid4()),
        "label": label,
        "value": value,
        "position": position,
        "color": color,
    }


PERSON_FIELDS: list[dict[str, Any]] = [
    {
        "name": "leadSource",
        "label": "Lead Source",
        "type": "SELECT",
        "icon": "IconTarget",
        "options": [
            option("LinkedIn", "LINKEDIN", 0, "blue"),
            option("X", "X", 1, "gray"),
            option("YouTube", "YOUTUBE", 2, "red"),
            option("Website", "WEBSITE", 3, "green"),
            option("Webinar", "WEBINAR", 4, "purple"),
            option("Referral", "REFERRAL", 5, "yellow"),
            option("Discord", "DISCORD", 6, "turquoise"),
        ],
    },
    {
        "name": "audienceSegment",
        "label": "Audience Segment",
        "type": "SELECT",
        "icon": "IconUsers",
        "options": [
            option("Retail Trader", "RETAIL_TRADER", 0),
            option("Algo Trader", "ALGO_TRADER", 1),
            option("Prop Trader", "PROP_TRADER", 2),
            option("Developer", "DEVELOPER", 3),
            option("Investor", "INVESTOR", 4),
            option("Partner", "PARTNER", 5),
        ],
    },
    {
        "name": "productInterest",
        "label": "Product Interest",
        "type": "MULTI_SELECT",
        "icon": "IconListCheck",
        "options": [
            option("Macro News API", "MACRO_NEWS_API", 0),
            option("Economic Calendar", "ECONOMIC_CALENDAR", 1),
            option("NQ Dataset", "NQ_DATASET", 2),
            option("Trading Indicators", "TRADING_INDICATORS", 3),
            option("Backtesting Tool", "BACKTESTING_TOOL", 4),
        ],
    },
    {
        "name": "funnelStage",
        "label": "Funnel Stage",
        "type": "SELECT",
        "icon": "IconFilter",
        "options": [
            option("New", "NEW", 0),
            option("Warm", "WARM", 1),
            option("Hot", "HOT", 2),
            option("Trial", "TRIAL", 3),
            option("Customer", "CUSTOMER", 4),
            option("Inactive", "INACTIVE", 5),
        ],
    },
    {"name": "utmSource", "label": "UTM Source", "type": "TEXT", "icon": "IconLink"},
    {"name": "utmCampaign", "label": "UTM Campaign", "type": "TEXT", "icon": "IconLink"},
    {"name": "nextAction", "label": "Next Action", "type": "TEXT", "icon": "IconChecklist"},
    {"name": "activatedAt", "label": "Activated At", "type": "DATE_TIME", "icon": "IconBolt"},
    {"name": "lastApiCallAt", "label": "Last API Call At", "type": "DATE_TIME", "icon": "IconClock"},
]

CAMPAIGN_FIELDS: list[dict[str, Any]] = [
    {"name": "name", "label": "Name", "type": "TEXT", "icon": "IconTypography"},
    {
        "name": "campaignType",
        "label": "Campaign Type",
        "type": "SELECT",
        "icon": "IconTag",
        "options": [
            option("Product Launch", "PRODUCT_LAUNCH", 0),
            option("Brand Awareness", "BRAND_AWARENESS", 1),
            option("Lead Generation", "LEAD_GENERATION", 2),
            option("Event Promotion", "EVENT_PROMOTION", 3),
        ],
    },
    {"name": "goal", "label": "Goal", "type": "TEXT", "icon": "IconTarget"},
    {
        "name": "status",
        "label": "Status",
        "type": "SELECT",
        "icon": "IconStatusChange",
        "options": [
            option("Planning", "PLANNING", 0),
            option("Active", "ACTIVE", 1),
            option("Paused", "PAUSED", 2),
            option("Completed", "COMPLETED", 3),
        ],
    },
    {"name": "startDate", "label": "Start Date", "type": "DATE", "icon": "IconCalendar"},
    {"name": "endDate", "label": "End Date", "type": "DATE", "icon": "IconCalendar"},
    {
        "name": "primaryAudience",
        "label": "Primary Audience",
        "type": "SELECT",
        "icon": "IconUsers",
        "options": PERSON_FIELDS[1]["options"],
    },
    {"name": "utmCampaign", "label": "UTM Campaign", "type": "TEXT", "icon": "IconLink"},
    {"name": "postizCampaignId", "label": "Postiz Campaign ID", "type": "TEXT", "icon": "IconHash"},
    {"name": "platforms", "label": "Platforms", "type": "TEXT", "icon": "IconShare"},
    {"name": "canvaDesignId", "label": "Canva Design ID", "type": "TEXT", "icon": "IconPhoto"},
]


def auth_headers(api_key: str) -> dict[str, str]:
    return {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }


def get_existing_field_names(
    client: httpx.Client, object_id: str, api_key: str,
) -> set[str]:
    response = client.get(
        f"{TWENTY_URL}/rest/metadata/objects",
        headers=auth_headers(api_key),
        timeout=120.0,
    )
    response.raise_for_status()
    objects = response.json().get("data", [])
    for obj in objects:
        if obj["id"] == object_id:
            return {field["name"] for field in obj.get("fields", [])}
    return set()


def create_field(
    client: httpx.Client, object_id: str, spec: dict[str, Any], api_key: str,
) -> None:
    payload: dict[str, Any] = {
        "name": spec["name"],
        "label": spec["label"],
        "type": spec["type"],
        "objectMetadataId": object_id,
        "icon": spec.get("icon", "IconTypography"),
        "isNullable": True,
    }
    if "options" in spec:
        payload["options"] = spec["options"]
    response = client.post(
        f"{TWENTY_URL}/rest/metadata/fields",
        headers=auth_headers(api_key),
        json=payload,
        timeout=120.0,
    )
    if response.status_code >= 400:
        print(f"  ❌ {spec['name']}: {response.status_code} {response.text[:200]}")
    else:
        print(f"  ✅ {spec['name']}")


def ensure_campaign_object(client: httpx.Client, api_key: str) -> str | None:
    response = client.get(
        f"{TWENTY_URL}/rest/metadata/objects",
        headers=auth_headers(api_key),
        timeout=120.0,
    )
    response.raise_for_status()
    for obj in response.json().get("data", []):
        if obj["nameSingular"] == "campaign":
            print(f"Campaign object exists: {obj['id']}")
            return obj["id"]

    print("Creating Campaign custom object...")
    create_response = client.post(
        f"{TWENTY_URL}/rest/metadata/objects",
        headers=auth_headers(api_key),
        json={
            "nameSingular": "campaign",
            "namePlural": "campaigns",
            "labelSingular": "Campaign",
            "labelPlural": "Campaigns",
            "description": "QuantGist marketing campaigns",
            "icon": "IconSpeakerphone",
            "isLabelSyncedWithName": False,
        },
        timeout=120.0,
    )
    if create_response.status_code >= 400:
        print(f"❌ Campaign object: {create_response.status_code} {create_response.text[:300]}")
        return None
    campaign_id = create_response.json().get("id") or create_response.json().get("data", {}).get("id")
    print(f"✅ Campaign object created: {campaign_id}")
    return campaign_id


def main() -> int:
    api_key = API_KEY
    if not api_key:
        key_file = os.path.expanduser("~/.openclaw/credentials/twenty-quantgist-api-key.txt")
        if os.path.isfile(key_file):
            api_key = open(key_file).read().strip()
    if not api_key:
        print("ERROR: set TWENTY_API_KEY")
        return 1

    with httpx.Client() as client:
        existing = get_existing_field_names(client, PERSON_OBJECT_ID, api_key)
        print("=== Person marketing fields ===")
        for spec in PERSON_FIELDS:
            if spec["name"] in existing:
                print(f"  ⏭️  {spec['name']} (exists)")
                continue
            create_field(client, PERSON_OBJECT_ID, spec, api_key)

        campaign_id = ensure_campaign_object(client, api_key)
        if campaign_id:
            campaign_fields = get_existing_field_names(client, campaign_id, api_key)
            print("=== Campaign fields ===")
            for spec in CAMPAIGN_FIELDS:
                if spec["name"] in campaign_fields:
                    print(f"  ⏭️  {spec['name']} (exists)")
                    continue
                create_field(client, campaign_id, spec, api_key)

    print("\nDone. Run: uv run python scripts/backfill_users_to_crm.py --probe")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
