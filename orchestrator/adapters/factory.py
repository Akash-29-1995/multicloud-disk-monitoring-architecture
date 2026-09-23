"""Adapter factory."""

from __future__ import annotations

from orchestrator.adapters.aws import AWSAdapter
from orchestrator.adapters.azure import AzureAdapter
from orchestrator.adapters.base import CloudAdapter
from orchestrator.adapters.gcp import GCPAdapter


def get_adapter(cloud: str, dry_run: bool = False) -> CloudAdapter:
    key = (cloud or "").strip().lower()
    if key == "aws":
        return AWSAdapter(dry_run=dry_run)
    if key == "gcp":
        return GCPAdapter(dry_run=dry_run)
    if key in ("azure", "az"):
        return AzureAdapter(dry_run=dry_run)
    raise ValueError(f"Unsupported cloud provider: {cloud!r}. Use aws|gcp|azure")
