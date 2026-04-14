# ---------------------------------------------------------------------------
# AWS Data Lifecycle Manager — snapshots automáticos do EBS
#
# Captura snapshot de todos os volumes da instância Name=savewithme-ec2
# a cada 24h (02:00 UTC), retendo os últimos 7.
# Tags nos snapshots: Name=savewithme-db-snapshot, ManagedBy=dlm
# ---------------------------------------------------------------------------

resource "aws_iam_role" "dlm" {
  name = "${var.app_name}-dlm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "dlm.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Name = "${var.app_name}-dlm-role" }
}

resource "aws_iam_role_policy" "dlm" {
  name = "dlm-ec2-snapshots"
  role = aws_iam_role.dlm.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateSnapshot",
          "ec2:CreateSnapshots",
          "ec2:DeleteSnapshot",
          "ec2:DescribeInstances",
          "ec2:DescribeVolumes",
          "ec2:DescribeSnapshots",
          "ec2:DescribeInstanceStatus",
          "ec2:EnableFastSnapshotRestores",
          "ec2:DescribeFastSnapshotRestores",
          "ec2:DisableFastSnapshotRestores",
          "ec2:CopySnapshot",
          "ec2:ModifySnapshotAttribute",
          "ec2:DescribeSnapshotAttribute"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["ec2:CreateTags"]
        Resource = "arn:aws:ec2:*::snapshot/*"
      }
    ]
  })
}

resource "aws_dlm_lifecycle_policy" "ebs_snapshots" {
  description        = "Daily EBS snapshots for ${var.app_name} - 7 retained"
  execution_role_arn = aws_iam_role.dlm.arn
  state              = "ENABLED"

  policy_details {
    resource_types = ["INSTANCE"]

    target_tags = {
      Name = "${var.app_name}-ec2"
    }

    schedule {
      name = "daily-7-retained"

      create_rule {
        interval      = 24
        interval_unit = "HOURS"
        times         = ["02:00"]
      }

      retain_rule {
        count = 7
      }

      tags_to_add = {
        Name      = "${var.app_name}-db-snapshot"
        ManagedBy = "dlm"
      }

      copy_tags = false
    }
  }

  tags = { Name = "${var.app_name}-dlm-policy" }
}
