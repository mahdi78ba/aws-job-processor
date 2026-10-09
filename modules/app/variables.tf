variable "name" {
  description = "Name prefix, e.g. jobproc-dev."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnets for the instances (one per AZ)."
  type        = list(string)
}

variable "ami_id" {
  description = "Amazon Linux 2023 AMI ID."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.micro"
}

variable "instance_count" {
  description = "Fixed number of API instances (min = max = desired)."
  type        = number
  default     = 2
}

variable "app_port" {
  description = "Port uvicorn listens on."
  type        = number
}

variable "alb_security_group_id" {
  description = "Security group of the ALB, the only allowed caller."
  type        = string
}

variable "target_group_arn" {
  description = "ALB target group to register the instances in."
  type        = string
}

variable "artifact_bucket" {
  description = "S3 bucket holding the code zip."
  type        = string
}

variable "artifact_key" {
  description = "S3 key of the code zip (contains the content hash)."
  type        = string
}

variable "queue_url" {
  description = "SQS jobs queue URL."
  type        = string
}

variable "queue_arn" {
  description = "SQS jobs queue ARN (IAM)."
  type        = string
}

variable "db_host" {
  description = "PostgreSQL hostname."
  type        = string
}

variable "db_port" {
  description = "PostgreSQL port."
  type        = number
}

variable "db_name" {
  description = "PostgreSQL database name."
  type        = string
}

variable "db_secret_arn" {
  description = "Secrets Manager secret with the DB credentials."
  type        = string
}
