variable "name" {
  description = "Name prefix, e.g. jobproc-dev (ALB and target group names are limited to 32 chars)."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID."
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR, used to scope the ALB's outbound rule."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnets for the ALB (at least 2 AZs)."
  type        = list(string)
}

variable "app_port" {
  description = "Port the app listens on."
  type        = number
}

variable "allowed_cidrs" {
  description = "Who may call the API. Use [\"<your-ip>/32\"] to restrict it to your machine."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
