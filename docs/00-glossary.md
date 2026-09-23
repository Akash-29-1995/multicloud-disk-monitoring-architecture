# Glossary (plain language)

Read this once before onboarding. Words below are used everywhere in this repo.

| Term | Meaning |
|------|---------|
| **AWS account** | A billing/security boundary with its own ID (12 digits), users, and resources. |
| **Region** | A geographic AWS area (example: `us-east-1`). Resources live in a region. |
| **EC2 instance** | A virtual machine (VM) in AWS. |
| **Tag** | A label on a resource, like `Monitoring=enabled`. We use tags to decide which VMs to monitor. |
| **IAM role** | A set of permissions a person or service can temporarily use. Not a long-lived password. |
| **AssumeRole (STS)** | “Borrow” a role in another account for a short time. No permanent keys copied around. |
| **SSM (Systems Manager)** | AWS way to manage VMs **without SSH**. Your laptop talks to AWS; AWS talks to the VM. |
| **CloudWatch** | AWS metrics, dashboards, and alarms service. |
| **CloudWatch Agent** | Small program on the VM that sends disk metrics to CloudWatch continuously. |
| **Ansible** | Tool that configures VMs (install agent, write config). It is **not** the continuous monitor. |
| **Terraform** | Tool that creates AWS resources (roles, alarms, dashboards) from code files. |
| **Enrollment** | Making a VM monitored: discover it → install/configure agent → validate metrics. |
| **Idempotent** | Safe to run again. Second run fixes drift; it does not break a healthy system. |
| **External ID** | Optional shared secret string used with AssumeRole to harden cross-account trust. |
| **MVP** | Minimum path that proves the design works (usually **one** AWS account first). |
| **Orchestrator** | Python program that picks a cloud adapter, discovers VMs, writes inventory for Ansible. |
| **Adapter** | Cloud-specific code (AWS implemented; GCP/Azure stubs). |
| **Normalized inventory** | Common host list format so Ansible does not care which cloud produced it. |
| **Jenkins** | Optional CI button that only passes parameters into the orchestrator. |
| **Customer** | SaaS tenant (e.g. nike) — many AWS accounts can belong to one customer. |

## The one sentence to remember

> **Ansible sets up monitoring. CloudWatch does the monitoring. Jenkins/Orchestrator only trigger setup.**
