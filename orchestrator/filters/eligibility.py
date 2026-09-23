"""Eligibility filters for discovered resources."""

from __future__ import annotations

from typing import Any, Dict, List


def apply_host_filters(hosts: List[Dict[str, Any]], filters: Dict[str, Any]) -> List[Dict[str, Any]]:
    """Filter normalized host dicts (post-discovery)."""
    out = []
    for h in hosts:
        if filters.get("environment") and h.get("environment") not in (
            filters["environment"],
            "",
        ):
            # allow empty env on host if filter set — prefer match
            if h.get("environment") and h.get("environment") != filters["environment"]:
                continue
        if filters.get("customer_id") and h.get("customer") not in (
            filters["customer_id"],
            "",
        ):
            if h.get("customer") and h.get("customer") != filters["customer_id"]:
                continue
        if filters.get("monitoring_profile") and h.get("monitoring_profile") not in (
            filters["monitoring_profile"],
            "",
        ):
            if h.get("monitoring_profile") and h.get("monitoring_profile") != filters[
                "monitoring_profile"
            ]:
                continue
        if h.get("monitoring", "").lower() != "enabled":
            continue
        out.append(h)
    return out
