# ── Amazon Redshift Serverless — equivalent of Azure Synapse Analytics ─────────

resource "random_password" "redshift_admin" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "redshift_admin_password" {
  name       = "${local.secrets_prefix}/redshift-admin"
  kms_key_id = aws_kms_key.secrets.arn
  tags       = local.common_tags
}

resource "aws_secretsmanager_secret_version" "redshift_admin_password" {
  secret_id     = aws_secretsmanager_secret.redshift_admin_password.id
  secret_string = random_password.redshift_admin.result
}

resource "aws_kms_key" "redshift" {
  description             = "KMS key for Redshift Serverless namespace encryption"
  deletion_window_in_days = var.kms_deletion_window_days
  enable_key_rotation     = true
  tags                    = local.common_tags
}

resource "aws_kms_alias" "redshift" {
  name          = local.kms_alias_redshift
  target_key_id = aws_kms_key.redshift.key_id
}

# ── IAM role for Redshift — allows cross-service access (S3, Glue, etc.) ─────

resource "aws_iam_role" "redshift" {
  name = local.redshift_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "redshift.amazonaws.com" }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "redshift_s3_readonly" {
  role       = aws_iam_role.redshift.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

# ── Security group for Redshift Serverless workgroup ──────────────────────────

resource "aws_security_group" "redshift" {
  name        = "${local.prefix}-sg-redshift"
  description = "Security group for Redshift Serverless workgroup"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all egress"
  }

  tags = local.common_tags
}

# ── Redshift Serverless namespace + workgroup ─────────────────────────────────

resource "aws_redshiftserverless_namespace" "main" {
  namespace_name      = local.redshift_namespace_name
  admin_username      = var.redshift_admin_username
  admin_user_password = random_password.redshift_admin.result
  db_name             = "main"
  kms_key_id          = aws_kms_key.redshift.arn
  iam_roles           = [aws_iam_role.redshift.arn]

  tags = local.common_tags
}

resource "aws_redshiftserverless_workgroup" "main" {
  namespace_name = aws_redshiftserverless_namespace.main.namespace_name
  workgroup_name = local.redshift_workgroup_name
  base_capacity  = var.redshift_base_capacity_rpus

  publicly_accessible = false

  subnet_ids         = aws_subnet.system[*].id
  security_group_ids = [aws_security_group.redshift.id]

  tags = local.common_tags
}
