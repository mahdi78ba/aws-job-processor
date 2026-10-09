locals {
  name = "${var.short_name}-${var.environment}" # e.g. jobproc-dev
}

module "vpc" {
  source = "../../modules/vpc"

  name       = local.name
  cidr_block = var.vpc_cidr
  az_count   = 2
}

module "queue" {
  source = "../../modules/queue"

  name = local.name
}

module "db" {
  source = "../../modules/db"

  name              = local.name
  vpc_id            = module.vpc.vpc_id
  subnet_ids        = module.vpc.private_subnet_ids
  engine_version    = var.db_engine_version
  instance_class    = var.db_instance_class
  allocated_storage = var.db_allocated_storage

  # Filled in Step 3c, once the app and worker modules (and their security groups) exist.
  allowed_security_group_ids = {}
}
