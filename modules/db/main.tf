terraform {
  required_version = ">= 1.11"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}

# RDS needs subnets in at least 2 AZs, even for a single-AZ instance.
resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-db"
  subnet_ids = var.subnet_ids

  tags = { Name = "${var.name}-db" }
}

# No egress rules: the database never initiates connections
# (Terraform removes AWS's default allow-all egress rule on creation).
resource "aws_security_group" "db" {
  name        = "${var.name}-db"
  description = "PostgreSQL, reachable only from the app and worker tiers"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name}-db" }
}

# One rule per allowed tier, referencing its security group instead of a CIDR:
# access follows the instances, whatever their IPs are.
resource "aws_vpc_security_group_ingress_rule" "postgres" {
  for_each = var.allowed_security_group_ids

  security_group_id            = aws_security_group.db.id
  referenced_security_group_id = each.value
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  description                  = "PostgreSQL from ${each.key}"
}

resource "aws_db_instance" "this" {
  identifier     = "${var.name}-postgres"
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage = var.allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.username
  # RDS generates the password and stores it in Secrets Manager:
  # it never appears in code, tfvars or Terraform state.
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false
  multi_az               = false

  # Ephemeral dev settings: fast create/destroy, nothing left behind.
  # Production: backups >= 7 days, deletion_protection = true, final snapshot, Multi-AZ.
  backup_retention_period  = 0
  skip_final_snapshot      = true
  deletion_protection      = false
  delete_automated_backups = true
  apply_immediately        = true

  performance_insights_enabled = false
  monitoring_interval          = 0

  tags = { Name = "${var.name}-postgres" }
}
