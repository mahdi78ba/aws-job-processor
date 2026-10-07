locals {
  name = "${var.short_name}-${var.environment}" # e.g. jobproc-dev
}

module "vpc" {
  source = "../../modules/vpc"

  name       = local.name
  cidr_block = var.vpc_cidr
  az_count   = 2
}
