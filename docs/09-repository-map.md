# 09 — Repository map (what every folder means)

Read this if you are new to the repo. Every important path is explained in plain language.

```text
lucidity-disk-monitoring/
|
|-- README.md                          Start here — hub + quick starts
|-- architecture/                      Pictures + written architecture story
|-- docs/                              Step-by-step guides (00 → 09)
|-- config/                            Customer accounts + alert profiles
|-- orchestrator/                      Python “brain” that discovers VMs
|-- jenkins/                           Thin CI job (parameters only)
|-- terraform/                         Creates AWS IAM + dashboards + alarms
|-- ansible/                           Installs/configures CloudWatch Agent on VMs
|-- cloudwatch/                        Dashboard + alarm JSON templates
|-- scripts/                           Validation helpers (no secrets)
```

---

## Top-level folders

| Path | What it is | Who uses it |
|------|------------|-------------|
| `architecture/` | How the system works (flows + diagrams) | Reviewers / architects |
| `docs/` | Numbered how-to guides | Operators following steps |
| `config/` | Lists of customers/accounts + disk alert profiles | Orchestrator + humans |
| `orchestrator/` | Discovers VMs, writes inventory for Ansible | Jenkins / CLI |
| `jenkins/` | One pipeline file that only calls the orchestrator | CI |
| `terraform/` | Creates AWS roles, instance profiles, dashboards, alarms | Cloud engineers |
| `ansible/` | Puts CloudWatch Agent on EC2 via SSM | Operators |
| `cloudwatch/` | Dashboard & alarm JSON used by Terraform | Terraform |
| `scripts/` | Checks that the repo / AWS path is healthy | Everyone |

---

## `terraform/environments/` — real environment names

| Folder | Meaning |
|--------|---------|
| `single-account-mvp/` | **First deploy** on one AWS account (reviewer path) |
| `workload-account/` | Deploy monitoring IAM **inside a customer AWS account** |
| `central-monitoring-account/` | Central dashboard + registry of workload role ARNs |

| File pattern | Meaning |
|--------------|---------|
| `*.tfvars.template` | Safe template — copy to `terraform.tfvars` (gitignored) and fill your values |
| `main.tf` / `variables.tf` | Actual infrastructure code |

---

## `terraform/modules/` — reusable building blocks

| Module | Creates |
|--------|---------|
| `monitoring-role/` | Cross-account execution role + EC2 instance profile |
| `cloudwatch/` | SNS topic, dashboard, disk % / free-space / agent-missing alarms |
| `monitoring-account/` | Central list of workload role ARNs (SSM parameter) |

---

## `ansible/` — agent enrollment

| Path | Meaning |
|------|---------|
| `playbooks/enroll-disk-monitoring.yml` | First-time install + configure agent |
| `playbooks/reconcile-agent-config.yml` | Re-apply config when something drifts / agent dies |
| `playbooks/validate-agent-on-host.yml` | Assert package/service/config on the VM |
| `roles/cloudwatch_agent/` | The reusable tasks (install, template, start, assert) |
| `inventory/aws_ec2.yml` | Direct AWS discovery by tags (simple MVP) |
| `inventory/orchestrator-output/` | Files written by the orchestrator for Ansible |
| `inventory/HOW-TO-CHOOSE-INVENTORY.md` | Which inventory to use |
| `group_vars/all.yml.template` | Copy → `all.yml` for region / SSM bucket |

---

## `orchestrator/` — discovery brain

| Path | Meaning |
|------|---------|
| `main.py` | CLI entry (`python -m orchestrator`) |
| `adapters/aws.py` | Real AWS AssumeRole + EC2 discovery |
| `adapters/gcp.py` / `azure.py` | Stubs (extension points, not implemented) |
| `inventory/` | Normalized host model + writers (YAML/INI/JSON) |
| `auth/sts.py` | Cross-account AssumeRole helper |
| `tests/` | Unit tests (no AWS needed) |

---

## `config/`

| File | Meaning |
|------|---------|
| `customer-accounts.template.yaml` | Sample Nike accounts — copy to `customer-accounts.yaml` |
| `monitoring-profiles.yaml` | `standard` / `aggressive` disk thresholds |

---

## `scripts/`

| Script | Meaning |
|--------|---------|
| `validate.sh` | Static checks + orchestrator tests (no AWS) |
| `validate-cloudwatch-metrics.sh` | Polls CloudWatch until disk metrics appear (needs AWS) |

---

## `docs/` reading order

| Doc | Topic |
|-----|-------|
| `00-glossary.md` | Words |
| `01-prerequisites.md` | Tools |
| `02-single-account-onboarding.md` | Live MVP |
| `03-multi-account-onboarding.md` | Account B, C, … |
| `04-validation-checklist.md` | Prove it |
| `05-troubleshooting.md` | Fixes |
| `06-orchestrator-dry-run.md` | Dry-run without AWS |
| `07-multi-customer-saas-model.md` | Nike / Adidas model |
| `08-jenkins-thin-trigger.md` | CI |
| `09-repository-map.md` | This file |
| `security.md` / `reliability.md` / `scalability.md` / `tradeoffs.md` | SA depth |
