output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "azs" {
  description = "AZs used by the subnets."
  value       = local.azs
}

output "public_subnet_ids" {
  description = "Public subnet IDs (ALB)."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs (app, worker, RDS)."
  value       = aws_subnet.private[*].id
}

output "nat_public_ip" {
  description = "Public IP that private instances use for outbound traffic."
  value       = aws_eip.nat.public_ip
}
