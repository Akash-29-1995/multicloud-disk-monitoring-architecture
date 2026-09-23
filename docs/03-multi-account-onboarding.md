# 03 — Multi-account onboarding

Complete [02-single-account-onboarding.md](02-single-account-onboarding.md) successfully **first**.  
This guide adds Account B, Account C, … without redesigning the architecture.

Plain idea:

```text
Central / management identity
        |
        |  STS AssumeRole (temporary)
        v
Workload account (B, C, …)
        |
        v
DiskMonitoringExecutionRole  +  tagged EC2  +  CloudWatch Agent
```

You will **never** copy long-lived access keys into this git repo.

---

## Words used here

| Word | Meaning |
|------|---------|
| **Central account** | Where operators run Ansible/Terraform dashboards (can be Account A from MVP) |
| **Workload account** | Account that owns EC2 VMs to monitor (B, C, …) |
| **Execution role** | `DiskMonitoringExecutionRole` in each workload account |

---

## Step 1 — Decide your account IDs

Write them down:

| Name | Account ID | Role |
|------|------------|------|
| Central (A) | `111111111111` | Management |
| Workload B | `222222222222` | Has EC2 |
| Workload C | `333333333333` | Has EC2 |

Replace with **your** real 12-digit IDs.

---

## Step 2 — Note the central principal ARN

In the **central** account, pick the IAM role or user that will run enrollment.

Example (role):

```text
arn:aws:iam::111111111111:role/LucidityMonitoringAdmin
```

**Verify in central account**

```bash
aws sts get-caller-identity
```

**Expected:** `Account` equals your central account id.

---

## Step 3 — (Recommended) Create a shared External ID

On your laptop:

```bash
openssl rand -hex 16
```

**Expected:** a long hex string. Save it in a password manager — **not in git**.

You will paste the same value into Terraform for every workload role trust policy.

---

## Step 4 — Deploy the execution role **inside Account B**

### 4a. Switch AWS credentials to Account B

Examples:

- `export AWS_PROFILE=workload-b` then `aws sso login --profile workload-b`
- or use a role switch in the AWS console / CLI

**Verify you are in B**

```bash
aws sts get-caller-identity --query Account --output text
```

**Expected:** `222222222222` (your B id), **not** the central id.

### 4b. Apply the workload-account Terraform environment in B

```bash
cd /path/to/lucidity-disk-monitoring/terraform/environments/workload-account
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
aws_region = "us-east-1"
trusted_principal_arns = [
  "arn:aws:iam::111111111111:role/LucidityMonitoringAdmin"
]
external_id = "PASTE_EXTERNAL_ID_HERE"
```

Apply **while AWS_PROFILE points at Account B**:

```bash
export AWS_PROFILE=workload-b
terraform init
terraform apply
```

**Expected output:**

```text
execution_role_arn = "arn:aws:iam::222222222222:role/DiskMonitoringExecutionRole"
instance_profile_name = "DiskMonitoringInstanceProfile"
```

### 4c. Wait 30–60 seconds

IAM propagation delay. Do not skip.

---

## Step 5 — Test AssumeRole from central → B

Switch back to **central** credentials:

```bash
export AWS_PROFILE=central
aws sts assume-role \
  --role-arn arn:aws:iam::222222222222:role/DiskMonitoringExecutionRole \
  --role-session-name lucidity-test \
  --external-id PASTE_EXTERNAL_ID_HERE
```

**Expected (good):** JSON with `Credentials.AccessKeyId`, `SecretAccessKey`, `SessionToken`.

**Bad:** `AccessDenied` → trust policy principal wrong, or ExternalId mismatch, or wrong account. Mark account status `non_compliant` in `config/accounts.yaml` and fix — do **not** silently ignore.

---

## Step 6 — Register Account B in config

```bash
cd /path/to/lucidity-disk-monitoring
cp config/accounts.yaml.example config/accounts.yaml
```

Edit:

```yaml
accounts:
  - name: central-a
    account_id: "111111111111"
    role_arn: "arn:aws:iam::111111111111:role/DiskMonitoringExecutionRole"
    region: us-east-1
    status: enrolled

  - name: workload-b
    account_id: "222222222222"
    role_arn: "arn:aws:iam::222222222222:role/DiskMonitoringExecutionRole"
    region: us-east-1
    external_id: "PASTE_EXTERNAL_ID_HERE"
    status: enrolled
```

---

## Step 7 — Prepare VMs in Account B

With **Account B** credentials:

1. Attach `DiskMonitoringInstanceProfile` to Linux EC2  
2. Tag: `Monitoring=enabled`, `MonitoringProfile=standard`, `Environment=production`  
3. Confirm SSM `Online`  

Same as single-account Steps 5–6 in doc 02.

---

## Step 8 — Enroll VMs in Account B

From central operator machine, assume role then run Ansible **or** use a profile that already targets B.

Example using temporary credentials from Step 5 (export the three keys from assume-role output), then:

```bash
cd ansible
# Ensure inventory region matches Account B region
ansible-inventory -i inventory/aws_ec2.yml --graph
ansible-playbook playbooks/enroll.yml -v
ansible-playbook playbooks/validate-enrollment.yml -v
```

Then:

```bash
../scripts/validate_live.sh --instance-id i-IN_ACCOUNT_B --region us-east-1 --profile central
```

(If metrics are in Account B, use B credentials / assumed-role session for `validate_live.sh`.)

**Expected:** `[PASS] End-to-end disk monitoring path is working`

---

## Step 9 — Wire central registry (optional but recommended)

With **central** credentials:

```bash
cd terraform/environments/multi-account-example
cp terraform.tfvars.example terraform.tfvars
```

Set:

```hcl
central_management_principal_arn = "arn:aws:iam::111111111111:role/LucidityMonitoringAdmin"
workload_role_arns = [
  "arn:aws:iam::222222222222:role/DiskMonitoringExecutionRole"
]
external_id = "PASTE_EXTERNAL_ID_HERE"
```

```bash
terraform init
terraform apply
```

**Expected:** SSM parameter `/lucidity/disk-monitoring/workload-role-arns` created (non-secret ARN list).

---

## Step 10 — Add Account C, D, … (repeatable)

For **each new account**:

1. Switch credentials to that account  
2. `terraform apply` monitoring-role with **same** central principal + ExternalId  
3. Wait 30–60s  
4. Test `sts assume-role` from central  
5. Attach instance profile + tags on VMs  
6. Append role ARN to `config/accounts.yaml` and `workload_role_arns`  
7. Enroll + `validate_live.sh`  
8. Set `status: enrolled` (or `non_compliant` if AssumeRole fails)

Adding Account #101 is this checklist — **not** a new architecture.

---

## Production evolution (read later)

| Today (MVP) | Tomorrow (scale) |
|-------------|------------------|
| Static `accounts.yaml` | AWS Organizations + EventBridge account-created events |
| Manual Terraform per account | Account baseline via StackSets / Control Tower customization (optional) |
| Ansible from laptop | AWX / Ansible Automation Platform with credential plugins |

Control Tower is **optional**. Organizations alone is enough.

---

## Done when

- [ ] AssumeRole from central → B works  
- [ ] At least one VM in B shows metrics  
- [ ] `accounts.yaml` lists B as `enrolled`  
- [ ] You can repeat the checklist for C without changing design  

Validation checklist: [04-validation-checklist.md](04-validation-checklist.md)
