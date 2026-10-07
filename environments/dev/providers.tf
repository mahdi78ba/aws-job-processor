provider "aws" {
  region = var.aws_region

  # Added to every taggable resource: makes cost tracking and "is everything gone?" checks trivial.
  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      Owner       = var.owner
      ManagedBy   = "terraform"
    }
  }
}
