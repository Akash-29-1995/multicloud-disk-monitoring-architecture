# Role: cloudwatch_agent

Idempotent enrollment of the **Amazon CloudWatch Agent** for disk utilization metrics.

## What this role does

1. Installs the agent (RPM/DEB) with retries if the package is missing  
2. Renders disk metric config (`disk_used_percent`, `disk_free`)  
3. Starts/enables the service and waits until it is `active`  
4. Asserts config contents (output-based validation)

## What this role does NOT do

- Continuously poll `df -h` via Ansible  
- Replace CloudWatch as the telemetry pipeline  

## Auto-heal

Re-run the enroll playbook anytime. All tasks are idempotent. Transient download/service failures use `retries` + `delay` + `until`.

## Windows

Not in MVP. Future: use the Windows CloudWatch Agent MSI + WinRM/SSM documents with the same tag enrollment contract.

## Variables

See `defaults/main.yml` and `group_vars/all.yml.example`.
