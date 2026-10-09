output "vpc_id" {
  description = "ID of the VPC."
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs."
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs."
  value       = module.vpc.private_subnet_ids
}

output "nat_public_ip" {
  description = "Egress IP of the private subnets."
  value       = module.vpc.nat_public_ip
}

output "jobs_queue_url" {
  description = "URL of the jobs queue."
  value       = module.queue.queue_url
}

output "dlq_url" {
  description = "URL of the dead-letter queue."
  value       = module.queue.dlq_url
}

output "db_address" {
  description = "Hostname of the PostgreSQL database (private, reachable only from inside the VPC)."
  value       = module.db.address
}

output "db_secret_arn" {
  description = "Secrets Manager secret with the DB master credentials."
  value       = module.db.master_user_secret_arn
}
