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

# --- Network: only the ALB can reach the app port ---------------------------

resource "aws_security_group" "app" {
  name        = "${var.name}-app"
  description = "API instances: app port from the ALB only"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name}-app" }
}

resource "aws_vpc_security_group_ingress_rule" "from_alb" {
  security_group_id            = aws_security_group.app.id
  referenced_security_group_id = var.alb_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = var.app_port
  to_port                      = var.app_port
  description                  = "App port from the ALB"
}

# Outbound: PostgreSQL, and SQS / Secrets Manager / S3 / packages through the NAT.
resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.app.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "All outbound"
}

# --- IAM: exactly what the API needs, nothing more ---------------------------

resource "aws_iam_role" "app" {
  name = "${var.name}-app"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# SSM Session Manager: shell access without SSH keys, bastion or open port 22.
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "app" {
  name = "app-permissions"
  role = aws_iam_role.app.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "SendJobs"
        Effect   = "Allow"
        Action   = "sqs:SendMessage"
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

resource "aws_iam_instance_profile" "app" {
  name = "${var.name}-app"
  role = aws_iam_role.app.name
}

# --- Compute: launch template + fixed-size Auto Scaling Group ----------------

resource "aws_launch_template" "app" {
  name_prefix            = "${var.name}-app-"
  image_id               = var.ami_id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.app.id]
  update_default_version = true

  iam_instance_profile {
    arn = aws_iam_instance_profile.app.arn
  }

  # IMDSv2 only: stops SSRF attacks from stealing the instance role's credentials.
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh.tftpl", {
    region          = data.aws_region.current.region
    artifact_bucket = var.artifact_bucket
    artifact_key    = var.artifact_key
    app_port        = var.app_port
    queue_url       = var.queue_url
    db_host         = var.db_host
    db_port         = var.db_port
    db_name         = var.db_name
    db_secret_arn   = var.db_secret_arn
  }))

  # Provider default_tags don't reach instances launched by an ASG: tag them explicitly.
  tag_specifications {
    resource_type = "instance"
    tags          = merge(data.aws_default_tags.current.tags, { Name = "${var.name}-app" })
  }

  tag_specifications {
    resource_type = "volume"
    tags          = merge(data.aws_default_tags.current.tags, { Name = "${var.name}-app" })
  }
}

resource "aws_autoscaling_group" "app" {
  name                      = "${var.name}-app"
  min_size                  = var.instance_count
  max_size                  = var.instance_count
  desired_capacity          = var.instance_count
  vpc_zone_identifier       = var.subnet_ids
  target_group_arns         = [var.target_group_arn]
  health_check_type         = "ELB" # replace instances the ALB sees as unhealthy, not only dead VMs
  health_check_grace_period = 300   # time to boot and install packages before health checks count

  launch_template {
    id      = aws_launch_template.app.id
    version = aws_launch_template.app.latest_version
  }

  # New code => new launch template version => instances replaced one at a time, the ALB keeps serving.
  instance_refresh {
    strategy = "Rolling"

    preferences {
      min_healthy_percentage = 50
    }
  }
}
