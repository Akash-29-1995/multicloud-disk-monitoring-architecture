# 07 — Multi-customer SaaS model (plain language)

Lucidity is a SaaS / platform company. One automation must serve many customers without writing a new Jenkins job per customer.

## Example

```text
Customer Nike
  AWS Account A (prod)
  AWS Account B (prod)
  AWS Account C (dev)

Customer Adidas
  GCP Project A   ← extension point later

Customer X
  Azure Subscription A  ← extension point later
```

## One pipeline, many parameters

```text
CLOUD_PROVIDER = aws
CUSTOMER_ID    = nike
ENVIRONMENT    = prod
ACCOUNT_ID     = 123456789012
REGION         = us-east-1
MONITORING_PROFILE = standard
ACTION         = enroll
```

The orchestrator uses these to choose the adapter, AssumeRole target, filters, and inventory.

**You do NOT create** `jenkins-nike-prod` and `jenkins-adidas-dev` as separate codebases.

## Tag contract (enrollment)

| Tag | Example | Meaning |
|-----|---------|---------|
| `Monitoring` | `enabled` | Include in discovery (opt-in) |
| `MonitoringProfile` | `standard` | Threshold profile |
| `Environment` | `prod` | Filter by env |
| `Customer` | `nike` | Filter by customer |

### Missing-tag governance (chosen model)

**Opt-in:** only instances with `Monitoring=enabled` are enrolled.

Why: safest default for multi-tenant SaaS (never monitor a customer VM by accident).

Production hardening (document, not required for MVP):

- AWS Organizations tag policies requiring the tag on EC2  
- IaC modules that always set tags  
- Periodic reconcile job listing untagged candidates  

Alternative “default = monitored / explicit exemption” is valid for single-enterprise IT — we chose **opt-in** for Lucidity SaaS.

## Account registry

See `config/accounts.yaml.example`. Copy to `config/accounts.yaml`.

Statuses:

| Status | Meaning |
|--------|---------|
| `enrolled` | Ready for discovery |
| `onboarding` | Role not finished |
| `non_compliant` | AssumeRole/IAM broken — **do not silently skip** |

## Multi-cloud

| Provider | Status in this repo |
|----------|---------------------|
| AWS | Fully implemented adapter |
| GCP | Stub interface (`NotImplementedError`) |
| Azure | Stub interface (`NotImplementedError`) |

Conceptual shared model:

```text
Customer → Account/Project/Subscription → Discover VMs → Enroll agent → Metrics → Central view
```

## Adding Customer #N or Account #101

1. Deploy monitoring role in the new account (Terraform workload-account)  
2. Add a row to `accounts.yaml`  
3. Tag VMs  
4. Run the **same** orchestrator / Jenkins job with new parameters  

No new architecture. No new playbook tree per customer.

Next: [08-jenkins-thin-trigger.md](08-jenkins-thin-trigger.md)
