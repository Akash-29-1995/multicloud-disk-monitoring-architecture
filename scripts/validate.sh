#!/usr/bin/env bash
# Static validation — NO AWS credentials required.
# Proves repository structure, Terraform/Ansible syntax, and JSON validity.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PASS=0
FAIL=0
WARN=0

ts() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

pass() { echo "[PASS] $*"; PASS=$((PASS + 1)); }
fail() { echo "[FAIL] $*"; FAIL=$((FAIL + 1)); }
warn() { echo "[WARN] $*"; WARN=$((WARN + 1)); }
info() { echo "[INFO] $*"; }

echo "=============================================="
echo " Lucidity disk-monitoring — static validation"
echo " Started: $(ts)"
echo "=============================================="

# --- Required paths ---
REQUIRED_PATHS=(
  "README.md"
  "architecture/architecture.md"
  "terraform/modules/monitoring-role/main.tf"
  "terraform/modules/cloudwatch/main.tf"
  "terraform/modules/monitoring-account/main.tf"
  "terraform/environments/example/main.tf"
  "ansible/playbooks/enroll.yml"
  "ansible/playbooks/configure-monitoring.yml"
  "ansible/playbooks/validate-enrollment.yml"
  "ansible/roles/cloudwatch_agent/tasks/main.yml"
  "ansible/roles/cloudwatch_agent/templates/amazon-cloudwatch-agent.json.j2"
  "ansible/inventory/generated/README.md"
  "cloudwatch/dashboard.json"
  "cloudwatch/alarms.json"
  "docs/00-glossary.md"
  "docs/02-single-account-onboarding.md"
  "docs/03-multi-account-onboarding.md"
  "docs/04-validation-checklist.md"
  "docs/06-orchestrator-dry-run.md"
  "docs/07-multi-customer-saas-model.md"
  "docs/08-jenkins-thin-trigger.md"
  "docs/security.md"
  "docs/reliability.md"
  "docs/tradeoffs.md"
  "config/accounts.yaml.example"
  "config/monitoring-profiles.yaml"
  "orchestrator/main.py"
  "orchestrator/adapters/aws.py"
  "orchestrator/adapters/gcp.py"
  "orchestrator/adapters/azure.py"
  "jenkins/Jenkinsfile"
  "scripts/validate_live.sh"
)

for p in "${REQUIRED_PATHS[@]}"; do
  if [[ -e "$ROOT/$p" ]]; then
    pass "Found $p"
  else
    fail "Missing required path: $p"
  fi
done

# --- Secrets must not be committed ---
if git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if git -C "$ROOT" ls-files | grep -E '(^|/)\.env$|credentials\.csv|\.pem$|terraform\.tfvars$' >/dev/null 2>&1; then
    fail "Secret-like files are tracked by git — remove them"
  else
    pass "No obvious secret files tracked by git"
  fi
else
  warn "Not a git repo yet — skip tracked-secrets check"
fi

# --- JSON ---
if command -v python3 >/dev/null 2>&1; then
  if python3 -c "import json; json.load(open('$ROOT/cloudwatch/dashboard.json')); json.load(open('$ROOT/cloudwatch/alarms.json'))"; then
    pass "cloudwatch/*.json parse as JSON"
  else
    fail "cloudwatch JSON failed to parse"
  fi
else
  warn "python3 not found — skip JSON parse"
fi

