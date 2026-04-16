# ── KMS Keys — equivalent of Azure Key Vault keys + Disk Encryption Set ───────
# All keys have rotation enabled (CKV_AWS_7) and a configurable deletion window.

# EKS secrets encryption key — equivalent of Azure DES key
resource "aws_kms_key" "eks" {
  description             = "KMS key for EKS secrets encryption — ${local.prefix}"
  deletion_window_in_days = var.kms_deletion_window_days
  enable_key_rotation     = true # CKV_AWS_7
  multi_region            = false

  policy = data.aws_iam_policy_document.kms_eks.json
}

resource "aws_kms_alias" "eks" {
  name          = local.kms_alias_eks
  target_key_id = aws_kms_key.eks.key_id
}

# S3 CMK — equivalent of Azure storage CMK key
resource "aws_kms_key" "s3" {
  description             = "KMS key for S3 bucket encryption — ${local.prefix}"
  deletion_window_in_days = var.kms_deletion_window_days
  enable_key_rotation     = true # CKV_AWS_7
  multi_region            = false

  policy = data.aws_iam_policy_document.kms_s3.json
}

resource "aws_kms_alias" "s3" {
  name          = local.kms_alias_s3
  target_key_id = aws_kms_key.s3.key_id
}

# Secrets Manager CMK — equivalent of Key Vault key for secret encryption
resource "aws_kms_key" "secrets" {
  description             = "KMS key for Secrets Manager encryption — ${local.prefix}"
  deletion_window_in_days = var.kms_deletion_window_days
  enable_key_rotation     = true # CKV_AWS_7
  multi_region            = false

  policy = data.aws_iam_policy_document.kms_secrets.json
}

resource "aws_kms_alias" "secrets" {
  name          = local.kms_alias_secrets
  target_key_id = aws_kms_key.secrets.key_id
}

# ── KMS Key Policies ──────────────────────────────────────────────────────────

data "aws_iam_policy_document" "kms_eks" {
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
    sid    = "AllowEKSServiceEncryption"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey",
      "kms:DescribeKey",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AllowCloudWatchLogs"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["logs.${data.aws_region.current.name}.amazonaws.com"]
    }
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "kms_s3" {
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
    sid    = "AllowS3ServiceEncryption"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
    actions = [
      "kms:GenerateDataKey",
      "kms:Decrypt",
      "kms:DescribeKey",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AllowEKSNodeRoleS3Access"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.eks_node.arn]
    }
    actions = [
      "kms:GenerateDataKey",
      "kms:Decrypt",
      "kms:DescribeKey",
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "kms_secrets" {
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
    sid    = "AllowSecretsManagerEncryption"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["secretsmanager.amazonaws.com"]
    }
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey",
      "kms:DescribeKey",
    ]
    resources = ["*"]
  }
}
