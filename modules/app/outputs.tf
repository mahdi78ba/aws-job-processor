output "security_group_id" {
  description = "Security group of the API instances (allowed into the database)."
  value       = aws_security_group.app.id
}

output "asg_name" {
  description = "Name of the API Auto Scaling Group."
  value       = aws_autoscaling_group.app.name
}
