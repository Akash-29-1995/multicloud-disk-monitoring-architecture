# How to choose an Ansible inventory

This folder has **two valid paths**. Pick one based on your goal.

## Path 1 — Direct AWS discovery (simple single-account review)

**File:** [`aws_ec2.yml`](aws_ec2.yml)

- Ansible talks to the AWS EC2 API itself
- Finds instances tagged `Monitoring=enabled`
- Best for: first-time reviewers proving the MVP on one account

```bash
cd ansible
ansible-playbook -i inventory/aws_ec2.yml playbooks/enroll-disk-monitoring.yml -v
```

## Path 2 — Orchestrator-built inventory (multi-customer SaaS)

**Folder:** [`orchestrator-output/`](orchestrator-output/)

1. Run the Python orchestrator (dry-run or live)
2. It writes `.ini` / `.yaml` / `.json` files here
3. Point Ansible at the generated `.ini` file

```bash
PYTHONPATH=. python3 -m orchestrator \
  --cloud aws --customer nike --account 111111111111 \
  --environment prod --region us-east-1 --dry-run \
  --accounts-file config/customer-accounts.template.yaml

cd ansible
ansible-playbook -i inventory/orchestrator-output/<generated-file>.ini playbooks/enroll-disk-monitoring.yml -v
```

## Rule of thumb

| Situation | Use |
|-----------|-----|
| Learning / one AWS account | `aws_ec2.yml` |
| Many customers / accounts / Jenkins | Orchestrator → `orchestrator-output/` |
