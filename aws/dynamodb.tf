# ── Amazon DynamoDB — equivalent of Azure Cosmos DB ───────────────────────────

resource "aws_kms_key" "dynamodb" {
  description             = "KMS key for DynamoDB table server-side encryption"
  deletion_window_in_days = var.kms_deletion_window_days
  enable_key_rotation     = true
  tags                    = local.common_tags
}

resource "aws_kms_alias" "dynamodb" {
  name          = local.kms_alias_dynamodb
  target_key_id = aws_kms_key.dynamodb.key_id
}

resource "aws_dynamodb_table" "main" {
  name         = local.dynamodb_table_name
  billing_mode = var.dynamodb_billing_mode
  hash_key     = var.dynamodb_hash_key

  attribute {
    name = var.dynamodb_hash_key
    type = "S"
  }

  # CKV_AWS_28: customer-managed KMS key encryption
  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.dynamodb.arn
  }

  # CKV_AWS_133: point-in-time recovery for data durability
  point_in_time_recovery {
    enabled = true
  }

  tags = local.common_tags
}