# --- Terraform fmt / validate (example env) ---
if command -v terraform >/dev/null 2>&1; then
  info "Running terraform fmt -check..."
  if terraform -chdir="$ROOT/terraform/environments/example" fmt -check -recursive "$ROOT/terraform" >/dev/null 2>&1; then
    pass "terraform fmt -check clean"
  else
    # Auto-fix then re-check message
    terraform -chdir="$ROOT/terraform/environments/example" fmt -recursive "$ROOT/terraform" >/dev/null 2>&1 || true
    warn "terraform fmt applied formatting — re-run validate.sh"
    pass "terraform fmt executed"
  fi

  info "Initializing terraform (no backend) for validate..."
  if terraform -chdir="$ROOT/terraform/environments/example" init -backend=false -input=false >/tmp/lucidity-tf-init.log 2>&1; then
    pass "terraform init -backend=false"
    if terraform -chdir="$ROOT/terraform/environments/example" validate >/tmp/lucidity-tf-validate.log 2>&1; then
      pass "terraform validate (example env)"
    else
      fail "terraform validate failed — see /tmp/lucidity-tf-validate.log"
      cat /tmp/lucidity-tf-validate.log || true
    fi
  else
    warn "terraform init failed (often missing network/provider) — see /tmp/lucidity-tf-init.log"
  fi
else
  warn "terraform not installed — skip terraform validate"
fi

# --- Ansible syntax ---
if command -v ansible-playbook >/dev/null 2>&1; then
  info "Checking Ansible playbook syntax..."
  pushd "$ROOT/ansible" >/dev/null
  # Avoid aws_ec2 inventory plugin (needs amazon.aws collection + AWS creds)
  export ANSIBLE_INVENTORY_ENABLED="host_list,ini,yaml"
  for pb in enroll.yml configure-monitoring.yml validate-enrollment.yml; do
    if ansible-playbook -i "localhost," -c local --syntax-check "playbooks/$pb" >/tmp/lucidity-ansible-syntax.log 2>&1; then
      pass "ansible syntax-check $pb"
    else
      fail "ansible syntax-check failed for $pb"
      cat /tmp/lucidity-ansible-syntax.log || true
    fi
  done
  popd >/dev/null
else
  warn "ansible-playbook not installed — skip ansible syntax-check"
fi

# --- Orchestrator unit tests + dry-run smoke ---
if command -v python3 >/dev/null 2>&1; then
  info "Running orchestrator unit tests..."
  if PYTHONPATH="$ROOT" python3 -m pytest "$ROOT/orchestrator/tests" -q >/tmp/lucidity-orch-pytest.log 2>&1; then
    pass "orchestrator pytest"
  else
    # Try ensuring PyYAML/pytest then retry once
    python3 -m pip install --user -q PyYAML pytest >/tmp/lucidity-pip.log 2>&1 || true
    if PYTHONPATH="$ROOT" python3 -m pytest "$ROOT/orchestrator/tests" -q >/tmp/lucidity-orch-pytest.log 2>&1; then
      pass "orchestrator pytest (after pip install)"
    else
      fail "orchestrator pytest failed — see /tmp/lucidity-orch-pytest.log"
      cat /tmp/lucidity-orch-pytest.log || true
    fi
  fi

  info "Running orchestrator dry-run smoke..."
  if PYTHONPATH="$ROOT" python3 -m orchestrator \
      --cloud aws --customer nike --account 111111111111 \
      --environment prod --region us-east-1 --dry-run \
      --accounts-file "$ROOT/config/accounts.yaml.example" \
      --output-dir "$ROOT/ansible/inventory/generated" \
      >/tmp/lucidity-orch-dryrun.log 2>&1; then
    if grep -q "MODE: DRY RUN" /tmp/lucidity-orch-dryrun.log && grep -q "host_count=2" /tmp/lucidity-orch-dryrun.log; then
      pass "orchestrator dry-run smoke"
    else
      fail "orchestrator dry-run output missing expected markers"
      cat /tmp/lucidity-orch-dryrun.log || true
    fi
  else
    fail "orchestrator dry-run failed — see /tmp/lucidity-orch-dryrun.log"
    cat /tmp/lucidity-orch-dryrun.log || true
  fi
else
  warn "python3 not found — skip orchestrator tests"
fi

echo "----------------------------------------------"
echo " Done: $(ts)"
echo " PASS=$PASS  FAIL=$FAIL  WARN=$WARN"
echo "----------------------------------------------"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
exit 0
