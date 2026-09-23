# Onboarding model (architecture view)

Beginner steps: [02-single-account-onboarding.md](02-single-account-onboarding.md), [03-multi-account-onboarding.md](03-multi-account-onboarding.md).

## New AWS account

```text
New account in AWS Organizations
        │
        ▼
Deploy DiskMonitoringExecutionRole (IaC / StackSet)
        │
        ▼
Trust central management principal (+ ExternalId)
        │
        ▼
Register ARN in accounts.yaml / SSM parameter
        │
        ▼
Account discoverable → EC2 discovery → enrollment
```

### MVP

Static list: `config/customer-accounts.template.yaml` → `accounts.yaml`.

### Production

- Organizations list-accounts / Account Created EventBridge events  
- Optional Control Tower lifecycle events / AFT / Customizations for Control Tower  
- Control Tower is **optional** — not a hard dependency  

## New EC2 VM

```text
New EC2
  │
  ▼
Instance profile (SSM + CW agent permissions)
  │
  ▼
Tags: Monitoring=enabled, MonitoringProfile=..., Environment=...
  │
  ▼
Dynamic inventory sees host
  │
  ▼
Ansible enroll via SSM
  │
  ▼
CloudWatch metrics + alarms
```

No manual IP inventory.

## Non-compliance

| Condition | Status |
|-----------|--------|
| AssumeRole denied | `non_compliant` — visible, not silent |
| SSM not Online | Block enrollment with clear FAIL |
| Metrics missing after timeout | FAIL from `validate-cloudwatch-metrics.sh` + agent-missing alarm |

## Orchestrator path

For multi-customer discovery, use `python -m orchestrator` (see docs/06). Direct `aws_ec2` inventory remains valid for single-account MVP.

