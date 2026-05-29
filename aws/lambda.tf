# ── AWS Lambda — equivalent of Azure Function App ─────────────────────────────

# Minimal placeholder source — replace with real application code via CI/CD
data "archive_file" "lambda_source" {
  type        = "zip"
  output_path = "${path.module}/.build/lambda.zip"

  source {
    content  = "def handler(event, context):\n    return {'statusCode': 200, 'body': 'OK'}\n"
    filename = "main.py"
  }
}

resource "aws_kms_key" "lambda" {
  description             = "KMS key for Lambda environment variable encryption"
  deletion_window_in_days = var.kms_deletion_window_days
  enable_key_rotation     = true
  tags                    = local.common_tags
}

resource "aws_kms_alias" "lambda" {
  name          = local.kms_alias_lambda
  target_key_id = aws_kms_key.lambda.key_id
}

# ── IAM execution role ────────────────────────────────────────────────────────

resource "aws_iam_role" "lambda" {
  name = local.lambda_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_kms" {
  name = "${local.lambda_role_name}-kms"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["kms:Decrypt", "kms:GenerateDataKey"]
      Resource = aws_kms_key.lambda.arn
    }]
  })
}

# ── CloudWatch Log Group — pre-create to control retention and encryption ──────

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${local.lambda_function_name}"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.lambda.arn
  tags              = local.common_tags
}

# ── Lambda function ───────────────────────────────────────────────────────────

resource "aws_lambda_function" "main" {
  function_name    = local.lambda_function_name
  role             = aws_iam_role.lambda.arn
  runtime          = var.lambda_runtime
  handler          = "main.handler"
  filename         = data.archive_file.lambda_source.output_path
  source_code_hash = data.archive_file.lambda_source.output_base64sha256
  memory_size      = var.lambda_memory_size
  timeout          = var.lambda_timeout

  # CKV_AWS_120: encrypt environment variables with a customer-managed KMS key
  kms_key_arn = aws_kms_key.lambda.arn

  environment {
    variables = {
      ENVIRONMENT = var.environment
    }
  }

  # CKV_AWS_50: enable X-Ray active tracing
  tracing_config {
    mode = "Active"
  }

  depends_on = [aws_cloudwatch_log_group.lambda]

  tags = local.common_tags
}
