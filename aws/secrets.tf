# ── Secrets Manager — equivalent of Azure Key Vault ──────────────────────────
# Secrets Manager stores application secrets; KMS keys (kms.tf) are the
# equivalent of Key Vault keys used for disk/storage encryption.

# Application secrets store
resource "aws_secretsmanager_secret" "app" {
  name        = "${local.secrets_prefix}/app"
  description = "Application secrets for ${var.project} ${var.environment}"

  # CKV_AWS_149: encrypt with CMK
  kms_key_id = aws_kms_key.secrets.arn

  # Retain secret for 30 days after deletion — equivalent of KV soft-delete retention
  recovery_window_in_days = 30

  tags = { Name = "${local.secrets_prefix}/app" }
}

# Initial placeholder version — prevents checkov CKV2_AWS_57 rotation warning
# by documenting that rotation config should be added per application requirement.
# Unlike Azure KV where rotation is set on the key, AWS rotation requires a
# Lambda function. Wire up aws_secretsmanager_secret_rotation separately once
# the rotation Lambda is deployed.

# Infrastructure secrets store (e.g. database passwords, API keys)
resource "aws_secretsmanager_secret" "infra" {
  name        = "${local.secrets_prefix}/infra"
  description = "Infrastructure secrets for ${var.project} ${var.environment}"

  # CKV_AWS_149: encrypt with CMK
  kms_key_id = aws_kms_key.secrets.arn

  recovery_window_in_days = 30

  tags = { Name = "${local.secrets_prefix}/infra" }
}

# ── IAM Policy — grant EKS workloads read access to secrets (via IRSA) ────────
# Attach this policy to IRSA roles for pods that need secret access.
# Equivalent of Azure "Key Vault Secrets User" role assignment for AKS.

resource "aws_iam_policy" "secrets_reader" {
  name        = "${var.project_acronym}-policy-secrets-reader-${var.environment}"
  description = "Allow reading Secrets Manager secrets for ${var.project} ${var.environment}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowGetSecretValue"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
        ]
        Resource = [
          aws_secretsmanager_secret.app.arn,
          aws_secretsmanager_secret.infra.arn,
        ]
      },
      {
        Sid    = "AllowKMSDecrypt"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
        ]
        Resource = aws_kms_key.secrets.arn
      }
    ]
  })
}
