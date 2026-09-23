# EC2 instance profile for CloudWatch Agent + SSM Agent
# Attach this profile to monitored instances (or bake into launch templates).

variable "instance_role_name" {
  description = "IAM role name for EC2 instances that will be monitored"
  type        = string
  default     = "DiskMonitoringInstanceRole"
}

variable "instance_profile_name" {
  description = "Instance profile name"
  type        = string
  default     = "DiskMonitoringInstanceProfile"
}

data "aws_iam_policy_document" "ec2_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "instance" {
  name               = var.instance_role_name
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json
  description        = "Instance role for SSM + CloudWatch Agent disk metrics"
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cw_agent" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "this" {
  name = var.instance_profile_name
  role = aws_iam_role.instance.name
  tags = var.tags
}

output "instance_role_arn" {
  value = aws_iam_role.instance.arn
}

output "instance_profile_arn" {
  value = aws_iam_instance_profile.this.arn
}

output "instance_profile_name" {
  value = aws_iam_instance_profile.this.name
}
