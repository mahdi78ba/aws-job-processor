# Cheap dev configuration. No secrets in this file, so it is safe to commit (CI needs it).
aws_region  = "eu-central-1"
environment = "dev"
owner       = "mahdi"
vpc_cidr    = "10.0.0.0/16"

# Database: smallest instance, minimum gp3 storage
db_engine_version    = "16"
db_instance_class    = "db.t3.micro"
db_allocated_storage = 20
