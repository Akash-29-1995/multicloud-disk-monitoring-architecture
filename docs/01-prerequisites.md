# 01 — Prerequisites

Install these tools on the computer you will use to onboard (your laptop or a bastion). After each install, run the **Verify** command. You must see output similar to the **Expected** sample.

## 1. AWS account access

You need an AWS account where you can create IAM roles, EC2, and CloudWatch resources.

**Verify**

```bash
aws sts get-caller-identity
```

**Expected (good)**

```text
{
    "UserId": "AIDA...",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/you"
}
```

**Bad**

```text
Unable to locate credentials
```

→ Fix: run `aws configure` or `aws sso login`, then retry.

## 2. Terraform (≥ 1.5)

**Verify**

```bash
terraform version
```

**Expected:** `Terraform v1.5` or newer.

## 3. Ansible (≥ 2.14) + collections

```bash
python3 -m pip install --user ansible
cd ansible
ansible-galaxy collection install -r requirements.yml
```

**Verify**

```bash
ansible --version
ansible-galaxy collection list | grep amazon.aws
```

**Expected:** Ansible version printed; `amazon.aws` listed.

## 4. AWS CLI v2

**Verify:** `aws --version` shows `aws-cli/2...`

## 5. One Linux EC2 instance (for single-account path)

Before Ansible enrollment:

| Requirement | Why |
|-------------|-----|
| Linux (Amazon Linux 2/2023 or Ubuntu) | MVP is Linux-only |
| SSM Agent running | Ansible connects via SSM, not SSH |
| Instance profile with `AmazonSSMManagedInstanceCore` + `CloudWatchAgentServerPolicy` | Terraform creates `DiskMonitoringInstanceProfile` for you |
| Outbound path to SSM + CloudWatch (NAT or VPC endpoints) | Private subnet without endpoints = SSM offline |
| Tags: `Monitoring=enabled`, `MonitoringProfile=standard`, `Environment=production` | Dynamic inventory finds the VM |

**Verify SSM**

```bash
aws ssm describe-instance-information \
  --filters "Key=InstanceIds,Values=i-YOUR_ID" \
  --query 'InstanceInformationList[0].PingStatus' \
  --output text
```

**Expected:** `Online`

**Bad:** `None` or empty → see [05-troubleshooting.md](05-troubleshooting.md#ssm)

## 6. S3 bucket for Ansible SSM file transfer (small)

The `aws_ssm` connection plugin needs an S3 bucket in the same account/region.

```bash
aws s3 mb s3://lucidity-ansible-ssm-$(aws sts get-caller-identity --query Account --output text)-$(aws configure get region) 
```

Save the bucket name; you will set `ansible_aws_ssm_bucket_name` later.

## 7. Optional but recommended

| Tool | Use |
|------|-----|
| `jq` | Pretty JSON |
| Git | Clone / push this repo |

## Checklist before continuing

- [ ] `aws sts get-caller-identity` works  
- [ ] `terraform version` ≥ 1.5  
- [ ] `ansible --version` works + `amazon.aws` installed  
- [ ] EC2 exists, SSM `Online`, tags set  
- [ ] S3 bucket for SSM plugin created  

Next: [02-single-account-onboarding.md](02-single-account-onboarding.md)
