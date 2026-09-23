# Design decisions & trade-offs

## Why CloudWatch Agent instead of Ansible polling?

Continuous telemetry must not depend on configuration-management execution. Ansible/Jenkins down ≠ monitoring down.

## Why SSM instead of SSH?

- No inbound SSH  
- No long-lived key distribution  
- IAM-authorized, CloudTrail-audited  
- Works with private subnets + VPC endpoints  

SSH remains a **documented fallback** (bastion, no public :22) — see [security.md](security.md).

## Why a Python orchestrator (not only Ansible dynamic inventory)?

`amazon.aws.aws_ec2` is excellent for AWS-only MVP.

The orchestrator adds value the inventory plugin alone does not:

- Multi-customer / environment parameters  
- Account registry + AssumeRole orchestration  
- Normalized inventory for future GCP/Azure adapters  
- Validation + dry-run without AWS  
- One Jenkins job for all customers  

It does **not** duplicate Ansible’s job: Ansible still enrolls the agent.

## Why Jenkins is thin?

Cloud API logic in Groovy becomes untestable and credential-hostile. Jenkins passes parameters → `python -m orchestrator`.

## Why dynamic / normalized inventory?

Static IP lists do not survive 5,000 VMs or autoscaling. Tags are the enrollment contract.

## Why cross-account IAM (AssumeRole)?

Controlled, temporary access without permanent credentials in every customer account.

## Why CloudWatch?

AWS-native metrics, dashboards, alarms — substantial benefit before buying a third-party monitoring SaaS.

## Why Terraform if we already use Ansible?

| Tool | Best at |
|------|---------|
| Terraform | Declarative IAM, SNS, dashboards, role baselines |
| Orchestrator | Customer/account discovery + normalized inventory |
| Ansible | OS package/config on VMs |
| CloudWatch | Continuous metrics & alerting |

## Why EventBridge (production)?

Event-driven account/VM onboarding. MVP: scheduled/manual orchestrator + `accounts.yaml`.

## Why Control Tower is optional?

Works with Organizations alone; CT enhances baselines if already present.

## Multi-cloud

```text
AWS adapter (implemented)   GCP stub   Azure stub
            \                  |           /
             v                 v          v
              Normalized inventory → Ansible → agent → native metrics
```

MVP implements **AWS** only. Stubs prove the extension point without over-building.
