variable "name" {
  description = "Name prefix for all resources, e.g. jobproc-dev."
  type        = string
}

variable "cidr_block" {
  description = "VPC CIDR block. Must be a /16 so the /24 subnet math in main.tf works."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.cidr_block, 0)) && endswith(var.cidr_block, "/16")
    error_message = "cidr_block must be a valid IPv4 /16, e.g. 10.0.0.0/16."
  }
}

variable "az_count" {
  description = "Number of AZs to spread subnets across. ALB and RDS subnet groups need at least 2."
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "az_count must be 2 or 3."
  }
}
