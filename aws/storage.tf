# ── S3 Access Logs Bucket (created first, referenced by main bucket) ──────────

resource "aws_s3_bucket" "logs" {
  #checkov:skip=CKV_AWS_18:This IS the access logs bucket — logging a logs bucket to itself creates a loop
  bucket        = local.s3_logs_bucket_name
  force_destroy = false

  tags = { Name = local.s3_logs_bucket_name }
}

resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true  # CKV_AWS_53
  block_public_policy     = true  # CKV_AWS_54
  ignore_public_acls      = true  # CKV_AWS_55
  restrict_public_buckets = true  # CKV_AWS_56
}

resource "aws_s3_bucket_ownership_controls" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {
    object_ownership = "BucketOwnerEnforced" # Disables ACLs
  }
}

# ── Main S3 Bucket — equivalent of Azure Storage Account ─────────────────────

resource "aws_s3_bucket" "main" {
  bucket        = local.s3_bucket_name
  force_destroy = false

  tags = { Name = local.s3_bucket_name }
}

# CKV_AWS_21: enable versioning
resource "aws_s3_bucket_versioning" "main" {
  bucket = aws_s3_bucket.main.id
  versioning_configuration {
    status = "Enabled"
  }
}

# CKV_AWS_19: server-side encryption with KMS CMK
resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  bucket = aws_s3_bucket.main.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }
    bucket_key_enabled = true # Reduces KMS API calls and cost
  }
}

# CKV_AWS_53-56, CKV2_AWS_6: block all public access
resource "aws_s3_bucket_public_access_block" "main" {
  bucket                  = aws_s3_bucket.main.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enforce bucket owner, disable ACLs
resource "aws_s3_bucket_ownership_controls" "main" {
  bucket = aws_s3_bucket.main.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# CKV_AWS_18: access logging to the logs bucket — equivalent of Azure blob diagnostic logs
resource "aws_s3_bucket_logging" "main" {
  bucket        = aws_s3_bucket.main.id
  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "s3-access-logs/${local.s3_bucket_name}/"
}

# Lifecycle: transition to IA after 90 days, expire non-current versions after 365 days
resource "aws_s3_bucket_lifecycle_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    id     = "transition-to-ia"
    status = "Enabled"

    transition {
      days          = var.s3_lifecycle_transition_days
      storage_class = "STANDARD_IA"
    }

    noncurrent_version_expiration {
      noncurrent_days = var.s3_lifecycle_expiration_days
    }
  }
}

# Enforce HTTPS-only access — equivalent of Azure https_traffic_only_enabled
resource "aws_s3_bucket_policy" "main" {
  bucket = aws_s3_bucket.main.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyNonTLS"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.main.arn,
          "${aws_s3_bucket.main.arn}/*",
        ]
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      },
      {
        Sid    = "AllowEKSNodeAccess"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.eks_node.arn
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
        ]
        Resource = [
          aws_s3_bucket.main.arn,
          "${aws_s3_bucket.main.arn}/*",
        ]
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.main]
}
