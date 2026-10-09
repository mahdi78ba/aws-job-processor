output "security_group_id" {
  description = "Security group of the worker instances (allowed into the database)."
  value       = aws_security_group.worker.id
}

output "asg_name" {
  description = "Name of the worker Auto Scaling Group."
  value       = aws_autoscaling_group.worker.name
}
