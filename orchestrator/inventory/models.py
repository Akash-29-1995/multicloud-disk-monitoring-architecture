"""Provider-neutral inventory models."""

from __future__ import annotations

from dataclasses import asdict, dataclass, field
from typing import Any, Dict, List, Optional


@dataclass
class Host:
    resource_id: str
    hostname: str
    private_ip: str
    operating_system: str
    monitoring: str
    monitoring_profile: str
    environment: str = ""
    customer: str = ""
    region: str = ""
    extra: Dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> Dict[str, Any]:
        data = asdict(self)
        extra = data.pop("extra", {}) or {}
        data.update(extra)
        return data


@dataclass
class NormalizedInventory:
    customer_id: str
    cloud_provider: str
    account_id: str
    environment: str
    region: str
    monitoring_profile: str
    hosts: List[Host] = field(default_factory=list)
    dry_run: bool = False
    notes: List[str] = field(default_factory=list)

    def to_dict(self) -> Dict[str, Any]:
        return {
            "customer_id": self.customer_id,
            "cloud_provider": self.cloud_provider,
            "account_id": self.account_id,
            "environment": self.environment,
            "region": self.region,
            "monitoring_profile": self.monitoring_profile,
            "dry_run": self.dry_run,
            "notes": self.notes,
            "hosts": [h.to_dict() for h in self.hosts],
            "host_count": len(self.hosts),
        }
