"""Input and registry validators."""

from __future__ import annotations

from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import yaml


REQUIRED_PARAMS = ("cloud", "customer_id", "environment", "region", "action")


def validate_params(params: Dict[str, Any]) -> Tuple[bool, List[str]]:
    errors: List[str] = []
    for key in REQUIRED_PARAMS:
        if not params.get(key):
            errors.append(f"Missing required parameter: {key}")
    cloud = (params.get("cloud") or "").lower()
    if cloud and cloud not in ("aws", "gcp", "azure"):
        errors.append(f"Invalid cloud: {cloud}")
    action = (params.get("action") or "").lower()
    if action and action not in ("enroll", "reconcile", "discover"):
        errors.append(f"Invalid action: {action} (use enroll|reconcile|discover)")
    if cloud == "aws" and not params.get("account_id") and not params.get("dry_run"):
        # account_id strongly recommended for multi-account; allow for dry-run demos
        pass
    return (len(errors) == 0, errors)


def load_accounts_registry(path: Path) -> Dict[str, Any]:
    if not path.exists():
        return {"accounts": []}
    with path.open(encoding="utf-8") as fh:
        return yaml.safe_load(fh) or {"accounts": []}


def resolve_account(
    registry: Dict[str, Any],
    *,
    customer_id: str,
    account_id: Optional[str],
    environment: str,
    cloud: str = "aws",
) -> Optional[Dict[str, Any]]:
    accounts = registry.get("accounts") or []
    matches = [
        a
        for a in accounts
        if str(a.get("customer_id", "")).lower() == customer_id.lower()
        and str(a.get("cloud_provider", "aws")).lower() == cloud.lower()
        and str(a.get("environment", "")).lower() == environment.lower()
    ]
    if account_id:
        matches = [a for a in matches if str(a.get("account_id")) == str(account_id)]
    if not matches:
        return None
    return matches[0]


def load_monitoring_profile(path: Path, profile_name: str) -> Dict[str, Any]:
    if not path.exists():
        return {}
    with path.open(encoding="utf-8") as fh:
        data = yaml.safe_load(fh) or {}
    profiles = data.get("profiles") or {}
    name = profile_name or data.get("default_profile") or "standard"
    return profiles.get(name) or {}
