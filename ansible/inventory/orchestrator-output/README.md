# Orchestrator output (Ansible inventory files)

This folder is filled automatically by:

```bash
PYTHONPATH=. python3 -m orchestrator ...
```

## Files you will see

| Suffix | Purpose |
|--------|---------|
| `.ini` | Ansible inventory (use this with `ansible-playbook -i …`) |
| `.yaml` | Normalized host list (human / multi-cloud friendly) |
| `.json` | Machine-readable summary for CI |

Generated files are **gitignored**. Only this README is committed.

## Next command after generation

```bash
cd ansible
ansible-playbook -i inventory/orchestrator-output/<file>.ini playbooks/enroll-disk-monitoring.yml -v
```

See also: [HOW-TO-CHOOSE-INVENTORY.md](../HOW-TO-CHOOSE-INVENTORY.md)
