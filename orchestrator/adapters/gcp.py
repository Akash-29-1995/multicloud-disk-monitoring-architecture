"""GCP adapter stub — extension point only (not implemented in MVP)."""

from __future__ import annotations

from typing import Any, Dict, List

from orchestrator.adapters.base import CloudAdapter
from orchestrator.inventory.models import NormalizedInventory


class GCPAdapter(CloudAdapter):
    provider = "gcp"

    def authenticate(self, context: Dict[str, Any]) -> None:
        raise NotImplementedError(
            "GCP adapter is an extension point. MVP implements AWS only. "
            "See docs/07-multi-customer-saas-model.md"
        )

    def validate_access(self, context: Dict[str, Any]) -> Dict[str, Any]:
        raise NotImplementedError("GCP adapter not implemented")

    def discover_resources(self, filters: Dict[str, Any]) -> List[Dict[str, Any]]:
        raise NotImplementedError("GCP adapter not implemented")

    def normalize_inventory(
        self,
        resources: List[Dict[str, Any]],
        context: Dict[str, Any],
    ) -> NormalizedInventory:
        raise NotImplementedError("GCP adapter not implemented")
