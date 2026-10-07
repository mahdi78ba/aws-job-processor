#!/usr/bin/env bash
# One-time bootstrap of the S3 bucket that stores Terraform remote state.
# Idempotent: safe to re-run, it re-applies the same settings.
# Usage: AWS_PROFILE=jobproc ./scripts/bootstrap-state.sh
set -euo pipefail

REGION="${AWS_REGION:-eu-central-1}"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
BUCKET="${TF_STATE_BUCKET:-jobproc-tfstate-${ACCOUNT_ID}-${REGION}}"

if aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
  echo "Bucket ${BUCKET} already exists, re-applying settings."
else
  echo "Creating bucket ${BUCKET} in ${REGION}..."
  aws s3api create-bucket \
    --bucket "$BUCKET" \
    --region "$REGION" \
    --create-bucket-configuration "LocationConstraint=${REGION}" >/dev/null
fi

# Versioning: lets you recover a previous state file if one gets corrupted or overwritten.
aws s3api put-bucket-versioning --bucket "$BUCKET" \
  --versioning-configuration Status=Enabled

# Encryption at rest (state files can contain sensitive values).
aws s3api put-bucket-encryption --bucket "$BUCKET" \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"},"BucketKeyEnabled":true}]}'

# The state bucket must never be public.
aws s3api put-public-access-block --bucket "$BUCKET" \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

aws s3api put-bucket-tagging --bucket "$BUCKET" \
  --tagging 'TagSet=[{Key=Project,Value=aws-job-processor},{Key=ManagedBy,Value=bootstrap-script}]'

echo
echo "State bucket ready. Export this before running terraform init:"
echo "  export TF_STATE_BUCKET=${BUCKET}"
