# Architecture — Lucidity scalable disk monitoring

## Core principle

> **Ansible manages the desired monitoring state; CloudWatch continuously observes the state.**  
> **Jenkins/Orchestrator are the control-plane trigger — never the telemetry path.**

```text
Jenkins (thin) → Python Orchestrator → Cloud Adapter → Normalized Inventory
        → Ansible → SSM → CloudWatch Agent → CloudWatch → Dashboard/Alarms
```

## End-to-end (SaaS multi-customer)

```text
Customer / Cloud / Environment parameters
             |
             v
          Jenkins (optional)  or  CLI
             |
             v
    Python Orchestrator
             |
      +------+------+
      |      |      |
     AWS    GCP   Azure
   Adapter Adapter(stub) Adapter(stub)
      |
      v
 Cross-account STS AssumeRole
      |
      v
 Dynamic EC2 discovery (tags)
      |
      v
 Normalized Inventory
      |
      v
 Ansible enroll / reconcile
      |
      v
 SSM → CloudWatch Agent → continuous disk metrics
      |
      v
 CloudWatch dashboard / alarms / SNS
```

## Diagram

See [architecture.png](architecture.png) and [architecture.svg](architecture.svg).

## Data plane vs control plane

| Plane | Components | If down |
|-------|------------|---------|
| Control | Jenkins, orchestrator, Ansible, SSM config | Metrics already enrolled **continue** |
| Data | CloudWatch Agent → CloudWatch | Independent of Jenkins/Ansible |

## IAM (three roles)

See [docs/security.md](../docs/security.md): Orchestrator (central) → Execution (workload) → Instance profile (EC2).

## Tag enrollment contract

| Tag | Example |
|-----|---------|
| `Monitoring` | `enabled` |
| `MonitoringProfile` | `standard` |
| `Environment` | `prod` |
| `Customer` | `nike` |

## Metrics

- `disk_used_percent` (warning/critical via profile)  
- `disk_free` (absolute floor via profile)  

Profiles: [config/monitoring-profiles.yaml](../config/monitoring-profiles.yaml)

## Two operator paths (both valid)

1. **Reviewer MVP (simple):** Terraform → tag EC2 → `ansible/inventory/aws_ec2.yml` → enroll → `validate_live.sh`  
2. **SaaS multi-customer:** Orchestrator (dry-run/live) → generated inventory → Ansible → same agent/CloudWatch  

## MVP vs production

| MVP | Production evolution |
|-----|----------------------|
| `accounts.yaml` | Organizations + EventBridge |
| Manual/scheduled discover | Event-driven EC2/account create |
| Single-account dashboard | Cross-account observability |

Control Tower: **optional**.
