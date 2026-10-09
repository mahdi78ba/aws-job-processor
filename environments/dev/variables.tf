variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "eu-central-1"
}

variable "project" {
  description = "Project name, used for tagging."
  type        = string
  default     = "aws-job-processor"
}

variable "short_name" {
  description = "Short prefix for resource names (ALB/target group names are limited to 32 chars)."
  type        = string
  default     = "jobproc"
}

variable "environment" {
  description = "Environment name, e.g. dev."
  type        = string
}

variable "owner" {
  description = "Who owns these resources (name or email). Applied as the Owner tag."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "db_engine_version" {
  description = "PostgreSQL major version."
  type        = string
  default     = "16"
}

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "RDS storage in GiB."
  type        = number
  default     = 20
}
