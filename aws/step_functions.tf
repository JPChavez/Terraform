# ── AWS Step Functions — equivalent of Azure Logic Apps ───────────────────────

resource "aws_cloudwatch_log_group" "step_functions" {
  name              = "/aws/states/${local.sfn_state_machine_name}"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.secrets.arn
  tags              = local.common_tags
}

resource "aws_iam_role" "step_functions" {
  name = local.sfn_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "states.amazonaws.com" }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "step_functions_logging" {
  name = "${local.sfn_role_name}-logging"
  role = aws_iam_role.step_functions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogDelivery",
        "logs:GetLogDelivery",
        "logs:UpdateLogDelivery",
        "logs:DeleteLogDelivery",
        "logs:ListLogDeliveries",
        "logs:PutResourcePolicy",
        "logs:DescribeResourcePolicies",
        "logs:DescribeLogGroups"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_sfn_state_machine" "main" {
  name     = local.sfn_state_machine_name
  role_arn = aws_iam_role.step_functions.arn
  type     = "STANDARD"

  # Minimal placeholder definition — update with real workflow states via CI/CD
  definition = jsonencode({
    Comment = "JProject ${var.environment} state machine"
    StartAt = "Pass"
    States = {
      Pass = {
        Type   = "Pass"
        Result = { status = "ok" }
        End    = true
      }
    }
  })

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.step_functions.arn}:*"
    include_execution_data = false
    level                  = "ERROR"
  }

  tags = local.common_tags
}
