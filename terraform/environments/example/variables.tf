variable "aws_region" {
  description = "AWS region for MVP deploy"
  type        = string
  default     = "us-east-1"
}

variable "trusted_principal_arns" {
  description = "Principals allowed to AssumeRole. Empty = current account root (MVP)."
  type        = list(string)
  default     = []
}

variable "external_id" {
  description = "Optional ExternalId for AssumeRole (leave empty for single-account MVP)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "execution_role_name" {
  type    = string
  default = "DiskMonitoringExecutionRole"
}

variable "dashboard_name" {
  type    = string
  default = "lucidity-disk-monitoring"
}

variable "sns_topic_name" {
  type    = string
  default = "lucidity-disk-alerts"
}

variable "alarm_email" {
  description = "Your email for alarm notifications (confirm the SNS subscription!)"
  type        = string
  default     = ""
}

variable "warning_threshold_percent" {
  type    = number
  default = 80
}

variable "critical_threshold_percent" {
  type    = number
  default = 90
}

variable "min_free_bytes" {
  type    = number
  default = 5368709120
}

variable "metric_namespace" {
  type    = string
  default = "CWAgent"
}

variable "create_example_alarms" {
  type    = bool
  default = true
}

variable "example_instance_id" {
  description = "Set to your EC2 instance id (i-...) after launch to create alarms; leave empty first apply"
  type        = string
  default     = ""
}

variable "example_fstype" {
  description = "xfs for Amazon Linux, ext4 for many Ubuntu AMIs"
  type        = string
  default     = "xfs"
}

variable "example_path" {
  type    = string
  default = "/"
}
