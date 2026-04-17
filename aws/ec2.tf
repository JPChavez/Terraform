# ── AMI — Latest Amazon Linux 2023 ───────────────────────────────────────────

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# ── KMS Key — EC2 EBS encryption ─────────────────────────────────────────────

resource "aws_kms_key" "ec2" {
  description             = "KMS key for EC2 EBS encryption — ${local.prefix}"
  deletion_window_in_days = var.kms_deletion_window_days
  enable_key_rotation     = true # CKV_AWS_7

  policy = data.aws_iam_policy_document.kms_ec2.json
}

resource "aws_kms_alias" "ec2" {
  name          = local.kms_alias_ec2
  target_key_id = aws_kms_key.ec2.key_id
}

data "aws_iam_policy_document" "kms_ec2" {
  statement {
    sid    = "EnableRootAccess"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowEC2ServiceEncryption"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey",
      "kms:DescribeKey",
      "kms:ReEncrypt*",
      "kms:CreateGrant",
    ]
    resources = ["*"]
  }
}

# ── IAM — EC2 Instance Profile (SSM access — no SSH key needed) ───────────────

resource "aws_iam_role" "ec2" {
  name = "${local.prefix}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${local.prefix}-ec2-profile"
  role = aws_iam_role.ec2.name
}

# ── Security Group — EC2 ─────────────────────────────────────────────────────
# No inbound SSH — access via SSM Session Manager only

resource "aws_security_group" "ec2" {
  name        = "sg-ec2-${local.prefix}"
  description = "Security group for EC2 instance — SSM access only"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS outbound for SSM and package updates"
  }

  tags = merge(local.common_tags, { Name = "sg-ec2-${local.prefix}" })
}

# ── EC2 Instance ─────────────────────────────────────────────────────────────

resource "aws_instance" "main" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.ec2_instance_type
  subnet_id              = aws_subnet.system[0].id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name

  # No key pair — access via SSM Session Manager (CKV_AWS_8 compliant)
  key_name = null

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 enforced — CKV_AWS_79
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.ec2_root_volume_size
    encrypted             = true
    kms_key_id            = aws_kms_key.ec2.arn
    delete_on_termination = true
  }

  monitoring = true # CKV_AWS_126 — detailed monitoring

  tags = merge(local.common_tags, { Name = local.ec2_name })
}
