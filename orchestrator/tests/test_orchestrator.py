"""Unit tests — no AWS credentials required."""

from __future__ import annotations

from pathlib import Path

import pytest

from orchestrator.adapters.aws import AWSAdapter
from orchestrator.adapters.factory import get_adapter
from orchestrator.inventory.generator import write_ansible_ini, write_normalized_yaml
from orchestrator.inventory.models import Host, NormalizedInventory
from orchestrator.main import main
from orchestrator.validators.params import resolve_account, validate_params


ROOT = Path(__file__).resolve().parents[2]


def test_validate_params_ok():
    ok, errors = validate_params(
        {
            "cloud": "aws",
            "customer_id": "nike",
            "environment": "prod",
            "region": "us-east-1",
            "action": "enroll",
        }
    )
    assert ok
    assert errors == []


def test_validate_params_missing():
    ok, errors = validate_params({"cloud": "aws"})
    assert not ok
    assert any("customer_id" in e for e in errors)


def test_get_adapter_aws():
    assert get_adapter("aws", dry_run=True).provider == "aws"


def test_get_adapter_gcp_raises_on_auth():
    adapter = get_adapter("gcp", dry_run=True)
    with pytest.raises(NotImplementedError):
        adapter.authenticate({})


def test_aws_dry_run_discover_and_normalize(tmp_path):
    adapter = AWSAdapter(dry_run=True)
    ctx = {
        "customer_id": "nike",
        "account_id": "111111111111",
        "environment": "prod",
        "region": "ap-south-1",
        "monitoring_profile": "standard",
        "role_arn": "arn:aws:iam::111111111111:role/DiskMonitoringExecutionRole",
    }
    inv = adapter.run(ctx, ctx)
    assert inv.dry_run is True
    assert len(inv.hosts) == 2
    assert all(h.resource_id.startswith("i-DRYRUN") for h in inv.hosts)
    assert any("DRY RUN" in n for n in inv.notes)

    yaml_path = write_normalized_yaml(inv, tmp_path / "inv.yaml")
    ini_path = write_ansible_ini(inv, tmp_path / "inv.ini")
    assert yaml_path.exists()
    assert "i-DRYRUN0000000001" in ini_path.read_text()


def test_resolve_account_from_example():
    from orchestrator.validators.params import load_accounts_registry

    reg = load_accounts_registry(ROOT / "config" / "accounts.yaml.example")
    acct = resolve_account(
        reg,
        customer_id="nike",
        account_id="111111111111",
        environment="prod",
        cloud="aws",
    )
    assert acct is not None
    assert acct["status"] == "enrolled"


def test_cli_dry_run(tmp_path):
    out = tmp_path / "generated"
    rc = main(
        [
            "--cloud",
            "aws",
            "--customer",
            "nike",
            "--account",
            "111111111111",
            "--environment",
            "prod",
            "--region",
            "us-east-1",
            "--dry-run",
            "--accounts-file",
            str(ROOT / "config" / "accounts.yaml.example"),
            "--output-dir",
            str(out),
        ]
    )
    assert rc == 0
    files = list(out.glob("*.ini"))
    assert files, "expected generated ansible inventory"
