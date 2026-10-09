output "queue_url" {
  description = "URL of the jobs queue (used by the SDK to send/receive)."
  value       = aws_sqs_queue.jobs.id
}

output "queue_arn" {
  description = "ARN of the jobs queue (used in IAM policies)."
  value       = aws_sqs_queue.jobs.arn
}

output "queue_name" {
  description = "Name of the jobs queue."
  value       = aws_sqs_queue.jobs.name
}

output "dlq_url" {
  description = "URL of the dead-letter queue."
  value       = aws_sqs_queue.dlq.id
}

output "dlq_arn" {
  description = "ARN of the dead-letter queue."
  value       = aws_sqs_queue.dlq.arn
}

output "max_receive_count" {
  description = "Receives before a message goes to the DLQ (the worker uses it to decide when a job is FAILED)."
  value       = var.max_receive_count
}
