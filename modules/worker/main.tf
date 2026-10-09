terraform {
  required_version = ">= 1.11"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}

data "aws_region" "current" {}

data "aws_default_tags" "current" {}

# --- Network: no inbound rules at all, the worker only makes outbound calls ---

resource "aws_security_group" "worker" {
  name        = "${var.name}-worker"
  description = "Worker instances: no inbound access"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name}-worker" }
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.worker.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "All outbound"
}

# --- IAM: consume the queue, read the DB secret, download the code ------------

resource "aws_iam_role" "worker" {
  name = "${var.name}-worker"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.worker.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "worker" {
  name = "worker-permissions"
  role = aws_iam_role.worker.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ConsumeJobs"
        Effect   = "Allow"
        Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:ChangeMessageVisibility"]
        Resource = var.queue_arn
      },
      {
        Sid      = "ReadDbCredentials"
        Effect   = "Allow"
        Action   = "secretsmanager:GetSecretValue"
        Resource = var.db_secret_arn
      },
      {
        Sid      = "DownloadCode"
        Effect   = "Allow"
        Action   = "s3:GetObject"
        Resource = "arn:aws:s3:::${var.artifact_bucket}/${var.artifact_key}"
      },
    ]
  })
}

resource "aws_iam_instance_profile" "worker" {
  name = "${var.name}-worker"
  role = aws_iam_role.worker.name
}

# --- Compute ------------------------------------------------------------------

resource "aws_launch_template" "worker" {
  name_prefix            = "${var.name}-worker-"
  image_id               = var.ami_id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.worker.id]
  update_default_version = true

  iam_instance_profile {
    arn = aws_iam_instance_profile.worker.arn
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh.tftpl", {
    region            = data.aws_region.current.region
    artifact_bucket   = var.artifact_bucket
    artifact_key      = var.artifact_key
    queue_url         = var.queue_url
    max_receive_count = var.max_receive_count
    db_host           = var.db_host
    db_port           = var.db_port
    db_name           = var.db_name
    db_secret_arn     = var.db_secret_arn
  }))

  tag_specifications {
    resource_type = "instance"
    tags          = merge(data.aws_default_tags.current.tags, { Name = "${var.name}-worker" })
  }

  tag_specifications {
    resource_type = "volume"
    tags          = merge(data.aws_default_tags.current.tags, { Name = "${var.name}-worker" })
  }
}

resource "aws_autoscaling_group" "worker" {
  name                      = "${var.name}-worker"
  min_size                  = var.instance_count
  max_size                  = var.instance_count
  desired_capacity          = var.instance_count
  vpc_zone_identifier       = var.subnet_ids
  health_check_type         = "EC2" # no load balancer: replace the instance if the VM itself fails
  health_check_grace_period = 120

  launch_template {
    id      = aws_launch_template.worker.id
    version = aws_launch_template.worker.latest_version
  }

  instance_refresh {
    strategy = "Rolling"

    preferences {
      min_healthy_percentage = 0 # one worker: replacing it briefly stops processing, SQS keeps the jobs meanwhile
    }
  }
}
