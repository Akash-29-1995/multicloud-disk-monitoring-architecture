# 06 — Orchestrator dry-run (no AWS required)

The **orchestrator** is a small Python program that:

1. Reads customer / account / environment parameters  
2. Picks the cloud **adapter** (AWS today; GCP/Azure stubs later)  
3. Discovers VMs (or simulates them in dry-run)  
4. Writes a **normalized inventory** for Ansible  

Jenkins only calls this program. Jenkins does **not** contain AWS API code.

---

## Step 1 — Install Python deps

```bash
cd /path/to/lucidity-disk-monitoring
python3 -m pip install --user -r orchestrator/requirements.txt
```

**Expected:** install finishes without error.

---

## Step 2 — Run dry-run

```bash
PYTHONPATH=. python3 -m orchestrator \
  --cloud aws \
  --customer nike \
  --account 111111111111 \
  --environment prod \
  --region us-east-1 \
  --dry-run \
  --accounts-file config/customer-accounts.template.yaml
```

**Expected (good):**

```text
MODE: DRY RUN
[PASS] Parameters validated
[PASS] Registry match: nike-prod-a status=enrolled
[PASS] Discovered host_count=2
       - i-DRYRUN0000000001 ...
[PASS] Wrote Ansible inventory: .../inventory/orchestrator-output/nike_...ini
[INFO] DRY RUN complete
```

**Important:** `i-DRYRUN...` hosts are **simulated**. They are not real AWS instances.

**Bad:**

```text
[FAIL] Missing required parameter
```

→ Fix flags (`--customer`, `--environment`, etc.).

---

## Step 3 — Inspect generated inventory

```bash
ls ansible/inventory/orchestrator-output/
head -20 ansible/inventory/orchestrator-output/nike_111111111111_prod_us-east-1.ini
```

**Expected:** files `.yaml`, `.ini`, `.json` for your customer/account/env/region.

---

## Step 4 — Live mode (reviewers with AWS)

Remove `--dry-run`. Ensure AWS credentials can AssumeRole (or use same-account defaults).

```bash
PYTHONPATH=. python3 -m orchestrator \
  --cloud aws \
  --customer nike \
  --account YOUR_ACCOUNT_ID \
  --environment prod \
  --region us-east-1 \
  --accounts-file config/customer-accounts.yaml
```

**Expected banner:**

```text
MODE: LIVE AWS EXECUTION
```

Then enroll:

```bash
cd ansible
ansible-playbook -i inventory/orchestrator-output/<file>.ini playbooks/enroll-disk-monitoring.yml -v
```

---

## Words

| Word | Meaning |
|------|---------|
| Adapter | Code that talks to one cloud (AWS / GCP / Azure) |
| Normalized inventory | Same host list shape no matter which cloud |
| Dry-run | Practice mode — no live API mutations |

Next: [07-multi-customer-saas-model.md](07-multi-customer-saas-model.md)
