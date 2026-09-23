# 08 — Jenkins control-plane job (architecture-oriented)

Jenkins is **not** the monitoring system. It is the **control-plane trigger** that walks the same stages as the architecture diagram.

```text
Jenkins stages
  │
  ├─ Architecture context     (what this job is / is not)
  ├─ Preconditions            (python, config present)
  ├─ Discover (orchestrator)  (AssumeRole + EC2 tags)  ← retries
  ├─ Wait (IAM/SSM)           (eventual consistency gate)
  ├─ Enroll or Auto-heal      (Ansible via SSM)        ← retries
  ├─ Validate host            (agent asserts)          ← retries
  └─ Validate CloudWatch      (metric poll wait/retry)
           │
           ▼
     CloudWatch Agent keeps observing  (even if Jenkins dies later)
```

## File

[jenkins/Jenkinsfile](../jenkins/Jenkinsfile)

## Parameters that matter

| Parameter | Meaning |
|-----------|---------|
| `ACTION=enroll` | First-time agent install |
| `ACTION=reconcile` or `autoheal` | Idempotent repair (agent-missing / drift) |
| `ACTION=discover` | Inventory only |
| `DRY_RUN=true` | Safe demo — no live AWS mutations |
| `RUN_ANSIBLE=true` | Actually touch VMs (live only) |
| `ORCHESTRATOR_RETRIES` / `ANSIBLE_RETRIES` | Transient failure retries |
| `IAM_PROPAGATION_WAIT_SECONDS` | Wait before Ansible after IAM changes |
| `VALIDATE_CLOUDWATCH` | Poll metrics until PASS/FAIL |

## Auto-heal from Jenkins

When CloudWatch fires `disk-agent-missing-*`:

1. Run the same job with:
   - `ACTION=autoheal`
   - `DRY_RUN=false`
   - `RUN_ANSIBLE=true`
   - `VALIDATE_HOST=true`
2. Ansible runs `reconcile-agent-config.yml` (SSM retries + agent reinstall/restart + assert active)
3. Optionally set `VALIDATE_CLOUDWATCH=true` to wait for metrics again

## What Jenkins must NOT do

- Hardcode account IDs in Groovy (use parameters + `customer-accounts` registry)
- Call EC2/GCP/Azure APIs directly (orchestrator owns that)
- Store long-lived access keys in the job definition
- Continuously poll `df` (that is CloudWatch Agent’s job)

## If Jenkins is down

Existing CloudWatch Agent metrics and alarms **continue**.  
Only **new** enroll / auto-heal jobs are delayed.

See [reliability.md](reliability.md).

## Try without Jenkins

```bash
PYTHONPATH=. python3 -m orchestrator --cloud aws --customer nike \
  --account 111111111111 --environment prod --region us-east-1 --dry-run \
  --accounts-file config/customer-accounts.template.yaml
```

Same discover path the Jenkins `Discover` stage uses.
