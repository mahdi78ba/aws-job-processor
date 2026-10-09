variable "name" {
  description = "Name prefix for the queues, e.g. jobproc-dev."
  type        = string
}

variable "visibility_timeout_seconds" {
  description = "How long a received message stays hidden from other consumers. Must exceed the worst-case job processing time."
  type        = number
  default     = 60
}

variable "message_retention_seconds" {
  description = "How long unprocessed messages are kept in the main queue."
  type        = number
  default     = 345600 # 4 days (the AWS default)
}

variable "max_receive_count" {
  description = "Failed receives before a message is moved to the DLQ."
  type        = number
  default     = 3

  validation {
    condition     = var.max_receive_count >= 1 && var.max_receive_count <= 10
    error_message = "max_receive_count must be between 1 and 10."
  }
}
