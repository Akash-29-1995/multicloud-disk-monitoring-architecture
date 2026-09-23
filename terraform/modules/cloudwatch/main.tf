# Simplified standard metric alarms (replaces metric_query form for clarity)

variable "dashboard_name" {
  type    = string
  default = "lucidity-disk-monitoring"
}

variable "dashboard_body" {
  description = "CloudWatch dashboard JSON body"
  type        = string
}

variable "sns_topic_name" {
  type    = string
  default = "lucidity-disk-alerts"
}

variable "alarm_email" {
  description = "Email for SNS subscription (leave empty to skip subscription)"
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
  description = "Absolute free-space floor (bytes). Alarm when free space is below this."
  type        = number
  default     = 5368709120 # 5 GiB
}

variable "metric_namespace" {
  type    = string
  default = "CWAgent"
}

variable "create_example_alarms" {
  description = "Create template alarms when example_instance_id is provided"
  type        = bool
  default     = true
}

variable "example_instance_id" {
  description = "Optional instance id for example alarms; empty skips instance-specific alarms"
  type        = string
  default     = ""
}

variable "example_fstype" {
  description = "Filesystem type dimension used by CloudWatch Agent (xfs on Amazon Linux, ext4 on Ubuntu)"
  type        = string
  default     = "xfs"
}

variable "example_path" {
  type    = string
  default = "/"
}

variable "tags" {
  type    = map(string)
  default = {}
}

resource "aws_sns_topic" "disk_alerts" {
  name = var.sns_topic_name
  tags = var.tags
}

resource "aws_sns_topic_subscription" "email" {
  count     = length(var.alarm_email) > 0 ? 1 : 0
  topic_arn = aws_sns_topic.disk_alerts.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

resource "aws_cloudwatch_dashboard" "disk" {
  dashboard_name = var.dashboard_name
  dashboard_body = var.dashboard_body
}

locals {
  create_alarms = var.create_example_alarms && length(var.example_instance_id) > 0
  dims = {
    InstanceId = var.example_instance_id
    path       = var.example_path
    fstype     = var.example_fstype
  }
}

resource "aws_cloudwatch_metric_alarm" "disk_warning" {
  count               = local.create_alarms ? 1 : 0
  alarm_name          = "disk-used-warning-${var.example_instance_id}"
  alarm_description   = "Disk used percent >= ${var.warning_threshold_percent}% (Warning)"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  datapoints_to_alarm = 2
  metric_name         = "disk_used_percent"
  namespace           = var.metric_namespace
  period              = 300
  statistic           = "Average"
  threshold           = var.warning_threshold_percent
  treat_missing_data  = "notBreaching"
  dimensions          = local.dims
  alarm_actions       = [aws_sns_topic.disk_alerts.arn]
  ok_actions          = [aws_sns_topic.disk_alerts.arn]
  tags                = var.tags
}

resource "aws_cloudwatch_metric_alarm" "disk_critical" {
  count               = local.create_alarms ? 1 : 0
  alarm_name          = "disk-used-critical-${var.example_instance_id}"
  alarm_description   = "Disk used percent >= ${var.critical_threshold_percent}% (Critical)"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  metric_name         = "disk_used_percent"
  namespace           = var.metric_namespace
  period              = 300
  statistic           = "Average"
  threshold           = var.critical_threshold_percent
  treat_missing_data  = "notBreaching"
  dimensions          = local.dims
  alarm_actions       = [aws_sns_topic.disk_alerts.arn]
  tags                = var.tags
}

resource "aws_cloudwatch_metric_alarm" "disk_free_low" {
  count               = local.create_alarms ? 1 : 0
  alarm_name          = "disk-free-low-${var.example_instance_id}"
  alarm_description   = "Disk free bytes below ${var.min_free_bytes}"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "disk_free"
  namespace           = var.metric_namespace
  period              = 300
  statistic           = "Average"
  threshold           = var.min_free_bytes
  treat_missing_data  = "notBreaching"
  dimensions          = local.dims
  alarm_actions       = [aws_sns_topic.disk_alerts.arn]
  tags                = var.tags
}

# Missing metrics = agent/config problem (heal signal: re-run enroll)
resource "aws_cloudwatch_metric_alarm" "agent_missing_metrics" {
  count               = local.create_alarms ? 1 : 0
  alarm_name          = "disk-agent-missing-${var.example_instance_id}"
  alarm_description   = "No disk_used_percent samples — agent may be down; re-run ansible playbooks/enroll.yml"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 3
  metric_name         = "disk_used_percent"
  namespace           = var.metric_namespace
  period              = 300
  statistic           = "SampleCount"
  threshold           = 1
  treat_missing_data  = "breaching"
  dimensions          = local.dims
  alarm_actions       = [aws_sns_topic.disk_alerts.arn]
  tags                = var.tags
}

output "sns_topic_arn" {
  value = aws_sns_topic.disk_alerts.arn
}

output "dashboard_name" {
  value = aws_cloudwatch_dashboard.disk.dashboard_name
}

output "dashboard_arn" {
  value = aws_cloudwatch_dashboard.disk.dashboard_arn
}
