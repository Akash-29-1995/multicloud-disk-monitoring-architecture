# Disk Monitoring Execution Role — least privilege
#
# Used by the central management identity (via STS AssumeRole) to:
# discover EC2, interact with SSM, and support monitoring enrollment.
# NEVER attach AdministratorAccess.

variable "role_name" {
  description = "Name of the cross-account (or same-account) execution role"
  type        = string
  default     = "DiskMonitoringExecutionRole"
}

variable "trusted_principal_arns" {
  description = "IAM principal ARNs allowed to AssumeRole (central management users/roles). Must not be empty or *."
  type        = list(string)

  validation {
    condition     = length(var.trusted_principal_arns) > 0 && !contains(var.trusted_principal_arns, "*")
    error_message = "trusted_principal_arns must list explicit ARNs; wildcard Principal is forbidden."
  }
}

variable "external_id" {
  description = "Optional ExternalId for AssumeRole hardening (recommended for multi-account)."
  type        = string
  default     = ""
  sensitive   = true
}

variable "enable_ssm_send_command" {
  description = "Allow SSM SendCommand for enrollment/remediation"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to the role"
  type        = map(string)
  default     = {}
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  external_id_enabled = length(var.external_id) > 0

  # Built with jsonencode so ExternalId is optional without dynamic for_each quirks
  trust_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      merge(
        {
          Sid    = "AllowCentralManagementAssume"
          Effect = "Allow"
          Action = "sts:AssumeRole"
          Principal = {
            AWS = var.trusted_principal_arns
          }
        },
        local.external_id_enabled ? {
          Condition = {
            StringEquals = {
              "sts:ExternalId" = var.external_id
            }
          }
        } : {}
      )
    ]
  })

  ssm_send_statement = var.enable_ssm_send_command ? [{
    Sid    = "SSMSendCommandEnrollment"
    Effect = "Allow"
    Action = ["ssm:SendCommand"]
    Resource = [
      "arn:aws:ec2:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:instance/*",
      "arn:aws:ssm:${data.aws_region.current.region}::document/AWS-RunShellScript",
      "arn:aws:ssm:${data.aws_region.current.region}::document/AWS-ConfigureAWSPackage",
      "arn:aws:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:document/*"
    ]
  }] : []

  execution_policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Sid    = "EC2Discovery"
          Effect = "Allow"
          Action = [
            "ec2:DescribeInstances",
            "ec2:DescribeTags",
            "ec2:DescribeRegions",
            "ec2:DescribeInstanceStatus"
          ]
          Resource = "*"
        },
        {
          Sid    = "SSMInventoryAndSession"
          Effect = "Allow"
          Action = [
            "ssm:DescribeInstanceInformation",
            "ssm:DescribeInstanceProperties",
            "ssm:GetConnectionStatus",
            "ssm:ListInventoryEntries",
            "ssm:DescribeInstanceAssociationsStatus",
            "ssm:ListCommandInvocations",
            "ssm:ListCommands",
            "ssm:GetCommandInvocation"
          ]
          Resource = "*"
        },
        {
          Sid    = "CloudWatchValidateMetrics"
          Effect = "Allow"
          Action = [
            "cloudwatch:GetMetricData",
            "cloudwatch:GetMetricStatistics",
            "cloudwatch:ListMetrics",
            "cloudwatch:DescribeAlarms"
          ]
          Resource = "*"
        },
        {
          Sid    = "DenyDangerousIAM"
          Effect = "Deny"
          Action = [
            "iam:CreateUser",
            "iam:CreateAccessKey",
            "iam:AttachUserPolicy",
            "iam:PutUserPolicy",
            "iam:CreateLoginProfile",
            "iam:UpdateAssumeRolePolicy"
          ]
          Resource = "*"
        }
      ],
      local.ssm_send_statement
    )
  })
}

resource "aws_iam_role" "monitoring_execution" {
  name               = var.role_name
  assume_role_policy = local.trust_policy
  description        = "Least-privilege role for Lucidity disk monitoring discovery and enrollment"
  tags               = var.tags
}

resource "aws_iam_role_policy" "execution" {
  name   = "${var.role_name}-policy"
  role   = aws_iam_role.monitoring_execution.id
  policy = local.execution_policy
}

output "role_arn" {
  description = "ARN of DiskMonitoringExecutionRole — use this in Ansible / central config"
  value       = aws_iam_role.monitoring_execution.arn
}

output "role_name" {
  value = aws_iam_role.monitoring_execution.name
}

output "account_id" {
  value = data.aws_caller_identity.current.account_id
}
