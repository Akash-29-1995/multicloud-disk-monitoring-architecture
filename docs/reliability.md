# Reliability & auto-healing

## Failure matrix

| Failure | What continues | What pauses | Operator action |
|---------|----------------|-------------|-----------------|
| **Ansible unavailable** | CloudWatch Agent → metrics/alarms | New enrollment / reconcile | Restore Ansible; backlog enroll |
| **Jenkins unavailable** | Existing metrics/alarms | New orchestrated jobs | Use CLI `python -m orchestrator` or restore Jenkins |
| **Orchestrator unavailable** | Existing metrics/alarms | Discovery / inventory generation | Fix Python/CI; Ansible direct aws_ec2 path still works for MVP |
| **CloudWatch Agent down** | — for that host | Telemetry for that host | `agent-missing` alarm → `reconcile-agent-config.yml` |
| **SSM unavailable** | Existing agent telemetry if agent still running | New config / Ansible reaches | Fix SSM/endpoints; retry enroll |
| **New VM appears** | — | Until tagged + enrolled | Tag → orchestrator/aws_ec2 → enroll |
| **New AWS account** | — | Until role onboarded | Doc 03 + registry row |
| **IAM role misconfigured** | Other accounts unaffected | That account | Mark `non_compliant`; fix trust |
| **VM not SSM-managed** | — | Enrollment | FAIL validation; fix instance profile |
| **CloudWatch unavailable** | Agent local buffer/retry (AWS behavior) | Dashboards/alarms | AWS status; agent resumes |

## Why Jenkins is not the monitoring system

```text
Jenkins DOWN
     X
     |
CloudWatch Agent ---> CloudWatch  (continues)
```

Same rule as Ansible: **control plane ≠ data plane**.

## Auto-healing design

```text
Drift / crash / missing metrics
        │
        ▼
Alarm (agent-missing) or failed validate
        │
        ▼
Re-run reconcile-agent-config.yml / enroll-disk-monitoring.yml  (idempotent)
        │
        ├── retries + delay + until on install/service
        ├── wait for IAM propagation (docs)
        └── validate-cloudwatch-metrics.sh polls CloudWatch with timeout
        │
        ▼
PASS → healthy   FAIL → troubleshooting guide
```

### Built-in retry / wait points

| Location | Mechanism |
|----------|-----------|
| Package download/install | `retries`, `delay`, `until` |
| Service active | `until` + `systemctl is-active` |
| SSM ping | 3 retries × 10s |
| IAM after Terraform | Documented 30–60s wait |
| Metric appearance | `validate-cloudwatch-metrics.sh` poll loop (default 300s) |

### What we intentionally did **not** build

Lambda/Dynamo/SQS “self-healing microservice” — keep heal loop = idempotent Ansible + CloudWatch alarms.
