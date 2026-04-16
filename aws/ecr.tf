# ── ECR Repository — equivalent of Azure Container Registry (ACR) ─────────────

resource "aws_ecr_repository" "main" {
  name                 = local.ecr_name
  image_tag_mutability = "IMMUTABLE" # CKV_AWS_51: prevent tag overwriting

  # CKV_AWS_163: scan images on push
  image_scanning_configuration {
    scan_on_push = true
  }

  # CKV_AWS_136: encrypt images with KMS CMK
  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.s3.arn
  }

  tags = { Name = local.ecr_name }
}

# ── ECR Lifecycle Policy — equivalent of ACR retention policy ─────────────────
# Keeps the last N tagged images and removes untagged images after 1 day.

resource "aws_ecr_lifecycle_policy" "main" {
  repository = aws_ecr_repository.main.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Remove untagged images after 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep only the last ${var.ecr_image_retention_count} tagged images"
        selection = {
          tagStatus   = "tagged"
          tagPrefixList = ["v"]
          countType   = "imageCountMoreThan"
          countNumber = var.ecr_image_retention_count
        }
        action = { type = "expire" }
      }
    ]
  })
}

# ── ECR Repository Policy — restrict pull access to this account only ─────────

resource "aws_ecr_repository_policy" "main" {
  repository = aws_ecr_repository.main.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEKSNodePull"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.eks_node.arn
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
        ]
      },
      {
        Sid    = "DenyPublicAccess"
        Effect = "Deny"
        Principal = "*"
        Action    = "ecr:*"
        Condition = {
          StringNotEquals = {
            "aws:PrincipalAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}
