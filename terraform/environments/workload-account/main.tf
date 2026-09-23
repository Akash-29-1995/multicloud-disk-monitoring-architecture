# Workload account apply helper
# Use when AWS credentials point at a WORKLOAD account and you want only the
# DiskMonitoringExecutionRole (+ instance profile) with trust back to central.

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

variable "trusted_principal_arns" {
  description = "Central management principal ARN(s)"
  type        = list(string)
}

variable "external_id" {
  type      = string
  default   = ""
  sensitive = true
}

variable "execution_role_name" {
  type    = string
  default = "DiskMonitoringExecutionRole"
}

locals {
  tags = {
    Project   = "lucidity-disk-monitoring"
    ManagedBy = "terraform"
    Scope     = "workload-account"
  }
}

module "monitoring_role" {
  source = "../../modules/monitoring-role"

  role_name               = var.execution_role_name
  trusted_principal_arns  = var.trusted_principal_arns
  external_id             = var.external_id
  enable_ssm_send_command = true
  tags                    = local.tags
}

output "execution_role_arn" {
  value = module.monitoring_role.role_arn
}

output "instance_profile_name" {
  value = module.monitoring_role.instance_profile_name
}

output "account_id" {
  value = module.monitoring_role.account_id
}
