# Multi-account EXAMPLE environment
#
# Beginners: finish docs/02 (single account) and docs/03 before this.
# Preferred beginner path for workload roles: apply environments/single-account-mvp
# with trusted_principal_arns = [central principal] while using workload credentials.
#
# This environment wires the CENTRAL side: dashboard + workload role ARN registry.

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

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "central_management_principal_arn" {
  description = "IAM role/user in the CENTRAL account (documentation / tagging reference)"
  type        = string
}

variable "external_id" {
  type      = string
  default   = ""
  sensitive = true
}

variable "workload_role_arns" {
  description = "DiskMonitoringExecutionRole ARNs from each workload account"
  type        = list(string)
  default     = []
}

variable "alarm_email" {
  type    = string
  default = ""
}

locals {
  tags = {
    Project   = "lucidity-disk-monitoring"
    ManagedBy = "terraform"
    Scope     = "multi-account-central"
  }

  dashboard_body = templatefile("${path.module}/../../../cloudwatch/dashboard.json", {
    region    = var.aws_region
    namespace = "CWAgent"
  })
}

module "central_cloudwatch" {
  source = "../../modules/cloudwatch"

  dashboard_name         = "lucidity-disk-monitoring-central"
  dashboard_body         = local.dashboard_body
  sns_topic_name         = "lucidity-disk-alerts-central"
  alarm_email            = var.alarm_email
  create_instance_alarms = false
  tags                   = local.tags
}

module "monitoring_account" {
  source             = "../../modules/monitoring-account"
  workload_role_arns = var.workload_role_arns
  tags               = local.tags
}

output "central_dashboard" {
  value = module.central_cloudwatch.dashboard_name
}

output "central_management_principal_arn" {
  value = var.central_management_principal_arn
}

output "workload_roles_parameter" {
  value = module.monitoring_account.workload_roles_parameter_name
}

output "onboarding" {
  value = module.monitoring_account.onboarding_instructions
}

# Boolean only — do not derive from sensitive string to avoid output sensitivity bleed
output "notes" {
  value = "Set external_id in tfvars for multi-account AssumeRole hardening. Value is never exported."
}
