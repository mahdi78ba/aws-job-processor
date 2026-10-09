output "address" {
  description = "Hostname of the database."
  value       = aws_db_instance.this.address
}

output "port" {
  description = "Port of the database."
  value       = aws_db_instance.this.port
}

output "db_name" {
  description = "Name of the initial database."
  value       = aws_db_instance.this.db_name
}

output "master_user_secret_arn" {
  description = "ARN of the Secrets Manager secret holding the master username/password (JSON)."
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
}

output "security_group_id" {
  description = "Security group attached to the database."
  value       = aws_security_group.db.id
}
