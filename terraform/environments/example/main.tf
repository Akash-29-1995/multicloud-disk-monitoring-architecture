terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  tags = {
    Project   = "lucidity-disk-monitoring"
    ManagedBy = "terraform"
    Purpose   = "disk-utilization-monitoring"
  }

  dashboard_body = templatefile("${path.module}/../../../cloudwatch/dashboard.json", {
    region    = var.aws_region
    namespace = var.metric_namespace
  })
}

# Who may assume the execution role? In single-account MVP: the caller identity.
data "aws_caller_identity" "current" {}

locals {
  trusted_principals = length(var.trusted_principal_arns) > 0 ? var.trusted_principal_arns : [
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
  ]
}

module "monitoring_role" {
  source = "../../modules/monitoring-role"

  role_name               = var.execution_role_name
  trusted_principal_arns  = local.trusted_principals
  external_id             = var.external_id
  enable_ssm_send_command = true
  tags                    = local.tags
}

module "cloudwatch" {
  source = "../../modules/cloudwatch"

  dashboard_name             = var.dashboard_name
  dashboard_body             = local.dashboard_body
  sns_topic_name             = var.sns_topic_name
  alarm_email                = var.alarm_email
  warning_threshold_percent  = var.warning_threshold_percent
  critical_threshold_percent = var.critical_threshold_percent
  min_free_bytes             = var.min_free_bytes
  metric_namespace           = var.metric_namespace
  create_example_alarms      = var.create_example_alarms
  example_instance_id        = var.example_instance_id
  example_fstype             = var.example_fstype
  example_path               = var.example_path
  tags                       = local.tags
}

module "monitoring_account" {
  source = "../../modules/monitoring-account"

  workload_role_arns = [module.monitoring_role.role_arn]
  tags               = local.tags
}

output "execution_role_arn" {
  description = "Use this ARN in Ansible / accounts.yaml"
  value       = module.monitoring_role.role_arn
}

output "instance_profile_name" {
  description = "Attach this instance profile to EC2 VMs you want to monitor"
  value       = module.monitoring_role.instance_profile_name
}

output "instance_profile_arn" {
  value = module.monitoring_role.instance_profile_arn
}

output "dashboard_name" {
  value = module.cloudwatch.dashboard_name
}

output "sns_topic_arn" {
  value = module.cloudwatch.sns_topic_arn
}

output "account_id" {
  value = module.monitoring_role.account_id
}

output "next_steps" {
  value = <<-EOT
    1. Attach instance profile '${module.monitoring_role.instance_profile_name}' to your Linux EC2.
    2. Tag instance: Monitoring=enabled, MonitoringProfile=standard, Environment=production
    3. Confirm SSM: aws ssm describe-instance-information --filters Key=InstanceIds,Values=<id>
    4. Wait 30–60s if you just created IAM, then run Ansible enroll.
    5. Confirm SNS email if you set alarm_email.
    See docs/02-single-account-onboarding.md
  EOT
}
