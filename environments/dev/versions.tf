terraform {
  required_version = ">= 1.11"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.7"
    }
  }

  # Partial backend configuration: the bucket name contains your account ID,
  # so it is passed at init time instead of being hard-coded:
  #   terraform init -backend-config="bucket=$TF_STATE_BUCKET"
  backend "s3" {
    key          = "aws-job-processor/dev/terraform.tfstate"
    region       = "eu-central-1"
    encrypt      = true
    use_lockfile = true # S3-native locking (Terraform >= 1.11), no DynamoDB table needed
  }
}
