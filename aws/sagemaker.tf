# ── Amazon SageMaker — equivalent of Azure AI Foundry ─────────────────────────

resource "aws_kms_key" "sagemaker" {
  description             = "KMS key for SageMaker domain and artifact encryption"
  deletion_window_in_days = var.kms_deletion_window_days
  enable_key_rotation     = true
  tags                    = local.common_tags
}

resource "aws_kms_alias" "sagemaker" {
  name          = local.kms_alias_sagemaker
  target_key_id = aws_kms_key.sagemaker.key_id
}

# ── IAM execution role for SageMaker ─────────────────────────────────────────

resource "aws_iam_role" "sagemaker" {
  name = local.sagemaker_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "sagemaker.amazonaws.com" }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "sagemaker_full_access" {
  role       = aws_iam_role.sagemaker.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
}

# ── Dedicated S3 bucket for SageMaker model artifacts and pipeline data ───────

resource "aws_s3_bucket" "sagemaker" {
  # checkov:skip=CKV_AWS_144:cross-region replication not required for ML artifact storage at this scale
  bucket = local.sagemaker_bucket_name
  tags   = local.common_tags
}

resource "aws_s3_bucket_versioning" "sagemaker" {
  bucket = aws_s3_bucket.sagemaker.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "sagemaker" {
  bucket = aws_s3_bucket.sagemaker.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.sagemaker.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "sagemaker" {
  bucket                  = aws_s3_bucket.sagemaker.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ── Security group for SageMaker domain network interface ─────────────────────

resource "aws_security_group" "sagemaker" {
  name        = "${local.prefix}-sg-sagemaker"
  description = "Security group for SageMaker domain"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all egress for SageMaker model downloads and updates"
  }

  tags = local.common_tags
}

# ── SageMaker Domain ──────────────────────────────────────────────────────────

resource "aws_sagemaker_domain" "main" {
  domain_name = local.sagemaker_domain_name
  auth_mode   = var.sagemaker_auth_mode
  vpc_id      = aws_vpc.main.id
  subnet_ids  = aws_subnet.system[*].id

  # CKV_AWS_187: encrypt domain storage with a customer-managed KMS key
  kms_key_id = aws_kms_key.sagemaker.arn

  default_user_settings {
    execution_role  = aws_iam_role.sagemaker.arn
    security_groups = [aws_security_group.sagemaker.id]
  }

  tags = local.common_tags
}
