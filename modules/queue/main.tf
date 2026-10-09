terraform {
  required_version = ">= 1.11"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}

# Dead-letter queue: receives messages that failed processing max_receive_count times.
# Retention is longer than the main queue's because a message keeps its ORIGINAL enqueue
# timestamp when it is moved to the DLQ (standard queues), so it would otherwise expire early.
resource "aws_sqs_queue" "dlq" {
  name                      = "${var.name}-jobs-dlq"
  message_retention_seconds = 1209600 # 14 days, the maximum
  sqs_managed_sse_enabled   = true

  tags = { Name = "${var.name}-jobs-dlq" }
}

resource "aws_sqs_queue" "jobs" {
  name                       = "${var.name}-jobs"
  visibility_timeout_seconds = var.visibility_timeout_seconds
  message_retention_seconds  = var.message_retention_seconds
  receive_wait_time_seconds  = 20 # long polling by default: fewer empty responses, lower cost
  sqs_managed_sse_enabled    = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = var.max_receive_count
  })

  tags = { Name = "${var.name}-jobs" }
}

# Only the jobs queue may use this DLQ as its dead-letter target.
resource "aws_sqs_queue_redrive_allow_policy" "dlq" {
  queue_url = aws_sqs_queue.dlq.id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.jobs.arn]
  })
}
