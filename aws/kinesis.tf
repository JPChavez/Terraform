# ── Amazon Kinesis Data Streams — equivalent of Azure Event Hub ───────────────

resource "aws_kms_key" "kinesis" {
  description             = "KMS key for Kinesis Data Stream server-side encryption"
  deletion_window_in_days = var.kms_deletion_window_days
  enable_key_rotation     = true
  tags                    = local.common_tags
}

resource "aws_kms_alias" "kinesis" {
  name          = local.kms_alias_kinesis
  target_key_id = aws_kms_key.kinesis.key_id
}

resource "aws_kinesis_stream" "main" {
  name             = local.kinesis_stream_name
  shard_count      = var.kinesis_shard_count
  retention_period = var.kinesis_retention_period

  # CKV_AWS_43: encrypt data at rest with a customer-managed KMS key
  encryption_type = "KMS"
  kms_key_id      = aws_kms_key.kinesis.id

  stream_mode_details {
    stream_mode = "PROVISIONED"
  }

  tags = local.common_tags
}
