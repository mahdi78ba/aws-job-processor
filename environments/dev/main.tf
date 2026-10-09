locals {
  name = "${var.short_name}-${var.environment}" # e.g. jobproc-dev
}

# Latest Amazon Linux 2023 AMI, published by AWS as a public SSM parameter.
data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
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

  allowed_security_group_ids = {
    app    = module.app.security_group_id
    worker = module.worker.security_group_id
  }
}

# --- Code artifacts: zipped by Terraform, stored in S3, downloaded by instances at boot ---

resource "aws_s3_bucket" "artifacts" {
  bucket_prefix = "${local.name}-artifacts-"
  force_destroy = true # destroy may delete it with the zips inside (new buckets are private by default)
}

data "archive_file" "app" {
  type             = "zip"
  source_dir       = "${path.module}/../../app"
  output_path      = "${path.module}/../../build/app.zip"
  excludes         = ["__pycache__", ".venv"]
  output_file_mode = "0644" # same bytes, same hash, on your laptop and in CI
}

data "archive_file" "worker" {
  type             = "zip"
  source_dir       = "${path.module}/../../worker"
  output_path      = "${path.module}/../../build/worker.zip"
  excludes         = ["__pycache__", ".venv"]
  output_file_mode = "0644"
}

# The content hash is part of the key: new code => new key => new launch template version => rolling refresh.
resource "aws_s3_object" "app" {
  bucket = aws_s3_bucket.artifacts.id
  key    = "app/${data.archive_file.app.output_md5}.zip"
  source = data.archive_file.app.output_path
}

resource "aws_s3_object" "worker" {
  bucket = aws_s3_bucket.artifacts.id
  key    = "worker/${data.archive_file.worker.output_md5}.zip"
  source = data.archive_file.worker.output_path
}

# --- Compute tiers ---

module "alb" {
  source = "../../modules/alb"

  name              = local.name
  vpc_id            = module.vpc.vpc_id
  vpc_cidr          = module.vpc.vpc_cidr_block
  public_subnet_ids = module.vpc.public_subnet_ids
  app_port          = var.app_port
}

module "app" {
  source = "../../modules/app"

  name           = local.name
  vpc_id         = module.vpc.vpc_id
  subnet_ids     = module.vpc.private_subnet_ids
  ami_id         = data.aws_ssm_parameter.al2023_ami.insecure_value
  instance_type  = var.app_instance_type
  instance_count = var.app_instance_count
  app_port       = var.app_port

  alb_security_group_id = module.alb.security_group_id
  target_group_arn      = module.alb.target_group_arn

  artifact_bucket = aws_s3_bucket.artifacts.id
  artifact_key    = aws_s3_object.app.key
  queue_url       = module.queue.queue_url
  queue_arn       = module.queue.queue_arn
  db_host         = module.db.address
  db_port         = module.db.port
  db_name         = module.db.db_name
  db_secret_arn   = module.db.master_user_secret_arn
}

module "worker" {
  source = "../../modules/worker"

  name           = local.name
  vpc_id         = module.vpc.vpc_id
  subnet_ids     = module.vpc.private_subnet_ids
  ami_id         = data.aws_ssm_parameter.al2023_ami.insecure_value
  instance_type  = var.worker_instance_type
  instance_count = var.worker_instance_count

  artifact_bucket   = aws_s3_bucket.artifacts.id
  artifact_key      = aws_s3_object.worker.key
  queue_url         = module.queue.queue_url
  queue_arn         = module.queue.queue_arn
  max_receive_count = module.queue.max_receive_count
  db_host           = module.db.address
  db_port           = module.db.port
  db_name           = module.db.db_name
  db_secret_arn     = module.db.master_user_secret_arn
}
