# ---------------------------------------------------------------------------
# Schedule de liga/desliga da instância EC2
#
# Stop:  cron(0 15 * * ? *) UTC = 12:00 BRT → AWS-StopEC2Instance (SSM Automation)
# Start: cron(0 10 * * ? *) UTC = 07:00 BRT → AWS-StartEC2Instance (SSM Automation)
#
# Sem Lambda — usa SSM Automation documents nativos da AWS via EventBridge.
# ---------------------------------------------------------------------------

# ── IAM: EventBridge → SSM Automation ────────────────────────────────────────

resource "aws_iam_role" "eventbridge_ssm" {
  name = "${var.app_name}-eventbridge-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Name = "${var.app_name}-eventbridge-ssm-role" }
}

resource "aws_iam_role_policy" "eventbridge_ssm" {
  name = "ssm-automation-trigger"
  role = aws_iam_role.eventbridge_ssm.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "ssm:StartAutomationExecution"
        Resource = [
          "arn:aws:ssm:${var.aws_region}::automation-definition/AWS-StopEC2Instance:*",
          "arn:aws:ssm:${var.aws_region}::automation-definition/AWS-StartEC2Instance:*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = aws_iam_role.ssm_automation_ec2.arn
      }
    ]
  })
}

# ── IAM: SSM Automation → EC2 ────────────────────────────────────────────────

resource "aws_iam_role" "ssm_automation_ec2" {
  name = "${var.app_name}-ssm-automation-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ssm.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Name = "${var.app_name}-ssm-automation-ec2-role" }
}

resource "aws_iam_role_policy" "ssm_automation_ec2" {
  name = "ec2-start-stop"
  role = aws_iam_role.ssm_automation_ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ec2:StopInstances",
        "ec2:StartInstances",
        "ec2:DescribeInstances",
        "ec2:DescribeInstanceStatus"
      ]
      Resource = "*"
    }]
  })
}

# ── EventBridge Rules ─────────────────────────────────────────────────────────

resource "aws_cloudwatch_event_rule" "stop_ec2" {
  name                = "${var.app_name}-stop-ec2"
  description         = "Para o EC2 às 15:00 UTC (12:00 BRT)"
  schedule_expression = "cron(0 15 * * ? *)"
}

resource "aws_cloudwatch_event_rule" "start_ec2" {
  name                = "${var.app_name}-start-ec2"
  description         = "Liga o EC2 às 10:00 UTC (07:00 BRT)"
  schedule_expression = "cron(0 10 * * ? *)"
}

# ── EventBridge Targets → SSM Automation ─────────────────────────────────────

resource "aws_cloudwatch_event_target" "stop_ec2" {
  rule     = aws_cloudwatch_event_rule.stop_ec2.name
  arn      = "arn:aws:ssm:${var.aws_region}::automation-definition/AWS-StopEC2Instance:$DEFAULT"
  role_arn = aws_iam_role.eventbridge_ssm.arn

  input = jsonencode({
    InstanceId           = [aws_instance.app.id]
    AutomationAssumeRole = aws_iam_role.ssm_automation_ec2.arn
  })
}

resource "aws_cloudwatch_event_target" "start_ec2" {
  rule     = aws_cloudwatch_event_rule.start_ec2.name
  arn      = "arn:aws:ssm:${var.aws_region}::automation-definition/AWS-StartEC2Instance:$DEFAULT"
  role_arn = aws_iam_role.eventbridge_ssm.arn

  input = jsonencode({
    InstanceId           = [aws_instance.app.id]
    AutomationAssumeRole = aws_iam_role.ssm_automation_ec2.arn
  })
}
