# 02 — Single-account onboarding (MVP)

Follow every step in order. Do not skip. After important commands you will see **Expected** output.

Time: about 30–45 minutes if prerequisites are done.

---

## Step 0 — Open a terminal in this repo

```bash
cd /path/to/lucidity-disk-monitoring
pwd
```

**Expected:** path ends with the repo name.

Read [00-glossary.md](00-glossary.md) if any word is unclear.

---

## Step 1 — Static check (no AWS required)

```bash
./scripts/validate.sh
```

**Expected:** ends with `FAIL=0` (WARN is OK if terraform/ansible are not installed yet).

**Bad:** `FAIL` on missing files → you are in the wrong folder or the clone is incomplete.

---

## Step 2 — Create Terraform variables file

```bash
cd terraform/environments/single-account-mvp
cp terraform.tfvars.template terraform.tfvars
```

Edit `terraform.tfvars` with a text editor:

1. Set `aws_region` to your region (example: `us-east-1`)
2. Set `alarm_email` to **your** email
3. Leave `monitored_instance_id = ""` for the first apply

**Security:** `terraform.tfvars` is gitignored. Never commit it.

---

## Step 3 — Apply Terraform (creates roles, dashboard, SNS)

```bash
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

**Expected (good):** `Apply complete!` and outputs including:

```text
execution_role_arn = "arn:aws:iam::123456789012:role/DiskMonitoringExecutionRole"
instance_profile_name = "DiskMonitoringInstanceProfile"
dashboard_name = "lucidity-disk-monitoring"
```

Copy these values to a notepad.

**Wait 30–60 seconds** after apply so IAM is ready (IAM is eventually consistent).

---

## Step 4 — Confirm SNS email

Check your inbox for AWS SNS confirmation. Click **Confirm subscription**.

**Expected:** browser page says subscription confirmed.

Without this, alarms will not email you (dashboard still works).

---

## Step 5 — Attach instance profile to your EC2

Replace `i-YOUR_ID` and use the profile name from Terraform output.

```bash
aws ec2 associate-iam-instance-profile \
  --instance-id i-YOUR_ID \
  --iam-instance-profile Name=DiskMonitoringInstanceProfile
```

If a profile is already attached, replace it in the EC2 console: Instance → Actions → Security → Modify IAM role.

**Wait ~1–2 minutes**, then:

```bash
aws ssm describe-instance-information \
  --filters "Key=InstanceIds,Values=i-YOUR_ID" \
  --query 'InstanceInformationList[0].PingStatus' \
  --output text
```

**Expected:** `Online`

---

## Step 6 — Tag the instance (enrollment contract)

```bash
aws ec2 create-tags --resources i-YOUR_ID --tags \
  Key=Monitoring,Value=enabled \
  Key=MonitoringProfile,Value=standard \
  Key=Environment,Value=production \
  Key=Customer,Value=demo
```

**Verify**

```bash
aws ec2 describe-tags --filters "Name=resource-id,Values=i-YOUR_ID"
```

**Expected:** you see the four tags above (`Monitoring`, `MonitoringProfile`, `Environment`, `Customer`).

---

## Step 7 — Configure Ansible variables

```bash
cd ../../../ansible
cp group_vars/all.yml.template group_vars/all.yml
```

Edit `group_vars/all.yml`:

- Set `aws_region` to your region
- Add (required for SSM connection):

```yaml
ansible_aws_ssm_bucket_name: "lucidity-ansible-ssm-YOUR_ACCOUNT_YOUR_REGION"
```

Use the bucket you created in [01-prerequisites.md](01-prerequisites.md).

Edit `inventory/aws_ec2.yml` and set `regions:` to your region if not `us-east-1`.

---

## Step 8 — See what inventory discovers

```bash
ansible-inventory -i inventory/aws_ec2.yml --graph
```

**Expected:** a host that looks like your instance id (`i-...`) under `all`.

**Bad:** empty inventory → tags wrong, region wrong, or AWS credentials wrong.

---

## Step 9 — Enroll (install + configure CloudWatch Agent)

```bash
ansible-playbook playbooks/enroll-disk-monitoring.yml -v
```

Watch for lines:

```text
[PASS] SSM connectivity OK
[PASS] CloudWatch Agent service is active
[PASS] Agent config includes disk_used_percent, disk_free, and namespace
```

**If a task fails:** the playbook retries automatically several times. If it still fails, open [05-troubleshooting.md](05-troubleshooting.md). Logs are in `ansible/logs/ansible.log`.

---

## Step 10 — Host-level validation

```bash
ansible-playbook playbooks/validate-agent-on-host.yml -v
```

**Expected:** all `[PASS]` asserts.

---

## Step 11 — CloudWatch metric validation (wait + poll)

```bash
cd ..
./scripts/validate-cloudwatch-metrics.sh --instance-id i-YOUR_ID --region us-east-1
```

This script **waits and retries** for up to 5 minutes until a datapoint exists.

**Expected:**

```text
[PASS] Found ... disk_used_percent metric stream(s)
[PASS] Datapoint received — latest disk_used_percent Average ≈ NN%
[PASS] End-to-end disk monitoring path is working
```

---

## Step 12 — Create alarms for your instance (second Terraform apply)

```bash
cd terraform/environments/single-account-mvp
```

Edit `terraform.tfvars`:

```hcl
monitored_instance_id = "i-YOUR_ID"
disk_filesystem_type      = "xfs"   # use "ext4" on many Ubuntu images
```

```bash
terraform apply
```

**Expected:** alarms created for warning (80%), critical (90%), free-space floor, and agent-missing.

---

## Step 13 — Open the dashboard

AWS Console → CloudWatch → Dashboards → `lucidity-disk-monitoring`

**Expected:** widgets showing disk used % and free space for your instance (may take a few minutes to populate).

---

## You are done with single-account MVP when

- [ ] Terraform applied  
- [ ] Instance tagged + SSM Online  
- [ ] `enroll-disk-monitoring.yml` shows PASS  
- [ ] `validate-cloudwatch-metrics.sh` shows PASS with a % value  
- [ ] Dashboard visible  
- [ ] Alarms exist  

**Auto-heal reminder:** if the agent-missing alarm fires later, re-run:

```bash
cd ansible && ansible-playbook playbooks/reconcile-agent-config.yml
```

Next (multiple AWS accounts): [03-multi-account-onboarding.md](03-multi-account-onboarding.md)
