# Central monitoring account glue — cross-account visibility pattern
#
# In MVP (single account), this module is optional / no-op heavy.
# In multi-account, deploy monitoring-role in each workload account,
# then list those role ARNs here for operators and automation.

variable "workload_role_arns" {
  description = "List of DiskMonitoringExecutionRole ARNs in workload accounts"
  type        = list(string)
  default     = []
}

variable "central_dashboard_name" {
  type    = string
  default = "lucidity-disk-monitoring-central"
}

variable "tags" {
  type    = map(string)
  default = {}
}

# SSM Parameter as a discoverable, non-secret registry of workload roles
# (ARNs are not secrets; this avoids hardcoding in Ansible git)
resource "aws_ssm_parameter" "workload_roles" {
  count       = length(var.workload_role_arns) > 0 ? 1 : 0
  name        = "/lucidity/disk-monitoring/workload-role-arns"
  description = "Cross-account DiskMonitoringExecutionRole ARNs for enrollment"
  type        = "StringList"
  value       = join(",", var.workload_role_arns)
  tags        = var.tags
}

output "workload_role_arns" {
  value = var.workload_role_arns
}

output "workload_roles_parameter_name" {
  value = try(aws_ssm_parameter.workload_roles[0].name, null)
}

output "onboarding_instructions" {
  value = <<-EOT
    Multi-account onboarding:
    1. In each workload account, apply terraform/modules/monitoring-role with
       trusted_principal_arns = [central management role/user ARN].
    2. Append the new role ARN to workload_role_arns and re-apply this module.
    3. Wait 30–60 seconds for IAM propagation.
    4. Update config/accounts.yaml and run Ansible enroll.
    See docs/03-multi-account-onboarding.md.
  EOT
}
