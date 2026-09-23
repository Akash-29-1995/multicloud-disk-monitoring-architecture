# Lucidity — Scalable Disk Monitoring for AWS (SaaS-ready)

Secure, scalable **disk utilization monitoring** across many **customers**, AWS accounts, and thousands of EC2 instances — with a clean extension path to GCP/Azure.

**Ansible manages the desired monitoring state. CloudWatch continuously observes the state.**  
**Jenkins is a thin trigger. The Python orchestrator handles discovery. Cloud-native services handle telemetry.**

---

## Start here

| Your goal | Where to go |
|-----------|-------------|
| **Understand in 2 minutes** | This README |
| Install tools | [docs/01-prerequisites.md](docs/01-prerequisites.md) |
| Run MVP on **your** AWS (single account) | [docs/02-single-account-onboarding.md](docs/02-single-account-onboarding.md) |
| Add more AWS accounts | [docs/03-multi-account-onboarding.md](docs/03-multi-account-onboarding.md) |
| Try orchestrator **without AWS** (dry-run) | [docs/06-orchestrator-dry-run.md](docs/06-orchestrator-dry-run.md) |
| Multi-customer SaaS model | [docs/07-multi-customer-saas-model.md](docs/07-multi-customer-saas-model.md) |
| Jenkins thin trigger | [docs/08-jenkins-thin-trigger.md](docs/08-jenkins-thin-trigger.md) |
| Prove it works | [docs/04-validation-checklist.md](docs/04-validation-checklist.md) |
| Something broke | [docs/05-troubleshooting.md](docs/05-troubleshooting.md) |
| Security / IAM roles | [docs/security.md](docs/security.md) |
| Reliability / healing | [docs/reliability.md](docs/reliability.md) |
| Why these tools | [docs/tradeoffs.md](docs/tradeoffs.md) |

Architecture: [architecture/architecture.md](architecture/architecture.md) · ![diagram](architecture/architecture.png)

Glossary: [docs/00-glossary.md](docs/00-glossary.md)

---

## Big picture

```text
Jenkins (optional) or CLI
        │
        ▼
Python Orchestrator ── AWS Adapter ──► STS AssumeRole ──► EC2 discovery
        │                                    (GCP/Azure = stubs)
        ▼
Normalized inventory (ansible/inventory/generated/)
        │
        ▼
Ansible ──► SSM ──► CloudWatch Agent ──► CloudWatch ──► Dashboard / Alarms
```

Adding **Customer #N** or **Account #101** = registry row + role deploy + same job parameters.  
**Not** a new pipeline or playbook tree.

---

## Quick starts

### A) Static check (no AWS)

```bash
./scripts/validate.sh
```

**Expected:** `FAIL=0`

### B) Orchestrator dry-run (no AWS)

```bash
python3 -m pip install --user -r orchestrator/requirements.txt
PYTHONPATH=. python3 -m orchestrator \
  --cloud aws --customer nike --account 111111111111 \
  --environment prod --region us-east-1 --dry-run \
  --accounts-file config/accounts.yaml.example
```

**Expected:** `MODE: DRY RUN`, `host_count=2`, inventory files under `ansible/inventory/generated/`  
Dry-run hosts (`i-DRYRUN...`) are **simulated** — not live AWS.

### C) Single-account live MVP (reviewers with AWS)

Follow [docs/02-single-account-onboarding.md](docs/02-single-account-onboarding.md):

1. `terraform/environments/example` apply  
2. Attach instance profile + tags (`Monitoring=enabled`, `MonitoringProfile=standard`, `Environment=production`, `Customer=demo`)  
3. `ansible-playbook` with `inventory/aws_ec2.yml` **or** orchestrator-generated inventory  
4. `./scripts/validate_live.sh --instance-id i-...`

---

## What each layer does

| Layer | Responsibility |
|-------|----------------|
| **Jenkins** | Parameters only → calls orchestrator ([jenkins/Jenkinsfile](jenkins/Jenkinsfile)) |
| **Orchestrator** | Customer/account context, AssumeRole, discover, normalize inventory, dry-run |
| **Terraform** | Least-privilege IAM, instance profile, dashboard, SNS, alarms |
| **Ansible** | Idempotent CloudWatch Agent install/config/reconcile via SSM |
| **CloudWatch Agent** | Continuous `disk_used_percent` + `disk_free` |
| **CloudWatch** | Dashboard + warning/critical/% + free-space + agent-missing alarms |

Ansible does **not** continuously run `df -h`.

---

## Config you will copy

| File | Purpose |
|------|---------|
| [config/accounts.yaml.example](config/accounts.yaml.example) | Multi-customer account registry → copy to `accounts.yaml` |
| [config/monitoring-profiles.yaml](config/monitoring-profiles.yaml) | Warning/critical/min-free thresholds |
| [terraform/.../terraform.tfvars.example](terraform/environments/example/terraform.tfvars.example) | Terraform inputs |

---

## Auto-healing

- Idempotent `enroll.yml` / `configure-monitoring.yml`  
- Retries / waits / `until` on install & service  
- `disk-agent-missing-*` alarm → re-run reconcile  
- `validate_live.sh` polls CloudWatch until PASS/FAIL  

Details: [docs/reliability.md](docs/reliability.md)

---

## Security (strict)

- No secrets in git  
- Three-role model: Orchestrator → Execution → Instance ([docs/security.md](docs/security.md))  
- Trust policy ≠ permissions policy  
- SSM preferred; SSH only as documented fallback  

---

## Repository map

```text
README.md                 ← you are here (hub)
architecture/             Diagram + narrative
orchestrator/             Python control plane (AWS + stubs + tests)
jenkins/Jenkinsfile       Thin CI trigger
terraform/                IAM + CloudWatch infra
ansible/                  Enrollment roles/playbooks + generated inventory
cloudwatch/               Dashboard + alarm templates
config/                   Accounts registry + monitoring profiles
docs/                     Deep / beginner guides
scripts/                  validate.sh + validate_live.sh
```

---

## Definition of Done

- [x] Architecture + multi-account + multi-customer model  
- [x] Cross-account IAM + three-role clarity  
- [x] Dynamic discovery + orchestrator dry-run/live  
- [x] Normalized inventory → Ansible  
- [x] Idempotent Ansible + SSM + CloudWatch Agent  
- [x] Dashboard + dual-threshold alarms  
- [x] Jenkins thin trigger  
- [x] Security / scalability / reliability / tradeoffs  
- [x] Beginner docs with expected outputs  
- [x] No secrets in repo  
- [x] No unsupported “tested at 5000 VMs” claims  

---

## Honesty

- Static + unit + dry-run: `./scripts/validate.sh`  
- Live AWS path designed for **reviewers’ accounts**  
- GCP/Azure = **stubs** (extension points), not full implementations  
- Author did not load-test 5,000 VMs (no personal AWS)  
