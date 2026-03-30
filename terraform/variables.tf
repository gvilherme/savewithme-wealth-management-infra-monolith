variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "app_name" {
  description = "Application name used for resource naming"
  type        = string
  default     = "savewithme"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t4g.small"

  validation {
    condition = can(regex("^(t4g|t3g|m6g|m7g|c6g|c7g|r6g|r7g|a1)\\.", var.instance_type))
    error_message = "Instance type must be ARM-compatible (e.g., t4g.*, t3g.*, m6g.*, m7g.*, c6g.*, c7g.*, r6g.*, r7g.*, a1.*) to match the arm64 AMI."
  }
}

variable "ssh_public_key" {
  description = "SSH public key content to inject into EC2"
  type        = string
  sensitive   = true
}
