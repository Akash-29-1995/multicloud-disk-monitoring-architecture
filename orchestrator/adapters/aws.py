"""AWS adapter — STS AssumeRole, EC2 discovery, normalized inventory."""

from __future__ import annotations

from typing import Any, Dict, List, Optional

from orchestrator.adapters.base import CloudAdapter
from orchestrator.auth.sts import assume_role_session
from orchestrator.inventory.models import Host, NormalizedInventory


class AWSAdapter(CloudAdapter):
    provider = "aws"

    def __init__(self, dry_run: bool = False):
        super().__init__(dry_run=dry_run)
        self._session = None
        self._auth_meta: Dict[str, Any] = {}

    def authenticate(self, context: Dict[str, Any]) -> None:
        role_arn = context.get("role_arn") or ""
        if not role_arn and not self.dry_run:
            # Same-account MVP: use default credentials without AssumeRole
            self._auth_meta = {
                "mode": "LIVE",
                "message": "[INFO] No role_arn — using default AWS credentials (single-account MVP)",
            }
            return

        if not role_arn and self.dry_run:
            self._auth_meta = {
                "mode": "DRY_RUN",
                "message": "[DRY RUN] No role_arn — would use default credentials (single-account MVP)",
            }
            return

        result = assume_role_session(
            role_arn=role_arn,
            session_name=context.get("session_name", "lucidity-orchestrator"),
            external_id=context.get("external_id") or None,
            region=context.get("region", "us-east-1"),
            dry_run=self.dry_run,
        )
        self._auth_meta = result
        self._session = result.get("session")

    def validate_access(self, context: Dict[str, Any]) -> Dict[str, Any]:
        if self.dry_run:
            return {
                "ok": True,
                "mode": "DRY_RUN",
                "message": "[DRY RUN] Access validation skipped — no live AWS API calls",
            }

        try:
            import boto3

            session = self._session or boto3.Session(region_name=context.get("region", "us-east-1"))
            sts = session.client("sts")
            ident = sts.get_caller_identity()
            return {
                "ok": True,
                "mode": "LIVE",
                "account": ident.get("Account"),
                "arn": ident.get("Arn"),
                "message": f"[PASS] STS identity {ident.get('Arn')}",
            }
        except Exception as exc:  # noqa: BLE001 — surface to operator
            return {
                "ok": False,
                "mode": "LIVE",
                "message": f"[FAIL] Access validation failed: {exc}",
            }

    def discover_resources(self, filters: Dict[str, Any]) -> List[Dict[str, Any]]:
        if self.dry_run:
            # Simulated sample hosts — clearly labeled, not production results
            customer = filters.get("customer_id", "example")
            env = filters.get("environment", "prod")
            return [
                {
                    "InstanceId": "i-DRYRUN0000000001",
                    "PrivateIpAddress": "10.0.1.10",
                    "State": {"Name": "running"},
                    "Placement": {"AvailabilityZone": f"{filters.get('region', 'us-east-1')}a"},
                    "Tags": [
                        {"Key": "Name", "Value": f"{customer}-app-01"},
                        {"Key": "Monitoring", "Value": "enabled"},
                        {"Key": "MonitoringProfile", "Value": filters.get("monitoring_profile", "standard")},
                        {"Key": "Environment", "Value": env},
                        {"Key": "Customer", "Value": customer},
                    ],
                    "_dry_run": True,
                },
                {
                    "InstanceId": "i-DRYRUN0000000002",
                    "PrivateIpAddress": "10.0.1.11",
                    "State": {"Name": "running"},
                    "Placement": {"AvailabilityZone": f"{filters.get('region', 'us-east-1')}a"},
                    "Tags": [
                        {"Key": "Name", "Value": f"{customer}-app-02"},
                        {"Key": "Monitoring", "Value": "enabled"},
                        {"Key": "MonitoringProfile", "Value": filters.get("monitoring_profile", "standard")},
                        {"Key": "Environment", "Value": env},
                        {"Key": "Customer", "Value": customer},
                    ],
                    "_dry_run": True,
                },
            ]

        import boto3

        session = self._session or boto3.Session(region_name=filters.get("region", "us-east-1"))
        ec2 = session.client("ec2", region_name=filters.get("region", "us-east-1"))

        ec2_filters = [
            {"Name": "instance-state-name", "Values": ["running"]},
            {"Name": "tag:Monitoring", "Values": ["enabled"]},
        ]
        if filters.get("environment"):
            ec2_filters.append(
                {"Name": "tag:Environment", "Values": [filters["environment"]]}
            )
        if filters.get("customer_id"):
            ec2_filters.append(
                {"Name": "tag:Customer", "Values": [filters["customer_id"]]}
            )
        if filters.get("monitoring_profile"):
            ec2_filters.append(
                {
                    "Name": "tag:MonitoringProfile",
                    "Values": [filters["monitoring_profile"]],
                }
            )

        paginator = ec2.get_paginator("describe_instances")
        instances: List[Dict[str, Any]] = []
        for page in paginator.paginate(Filters=ec2_filters):
            for reservation in page.get("Reservations", []):
                instances.extend(reservation.get("Instances", []))
        return instances

    def normalize_inventory(
        self,
        resources: List[Dict[str, Any]],
        context: Dict[str, Any],
    ) -> NormalizedInventory:
        hosts: List[Host] = []
        for inst in resources:
            tags = {t["Key"]: t["Value"] for t in inst.get("Tags", []) if "Key" in t}
            if tags.get("Monitoring", "").lower() != "enabled":
                continue
            hosts.append(
                Host(
                    resource_id=inst.get("InstanceId", "unknown"),
                    hostname=tags.get("Name", inst.get("InstanceId", "unknown")),
                    private_ip=inst.get("PrivateIpAddress", ""),
                    operating_system="linux",
                    monitoring="enabled",
                    monitoring_profile=tags.get(
                        "MonitoringProfile",
                        context.get("monitoring_profile", "standard"),
                    ),
                    environment=tags.get("Environment", context.get("environment", "")),
                    customer=tags.get("Customer", context.get("customer_id", "")),
                    region=context.get("region", ""),
                    extra={"platform": inst.get("PlatformDetails", "Linux/UNIX")},
                )
            )

        notes = []
        if self.dry_run:
            notes.append(
                "[DRY RUN] Hosts below are SIMULATED samples — not live AWS results"
            )
        if self._auth_meta.get("message"):
            notes.append(str(self._auth_meta["message"]))

        return NormalizedInventory(
            customer_id=context.get("customer_id", ""),
            cloud_provider="aws",
            account_id=str(context.get("account_id", "")),
            environment=context.get("environment", ""),
            region=context.get("region", "us-east-1"),
            monitoring_profile=context.get("monitoring_profile", "standard"),
            hosts=hosts,
            dry_run=self.dry_run,
            notes=notes,
        )
