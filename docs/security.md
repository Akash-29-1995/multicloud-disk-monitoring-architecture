# Security model

## Principles

1. **No static AWS access keys** in git or Jenkins job scripts  
2. **SSM preferred** for enrollment — no SSH key distribution in the happy path  
3. **Least privilege IAM** — never `AdministratorAccess` on the monitoring workflow  
4. **Restricted cross-account trust** — explicit principal ARNs; optional ExternalId  
5. **Secrets stay out of GitHub** — `.gitignore` blocks `*.tfvars`, `.env`, keys  
6. **Auditable** — CloudTrail records AssumeRole, SSM, IAM changes  

---

## Three IAM roles (do not confuse them)

| Role | Where it lives | Used by | Purpose |
|------|----------------|---------|---------|
| **MonitoringOrchestratorRole** (central) | Management / SaaS account | Jenkins agent, Python orchestrator | Allowed to `sts:AssumeRole` into customer accounts |
| **DiskMonitoringExecutionRole** (workload) | Each customer AWS account | Assumed by orchestrator | EC2 discovery, SSM enrollment commands, CW validate |
| **DiskMonitoringInstanceRole** + instance profile | Each monitored EC2 | The VM itself | SSM agent + CloudWatch Agent permissions |

```text
Jenkins / Orchestrator
        |  (uses MonitoringOrchestratorRole or SSO user)
        v
   sts:AssumeRole
        |
        v
DiskMonitoringExecutionRole  (customer account)
        |
        +-- describe EC2 / SSM
        |
EC2 instance uses DiskMonitoringInstanceProfile
        |
        +-- publish metrics / talk to SSM
```

In this repo’s Terraform MVP, the **execution role** + **instance profile** are created by `terraform/modules/monitoring-role`. The central orchestrator principal is whatever identity runs the CLI/Jenkins (configure `trusted_principal_arns` to that ARN).

### Trust policy vs permissions policy

| Policy | Answers |
|--------|---------|
| **Trust policy** (on execution role) | *Who* may AssumeRole? → central orchestrator ARN only (never `*`) |
| **Permissions policy** (on execution role) | *What* can they do after assuming? → describe EC2, SSM send/list, CW get |

These are separate controls. Fixing trust does not grant Admin; fixing permissions does not open trust to the world.

Optional **ExternalId** further hardens AssumeRole (set via env `LUCIDITY_EXTERNAL_ID`, not git).

---

## Policy inventory (execution + instance)

| Role / profile | Key allows | Trust | Forbidden |
|----------------|------------|-------|-----------|
| `DiskMonitoringExecutionRole` | `ec2:Describe*`, SSM describe/list/send (scoped), CloudWatch get/list | Central orchestrator principal ARN(s) | Admin; IAM user/key creation (Deny) |
| `DiskMonitoringInstanceRole` | `AmazonSSMManagedInstanceCore`, `CloudWatchAgentServerPolicy` | `ec2.amazonaws.com` | Broad admin |

Future split (optional): separate Discovery vs Enrollment roles if privilege levels must diverge.

---

## SSH fallback (not preferred)

Preferred path is **SSM**.

If SSH is required in an enterprise:

```text
Ansible controller → bastion / management subnet → private EC2
```

Rules:

- Do not expose port 22 to `0.0.0.0/0`  
- Do not distribute long-lived PEM files to engineers  
- Prefer short-lived SSH certificates or Secrets Manager–backed keys  
- Document SSM as the AWS default in runbooks  

---

## Tag governance

**Chosen model: opt-in** (`Monitoring=enabled`). Safer for multi-customer SaaS.  
See [07-multi-customer-saas-model.md](07-multi-customer-saas-model.md).

---

## Secrets handling

| Item | Where it lives | In git? |
|------|----------------|---------|
| `terraform.tfvars` | Local / CI | **No** |
| ExternalId | Password manager / Jenkins creds / env | **No** |
| AWS keys | SSO / instance role / OIDC | **No** |
| Role ARNs | `accounts.yaml` | OK (not secrets) |

---

## Cross-account observability

Prefer **local metrics in each workload account** + central CloudWatch cross-account observability / dashboards, rather than every agent writing directly into one account. Cleaner blast radius and IAM.

---

## Reviewer checklist

- [ ] No secrets in `git ls-files`  
- [ ] Execution role has no Admin policy  
- [ ] Trust principals are explicit  
- [ ] SSM used for enrollment; SSH only as documented fallback  
