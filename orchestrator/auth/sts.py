"""STS AssumeRole helper for AWS cross-account access."""

from __future__ import annotations

from typing import Any, Dict, Optional


def assume_role_session(
    role_arn: str,
    session_name: str = "lucidity-orchestrator",
    external_id: Optional[str] = None,
    region: str = "us-east-1",
    dry_run: bool = False,
) -> Dict[str, Any]:
    """
    Return a boto3 session dict or a dry-run placeholder.

    Dry-run NEVER pretends credentials were issued by AWS.
    """
    if dry_run:
        return {
            "mode": "DRY_RUN",
            "role_arn": role_arn,
            "session_name": session_name,
            "external_id_set": bool(external_id),
            "region": region,
            "message": "[DRY RUN] Would call sts:AssumeRole — no live credentials obtained",
        }

    import boto3  # lazy import so dry-run works without boto3 installed for unit tests of other paths

    sts = boto3.client("sts", region_name=region)
    kwargs: Dict[str, Any] = {
        "RoleArn": role_arn,
        "RoleSessionName": session_name,
    }
    if external_id:
        kwargs["ExternalId"] = external_id
    resp = sts.assume_role(**kwargs)
    creds = resp["Credentials"]
    session = boto3.Session(
        aws_access_key_id=creds["AccessKeyId"],
        aws_secret_access_key=creds["SecretAccessKey"],
        aws_session_token=creds["SessionToken"],
        region_name=region,
    )
    return {
        "mode": "LIVE",
        "role_arn": role_arn,
        "session": session,
        "message": f"[PASS] Assumed role {role_arn}",
    }
