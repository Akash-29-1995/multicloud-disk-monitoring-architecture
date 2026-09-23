# 05 — Troubleshooting

Find your **symptom**, then apply the **fix**. Re-run the validation command after each fix.

---

## <a id="ssm"></a> SSM not Online / Ansible cannot connect

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `PingStatus` empty / `None` | No instance profile or wrong profile | Attach `DiskMonitoringInstanceProfile`; wait 2 minutes |
| PingStatus `ConnectionLost` | No path to SSM endpoints | Add NAT gateway **or** VPC interface endpoints for `ssm`, `ssmmessages`, `ec2messages` |
| Ansible `Failed to connect` | Missing S3 bucket for aws_ssm plugin | Set `ansible_aws_ssm_bucket_name` in `group_vars/all.yml` |
| Still failing | SSM Agent dead on OS | On console Session Manager / EC2 serial: start `amazon-ssm-agent` |

**Validate**

```bash
aws ssm describe-instance-information --filters "Key=InstanceIds,Values=i-YOUR_ID" \
  --query 'InstanceInformationList[0].PingStatus' --output text
```

Expected: `Online`

---

## Inventory empty (Ansible finds zero hosts)

| Cause | Fix |
|-------|-----|
| Missing tag `Monitoring=enabled` | Create tags (doc 02 Step 6) |
| Wrong region in `inventory/aws_ec2.yml` | Set your region |
| Instance not `running` | Start instance |
| Wrong AWS credentials/account | `aws sts get-caller-identity` |

**Validate:** `ansible-inventory -i inventory/aws_ec2.yml --graph` shows `i-...`

---

## <a id="metrics-missing"></a> Metrics missing in CloudWatch

| Cause | Fix |
|-------|-----|
| Agent not installed/running | `ansible-playbook playbooks/reconcile-agent-config.yml` |
| Instance profile missing `CloudWatchAgentServerPolicy` | Re-attach profile from Terraform |
| Wrong region in console | Open CloudWatch in the instance region |
| Need more time | Wait 2–3 minutes; `validate-cloudwatch-metrics.sh` already polls |
| fstype dimension mismatch on alarms | Set `disk_filesystem_type` to `ext4` or `xfs` to match agent |

**Validate:** `./scripts/validate-cloudwatch-metrics.sh --instance-id i-YOUR_ID`

---

## <a id="iam"></a> AssumeRole AccessDenied (multi-account)

| Cause | Fix |
|-------|-----|
| Trust principal ARN wrong | Must be central role/user ARN |
| ExternalId mismatch | Same string in workload trust and assume-role call |
| Applying Terraform in wrong account | `get-caller-identity` must match target account |
| IAM not propagated | Wait 60s and retry |

Mark account `non_compliant` in `config/customer-accounts.yaml` until fixed.

---

## Terraform errors

| Symptom | Fix |
|---------|-----|
| `No valid credential sources` | Configure AWS profile / SSO |
| `EntityAlreadyExists` | Role name collision — import or rename via variable |
| Dashboard JSON error | Run `./scripts/validate.sh`; ensure `cloudwatch/dashboard.json` intact |

---

## Ansible package download retries exhausted

Transient network issues are why we use `retries` + `delay`. If still failing:

- Ensure VM can reach `amazoncloudwatch-agent.s3.amazonaws.com`
- Check proxy/firewall
- Re-run enroll (idempotent)

Logs: `ansible/logs/ansible.log`

---

## Alarms never email

Confirm SNS subscription in your inbox. Without confirmation, no emails.

---

## Agent alarm fires often

That is intentional for **missing metrics**. Heal:

```bash
cd ansible && ansible-playbook playbooks/reconcile-agent-config.yml
```

Then re-validate with `validate-cloudwatch-metrics.sh`.
