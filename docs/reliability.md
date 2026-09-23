# Reliability & auto-healing

## Failure matrix

| Failure | What continues | What pauses | Operator / automation action |
|---------|----------------|-------------|------------------------------|
| **Jenkins unavailable** | CloudWatch Agent → metrics/alarms | New enroll/heal jobs | CLI orchestrator + Ansible, or restore Jenkins |
| **Orchestrator unavailable** | Existing metrics | Discovery / inventory | Fix Python/CI; MVP can use `inventory/aws_ec2.yml` directly |
| **Ansible unavailable** | Existing metrics | New enrollment / heal | Restore Ansible; backlog reconcile |
| **CloudWatch Agent down** | — for that host | Telemetry for that host | Alarm `disk-agent-missing-*` → Jenkins `ACTION=autoheal` or `reconcile-agent-config.yml` |
| **SSM unavailable** | Existing agent telemetry if agent still running | Config / heal | Fix endpoints/profile; heal playbook retries SSM then fails clearly |
| **New VM appears** | — | Until tagged + enrolled | Tag → discover → enroll |
| **New AWS account** | — | Until role onboarded | Doc 03 + registry row |
| **IAM misconfigured** | Other accounts unaffected | That account | Mark `non_compliant`; fix trust |
| **CloudWatch unavailable** | Agent local buffer/retry (AWS) | Dashboards/alarms | AWS status; agent resumes |

## Why Jenkins / Ansible are not the monitoring system

```text
Jenkins DOWN or Ansible DOWN
            X
            |
CloudWatch Agent ---> CloudWatch   (continues)
```

Control plane sets up and heals. Data plane observes continuously.

## Auto-healing design

```text
Crash / drift / missing metrics
        │
        ▼
CloudWatch alarm: disk-agent-missing-*   (or validate failure)
        │
        ▼
Jenkins ACTION=autoheal  OR  ansible-playbook reconcile-agent-config.yml
        │
        ├── SSM reachability retries (delay/backoff)
        ├── Idempotent agent install/config (retries/until)
        ├── Wait until systemd active
        ├── Assert heal success
        └── Optional: validate-cloudwatch-metrics.sh poll loop
        │
        ▼
PASS → healthy    FAIL → docs/05-troubleshooting.md
```

### Where retries and waits are implemented

| Layer | Mechanism |
|-------|-----------|
| **Jenkins** | `retry()` on Discover, Ansible, host validate; `sleep` IAM/SSM wait gate; job timeout |
| **Orchestrator** | Dry-run safe; live STS/EC2 errors surface for Jenkins retry |
| **Ansible enroll** | SSM ping retries; package download/install `retries`+`delay`+`until`; service `until active` |
| **Ansible auto-heal** | Stronger SSM retries; full role re-apply; post-heal `systemctl is-active` until/assert |
| **CloudWatch validation script** | Poll loop up to 300s for metric datapoints |
| **Terraform / IAM** | Documented 30–60s propagation wait before AssumeRole/Ansible |
| **CloudWatch Agent (AWS)** | Local buffer/retry if CloudWatch API is briefly unavailable |

### Default retry knobs (`ansible/group_vars/all.yml.template`)

| Variable | Default | Purpose |
|----------|---------|---------|
| `agent_install_retries` | 5 | Package download/install |
| `agent_install_delay_seconds` | 15 | Backoff between install attempts |
| `service_wait_retries` | 12 | Wait for agent active |
| `service_wait_delay_seconds` | 5 | Between service checks |
| `heal_ssm_retries` | 5 | SSM Online before heal |
| `heal_ssm_delay_seconds` | 15 | Between SSM pings during heal |

Jenkins parameters `ORCHESTRATOR_RETRIES`, `ANSIBLE_RETRIES`, `IAM_PROPAGATION_WAIT_SECONDS` wrap the same idea at CI level.

## Auto-heal drill (prove it)

1. Stop agent: `sudo systemctl stop amazon-cloudwatch-agent`  
2. Confirm missing metrics / alarm path  
3. Run Jenkins `ACTION=autoheal` **or**:

```bash
cd ansible
ansible-playbook -i inventory/orchestrator-output/<file>.ini playbooks/reconcile-agent-config.yml -v
```

4. Expect `[PASS] Auto-heal complete — CloudWatch Agent is active`  
5. Optional: `./scripts/validate-cloudwatch-metrics.sh --instance-id i-...`

## What we intentionally did **not** build

A custom Lambda/Dynamo/SQS “healing platform”.  
Heal loop = **idempotent Ansible + CloudWatch alarms + Jenkins/CLI retries** — simple, auditable, assignment-aligned.
