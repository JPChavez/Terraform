# ── AWS Glue — equivalent of Azure Data Factory ───────────────────────────────

resource "aws_kms_key" "glue" {
  description             = "KMS key for AWS Glue job bookmark and CloudWatch log encryption"
  deletion_window_in_days = var.kms_deletion_window_days
  enable_key_rotation     = true
  tags                    = local.common_tags
}

resource "aws_kms_alias" "glue" {
  name          = local.kms_alias_glue
  target_key_id = aws_kms_key.glue.key_id
}

# ── IAM role for Glue jobs ────────────────────────────────────────────────────

resource "aws_iam_role" "glue" {
  name = local.glue_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "glue.amazonaws.com" }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "glue_service" {
  role       = aws_iam_role.glue.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# Inline policy granting access to the main S3 bucket for ETL input/output
resource "aws_iam_role_policy" "glue_s3_access" {
  name = "${local.glue_role_name}-s3"
  role = aws_iam_role.glue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
        Resource = [aws_s3_bucket.main.arn, "${aws_s3_bucket.main.arn}/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey"]
        Resource = [aws_kms_key.s3.arn, aws_kms_key.glue.arn]
      }
    ]
  })
}

# ── Glue Security Configuration — encrypts job bookmarks, logs, and S3 output ─

resource "aws_glue_security_configuration" "main" {
  name = local.glue_sec_config_name

  encryption_configuration {
    cloudwatch_encryption {
      cloudwatch_encryption_mode = "SSE-KMS"
      kms_key_arn                = aws_kms_key.glue.arn
    }

    job_bookmarks_encryption {
      job_bookmarks_encryption_mode = "CSE-KMS"
      kms_key_arn                   = aws_kms_key.glue.arn
    }

    s3_encryption {
      s3_encryption_mode = "SSE-KMS"
      kms_key_arn        = aws_kms_key.glue.arn
    }
  }
}

# ── Glue Data Catalog database ────────────────────────────────────────────────

resource "aws_glue_catalog_database" "main" {
  name = local.glue_database_name
}

# ── Glue ETL job ──────────────────────────────────────────────────────────────

resource "aws_glue_job" "main" {
  name              = local.glue_job_name
  role_arn          = aws_iam_role.glue.arn
  glue_version      = "4.0"
  number_of_workers = 2
  worker_type       = "G.1X"

  # Script must be uploaded to S3 before the job runs
  command {
    name            = "glueetl"
    script_location = "s3://${aws_s3_bucket.main.bucket}/glue/scripts/job.py"
    python_version  = "3"
  }

  default_arguments = {
    "--enable-metrics"                   = ""
    "--enable-continuous-cloudwatch-log" = "true"
    "--job-language"                     = "python"
    "--TempDir"                          = "s3://${aws_s3_bucket.main.bucket}/glue/tmp/"
  }

  security_configuration = aws_glue_security_configuration.main.name

  tags = local.common_tags
}
