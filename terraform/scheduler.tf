# ---------------------------------------------------------------------------
# Schedule de liga/desliga da instância EC2
#
# Stop:  cron(0 15 * * ? *) UTC = 12:00 BRT
# Start: cron(0 10 * * ? *) UTC = 07:00 BRT
#
# SSM Automation Documents customizados resolvem o ID da instância por tag
# Name=savewithme-ec2 em runtime — sem ID fixo no EventBridge target.
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
          "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:automation-definition/${aws_ssm_document.stop_ec2_by_tag.name}:*",
          "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:automation-definition/${aws_ssm_document.start_ec2_by_tag.name}:*"
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
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:StopInstances",
          "ec2:StartInstances"
        ]
        # Resource "*" necessário: o document resolve o ID por tag em runtime,
        # não é possível restringir a uma ARN estática no momento do apply.
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceStatus"
        ]
        Resource = "*"
      }
    ]
  })
}

# ── SSM Automation Documents (tag-based, sem ID fixo) ────────────────────────

resource "aws_ssm_document" "stop_ec2_by_tag" {
  name          = "${var.app_name}-stop-ec2-by-tag"
  document_type = "Automation"

  content = jsonencode({
    schemaVersion = "0.3"
    description   = "Stop EC2 instances tagged Name=${var.app_name}-ec2"
    assumeRole    = "{{ AutomationAssumeRole }}"
    parameters = {
      AutomationAssumeRole = {
        type        = "String"
        description = "IAM role ARN with EC2 stop permissions"
      }
    }
    mainSteps = [
      {
        name   = "getRunningInstances"
        action = "aws:executeAwsApi"
        inputs = {
          Service = "ec2"
          Api     = "DescribeInstances"
          Filters = [
            { Name = "tag:Name", Values = ["${var.app_name}-ec2"] },
            { Name = "instance-state-name", Values = ["running"] }
          ]
        }
        outputs = [
          {
            Name     = "InstanceIds"
            Selector = "$.Reservations[*].Instances[*].InstanceId"
            Type     = "StringList"
          }
        ]
      },
      {
        name      = "stopInstances"
        action    = "aws:changeInstanceState"
        onFailure = "Continue"
        inputs = {
          InstanceIds  = "{{ getRunningInstances.InstanceIds }}"
          DesiredState = "stopped"
        }
      }
    ]
  })
}

resource "aws_ssm_document" "start_ec2_by_tag" {
  name          = "${var.app_name}-start-ec2-by-tag"
  document_type = "Automation"

  content = jsonencode({
    schemaVersion = "0.3"
    description   = "Start EC2 instances tagged Name=${var.app_name}-ec2"
    assumeRole    = "{{ AutomationAssumeRole }}"
    parameters = {
      AutomationAssumeRole = {
        type        = "String"
        description = "IAM role ARN with EC2 start permissions"
      }
    }
    mainSteps = [
      {
        name   = "getStoppedInstances"
        action = "aws:executeAwsApi"
        inputs = {
          Service = "ec2"
          Api     = "DescribeInstances"
          Filters = [
            { Name = "tag:Name", Values = ["${var.app_name}-ec2"] },
            { Name = "instance-state-name", Values = ["stopped"] }
          ]
        }
        outputs = [
          {
            Name     = "InstanceIds"
            Selector = "$.Reservations[*].Instances[*].InstanceId"
            Type     = "StringList"
          }
        ]
      },
      {
        name      = "startInstances"
        action    = "aws:changeInstanceState"
        onFailure = "Continue"
        inputs = {
          InstanceIds  = "{{ getStoppedInstances.InstanceIds }}"
          DesiredState = "running"
        }
      }
    ]
  })
}

# ── EventBridge Rules ─────────────────────────────────────────────────────────

resource "aws_cloudwatch_event_rule" "stop_ec2" {
  name                = "${var.app_name}-stop-ec2"
  description         = "Para o EC2 às 15:00 UTC (12:00 BRT)"
  schedule_expression = "cron(0 15 * * ? *)"
  is_enabled          = true
}

resource "aws_cloudwatch_event_rule" "start_ec2" {
  name                = "${var.app_name}-start-ec2"
  description         = "Liga o EC2 às 10:00 UTC (07:00 BRT)"
  schedule_expression = "cron(0 10 * * ? *)"
  is_enabled          = true
}

# ── EventBridge Targets → SSM Automation ─────────────────────────────────────

resource "aws_cloudwatch_event_target" "stop_ec2" {
  rule     = aws_cloudwatch_event_rule.stop_ec2.name
  arn      = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:automation-definition/${aws_ssm_document.stop_ec2_by_tag.name}:$DEFAULT"
  role_arn = aws_iam_role.eventbridge_ssm.arn

  input = jsonencode({
    AutomationAssumeRole = aws_iam_role.ssm_automation_ec2.arn
  })
}

resource "aws_cloudwatch_event_target" "start_ec2" {
  rule     = aws_cloudwatch_event_rule.start_ec2.name
  arn      = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:automation-definition/${aws_ssm_document.start_ec2_by_tag.name}:$DEFAULT"
  role_arn = aws_iam_role.eventbridge_ssm.arn

  input = jsonencode({
    AutomationAssumeRole = aws_iam_role.ssm_automation_ec2.arn
  })
}
