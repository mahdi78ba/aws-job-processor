output "dns_name" {
  description = "Public DNS name of the ALB."
  value       = aws_lb.this.dns_name
}

output "security_group_id" {
  description = "ALB security group (the app tier only accepts traffic from it)."
  value       = aws_security_group.alb.id
}

output "target_group_arn" {
  description = "Target group the app ASG registers its instances in."
  value       = aws_lb_target_group.app.arn
}
