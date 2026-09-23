# 04 — Validation checklist (output-based)

Tick each box only when you see the **Expected** output.  
“Command succeeded” without checking output is **not** enough.

---

## A. Static (no AWS)

```bash
./scripts/validate.sh
```

- [ ] Expected: `FAIL=0`

---

## B. Identity

```bash
aws sts get-caller-identity
```

- [ ] Expected: JSON with `Account` and `Arn`

---

## C. IAM role exists

```bash
aws iam get-role --role-name DiskMonitoringExecutionRole \
  --query 'Role.Arn' --output text
```

- [ ] Expected: `arn:aws:iam::ACCOUNT:role/DiskMonitoringExecutionRole`

Trust check:

```bash
aws iam get-role --role-name DiskMonitoringExecutionRole \
  --query 'Role.AssumeRolePolicyDocument' --output json
```

- [ ] Expected: `Principal.AWS` is your central ARN (or account root in MVP) — **not** `"*"`

---

## D. Instance profile + SSM

```bash
aws ssm describe-instance-information \
  --filters "Key=InstanceIds,Values=i-YOUR_ID" \
  --query 'InstanceInformationList[0].[PingStatus,IPAddress]' --output text
```

- [ ] Expected: first field `Online`

---

## E. Tags

```bash
aws ec2 describe-instances --instance-ids i-YOUR_ID \
  --query 'Reservations[0].Instances[0].Tags' --output table
```

- [ ] Expected: `Monitoring=enabled` present

---

## F. Ansible host validation

```bash
cd ansible
ansible-playbook playbooks/validate-enrollment.yml -v
```

- [ ] Expected lines include:
  - `[PASS] CloudWatch Agent package present`
  - `[PASS] Agent service active`
  - `[PASS] Config contains disk measurements`

---

## G. Live CloudWatch metrics (wait/retry)

```bash
./scripts/validate_live.sh --instance-id i-YOUR_ID --region YOUR_REGION
```

- [ ] Expected: `[PASS] End-to-end disk monitoring path is working` with a numeric %

---

## H. Dashboard + alarms

Console or CLI:

```bash
aws cloudwatch list-dashboards --query 'DashboardEntries[?DashboardName==`lucidity-disk-monitoring`]'
aws cloudwatch describe-alarms --alarm-name-prefix disk-
```

- [ ] Expected: dashboard listed; alarms for warning/critical/free/agent-missing (after second apply)

---

## I. Multi-account (only after doc 03)

```bash
aws sts assume-role \
  --role-arn arn:aws:iam::WORKLOAD:role/DiskMonitoringExecutionRole \
  --role-session-name validate \
  --external-id YOUR_EXTERNAL_ID
```

- [ ] Expected: temporary credentials JSON  
- [ ] Expected: `validate_live.sh` PASS for a VM **in the workload account**  
- [ ] Expected: `config/accounts.yaml` status `enrolled` (not blank / not silently missing)

---

## J. Auto-heal drill (optional but impressive)

1. Stop agent on a test VM: `sudo systemctl stop amazon-cloudwatch-agent`  
2. Wait until `disk-agent-missing-*` goes ALARM (or skip wait)  
3. Re-run: `ansible-playbook playbooks/configure-monitoring.yml`  
4. Re-run: `./scripts/validate_live.sh --instance-id i-YOUR_ID`  

- [ ] Expected: service active again + metrics resume  

This proves **idempotent reconcile + retries**, not a custom healing product.
