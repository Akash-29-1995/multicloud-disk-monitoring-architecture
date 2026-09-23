"""CLI entrypoint for Lucidity orchestrator."""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path
from typing import List, Optional

from orchestrator.adapters.factory import get_adapter
from orchestrator.inventory.generator import (
    write_ansible_ini,
    write_normalized_yaml,
    write_summary_json,
)
from orchestrator.validators.params import (
    load_accounts_registry,
    load_monitoring_profile,
    resolve_account,
    validate_params,
)

ROOT = Path(__file__).resolve().parents[1]


def _banner(dry_run: bool) -> None:
    if dry_run:
        print("=" * 60)
        print("  MODE: DRY RUN  (no live cloud API mutations)")
        print("  Simulated discovery hosts are NOT production results")
        print("=" * 60)
    else:
        print("=" * 60)
        print("  MODE: LIVE AWS EXECUTION")
        print("=" * 60)


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="Lucidity multi-account disk monitoring orchestrator",
    )
    p.add_argument("--cloud", default="aws", help="aws|gcp|azure")
    p.add_argument("--customer", dest="customer_id", required=True, help="Customer id e.g. nike")
    p.add_argument("--account", dest="account_id", default="", help="AWS account id")
    p.add_argument("--environment", required=True, help="dev|pre-prod|prod")
    p.add_argument("--region", default="us-east-1")
    p.add_argument("--monitoring-profile", default="standard")
    p.add_argument(
        "--action",
        default="enroll",
        choices=("enroll", "reconcile", "discover"),
        help="What Jenkins/operator intends after discovery",
    )
    p.add_argument("--role-arn", default="", help="Override DiskMonitoringExecutionRole ARN")
    p.add_argument("--external-id", default="", help="Optional STS ExternalId")
    p.add_argument(
        "--accounts-file",
        default=str(ROOT / "config" / "accounts.yaml"),
        help="Path to accounts registry",
    )
    p.add_argument(
        "--profiles-file",
        default=str(ROOT / "config" / "monitoring-profiles.yaml"),
    )
    p.add_argument(
        "--output-dir",
        default=str(ROOT / "ansible" / "inventory" / "generated"),
    )
    p.add_argument("--dry-run", action="store_true", help="Simulate without live AWS calls")
    return p


def main(argv: Optional[List[str]] = None) -> int:
    args = build_parser().parse_args(argv)
    _banner(args.dry_run)

    params = {
        "cloud": args.cloud,
        "customer_id": args.customer_id,
        "account_id": args.account_id,
        "environment": args.environment,
        "region": args.region,
        "action": args.action,
        "monitoring_profile": args.monitoring_profile,
        "dry_run": args.dry_run,
    }

    ok, errors = validate_params(params)
    if not ok:
        for e in errors:
            print(f"[FAIL] {e}")
        return 2
    print("[PASS] Parameters validated")

    # Prefer example registry when accounts.yaml not present (reviewer clone)
    accounts_path = Path(args.accounts_file)
    if not accounts_path.exists():
        example = ROOT / "config" / "accounts.yaml.example"
        if example.exists():
            accounts_path = example
            print(f"[INFO] Using {example} (copy to accounts.yaml for real registry)")

    registry = load_accounts_registry(accounts_path)
    account = resolve_account(
        registry,
        customer_id=args.customer_id,
        account_id=args.account_id or None,
        environment=args.environment,
        cloud=args.cloud,
    )

    role_arn = args.role_arn
    external_id = args.external_id or os.environ.get("LUCIDITY_EXTERNAL_ID", "")
    account_id = args.account_id

    if account:
        print(f"[PASS] Registry match: {account.get('name')} status={account.get('status')}")
        if account.get("status") == "non_compliant":
            print("[FAIL] Account marked non_compliant — fix IAM before enrollment")
            return 3
        role_arn = role_arn or account.get("role_arn", "")
        account_id = account_id or str(account.get("account_id", ""))
        if not external_id:
            external_id = str(account.get("external_id") or "")
        regions = account.get("regions") or []
        if regions and args.region not in regions:
            print(
                f"[WARN] Region {args.region} not in registry regions {regions} — continuing"
            )
    else:
        print(
            "[WARN] No registry match — continuing with CLI flags only "
            "(ok for single-account MVP / dry-run demo)"
        )

    profile = load_monitoring_profile(Path(args.profiles_file), args.monitoring_profile)
    if profile:
        print(f"[PASS] Loaded monitoring profile '{args.monitoring_profile}'")
    else:
        print(f"[WARN] Profile '{args.monitoring_profile}' not found — using defaults")

    try:
        adapter = get_adapter(args.cloud, dry_run=args.dry_run)
    except ValueError as exc:
        print(f"[FAIL] {exc}")
        return 2
    except NotImplementedError as exc:
        print(f"[FAIL] {exc}")
        return 4

    context = {
        "customer_id": args.customer_id,
        "account_id": account_id,
        "environment": args.environment,
        "region": args.region,
        "monitoring_profile": args.monitoring_profile,
        "role_arn": role_arn,
        "external_id": external_id,
        "session_name": f"lucidity-{args.customer_id}-{args.action}",
    }
    filters = {
        "customer_id": args.customer_id,
        "environment": args.environment,
        "region": args.region,
        "monitoring_profile": args.monitoring_profile,
    }

    print(f"[INFO] Adapter={adapter.provider} action={args.action}")
    try:
        inventory = adapter.run(context, filters)
    except NotImplementedError as exc:
        print(f"[FAIL] {exc}")
        return 4
    except Exception as exc:  # noqa: BLE001
        print(f"[FAIL] Orchestration error: {exc}")
        return 1

    for note in inventory.notes:
        print(f"[INFO] {note}")

    out_dir = Path(args.output_dir)
    stem = f"{args.customer_id}_{account_id or 'noacct'}_{args.environment}_{args.region}"
    yaml_path = write_normalized_yaml(inventory, out_dir / f"{stem}.yaml")
    ini_path = write_ansible_ini(inventory, out_dir / f"{stem}.ini")
    json_path = write_summary_json(inventory, out_dir / f"{stem}.json")

    print(f"[PASS] Discovered host_count={len(inventory.hosts)}")
    for h in inventory.hosts:
        print(f"       - {h.resource_id} ({h.hostname}) {h.private_ip}")
    print(f"[PASS] Wrote normalized inventory: {yaml_path}")
    print(f"[PASS] Wrote Ansible inventory:    {ini_path}")
    print(f"[PASS] Wrote summary JSON:         {json_path}")

    playbook = {
        "enroll": "playbooks/enroll.yml",
        "reconcile": "playbooks/configure-monitoring.yml",
        "discover": None,
    }.get(args.action)

    if playbook and inventory.hosts:
        print("[INFO] Next step (from ansible/ directory):")
        print(
            f"  ansible-playbook -i inventory/generated/{ini_path.name} {playbook} -v"
        )
    elif args.action == "discover":
        print("[INFO] Discover-only complete — no Ansible playbook invoked")
    else:
        print("[WARN] No eligible hosts — Ansible enroll skipped")

    if args.dry_run:
        print("[INFO] DRY RUN complete — re-run without --dry-run for LIVE AWS EXECUTION")
    return 0


if __name__ == "__main__":
    sys.exit(main())
