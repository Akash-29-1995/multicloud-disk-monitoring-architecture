"""Cloud adapter interface — keep provider APIs out of Jenkins and Ansible."""

from __future__ import annotations

from abc import ABC, abstractmethod
from typing import Any, Dict, List

from orchestrator.inventory.models import Host, NormalizedInventory


class CloudAdapter(ABC):
    provider: str = "unknown"

    def __init__(self, dry_run: bool = False):
        self.dry_run = dry_run

    @abstractmethod
    def authenticate(self, context: Dict[str, Any]) -> None:
        """Establish credentials / AssumeRole. Dry-run must not claim live success."""

    @abstractmethod
    def validate_access(self, context: Dict[str, Any]) -> Dict[str, Any]:
        """Return a status dict describing access checks."""

    @abstractmethod
    def discover_resources(self, filters: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Return raw provider resources."""

    @abstractmethod
    def normalize_inventory(
        self,
        resources: List[Dict[str, Any]],
        context: Dict[str, Any],
    ) -> NormalizedInventory:
        """Map raw resources into NormalizedInventory."""

    def run(self, context: Dict[str, Any], filters: Dict[str, Any]) -> NormalizedInventory:
        self.authenticate(context)
        access = self.validate_access(context)
        resources = self.discover_resources(filters)
        inventory = self.normalize_inventory(resources, context)
        inventory.dry_run = self.dry_run
        if access.get("message"):
            inventory.notes.append(str(access["message"]))
        return inventory
