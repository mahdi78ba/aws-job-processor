#!/usr/bin/env bash
# Lists the resources of this project that still exist in AWS. Read-only and free.
# Run it after every destroy: every line must show 0 (the state bucket is expected until final cleanup).
# Usage: AWS_PROFILE=jobproc ./scripts/check-leftovers.sh
set -euo pipefail
export AWS_PAGER=""
REGION="${AWS_REGION:-eu-central-1}"
TAG="Name=tag:Project,Values=aws-job-processor"

row() { printf '  %-26s %s\n' "$1" "$2"; }

echo "Billable resources still present in ${REGION}:"
row "EC2 instances"      "$(aws ec2 describe-instances --region "$REGION" --filters "$TAG" "Name=instance-state-name,Values=pending,running,stopping,stopped" --query 'length(Reservations[].Instances[])' --output text)"
row "NAT gateways"       "$(aws ec2 describe-nat-gateways --region "$REGION" --filter "$TAG" "Name=state,Values=pending,available,deleting" --query 'length(NatGateways)' --output text)"
row "Elastic IPs"        "$(aws ec2 describe-addresses --region "$REGION" --filters "$TAG" --query 'length(Addresses)' --output text)"
row "Load balancers"     "$(aws elbv2 describe-load-balancers --region "$REGION" --query "length(LoadBalancers[?starts_with(LoadBalancerName, 'jobproc-')])" --output text)"
row "Auto Scaling groups" "$(aws autoscaling describe-auto-scaling-groups --region "$REGION" --query "length(AutoScalingGroups[?starts_with(AutoScalingGroupName, 'jobproc-')])" --output text)"
row "RDS instances"      "$(aws rds describe-db-instances --region "$REGION" --query "length(DBInstances[?starts_with(DBInstanceIdentifier, 'jobproc-')])" --output text)"
# shellcheck disable=SC2016  # the backticks are a JMESPath literal, not shell syntax
row "SQS queues"         "$(aws sqs list-queues --region "$REGION" --queue-name-prefix jobproc- --query 'length(QueueUrls || `[]`)' --output text)"
row "VPCs"               "$(aws ec2 describe-vpcs --region "$REGION" --filters "$TAG" --query 'length(Vpcs)' --output text)"
row "Artifact buckets"   "$(aws s3api list-buckets --query "length(Buckets[?starts_with(Name, 'jobproc-dev-artifacts-')])" --output text)"
row "State bucket (kept)" "$(aws s3api list-buckets --query "length(Buckets[?starts_with(Name, 'jobproc-tfstate-')])" --output text)"

echo
echo "Everything tagged Project=aws-job-processor (this API can lag a few minutes behind a destroy):"
aws resourcegroupstaggingapi get-resources --region "$REGION" --tag-filters Key=Project,Values=aws-job-processor \
  --query 'ResourceTagMappingList[].ResourceARN' --output text | tr '\t' '\n' | sed 's/^/  /'
