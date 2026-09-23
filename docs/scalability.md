# Scalability model

## Same architecture at every scale

```text
2 accounts / 500 VMs
        │
        ▼
20 accounts / 2,000 VMs
        │
        ▼
100+ accounts / 5,000–10,000+ VMs
```

Growth is **discovery + enrollment**, not redesign.

## What scales how

| Concern | Mechanism |
|---------|-----------|
| More accounts | Repeat role deploy + `accounts.yaml` / Org + EventBridge (prod) |
| More VMs | Tag contract + dynamic inventory — no IP lists |
| Ansible blast radius | `forks`, `serial` batches, `max_fail_percentage`, retries |
| Telemetry volume | CloudWatch Agent push — Ansible not in the hot path |
| Operator toil | Idempotent reconcile; AWX/AAP later for scheduling |

## Ansible at thousands of hosts

Do **not** run one unbounded play against 5,000 hosts.

This repo defaults:

- `forks = 25` (`ansible.cfg`)  
- `serial_batch_size = 50`  
- retries/delay on install and service waits  
- Idempotent role → safe re-runs for failed batches  

Production evolution: **Ansible Automation Platform / AWX** with credential plugins for AssumeRole, job templates per account OU, and rate limits.

## CloudWatch

- Metrics are per-instance with dimensions (path, fstype)  
- Alarms should be automated per instance (Terraform loop / metric math / CW Observability) as fleet grows — MVP creates alarms for an example instance; pattern is identical for N  
- Cross-account dashboards: CloudWatch cross-account observability (org) when ready  

## Honesty

This design is **architected** for 5,000+ VMs. It has **not** been load-tested at that scale by the author (no personal AWS). Reviewers should judge the control/data plane split and batching model.
