# ---------------------------------------------------------------------------
# pg_dump diário para S3
#
# Bucket: savewithme-db-backups-<account_id>
# - objetos em daily/ expiram após 30 dias
# - versionamento desabilitado
#
# IAM: EC2 role recebe permissão s3:PutObject neste bucket
#
# SSM: State Manager association instala cron no EC2 que executa pg_dump
# todo dia às 05:00 UTC (02:00 BRT / GMT-3) e faz upload para S3.
# ---------------------------------------------------------------------------

locals {
  backup_bucket_name = "${var.app_name}-db-backups-${data.aws_caller_identity.current.account_id}"

  # Script instalado em /usr/local/bin/pg-dump-backup.sh via SSM.
  # O nome do bucket é embutido em tempo de apply (Terraform interpolation).
  pg_dump_script = <<-SCRIPT
    #!/bin/bash
    set -e
    DATE=$(date -u +%Y-%m-%d)
    CONTAINER=$(docker ps --filter "name=postgres" --format "{{.Names}}" | head -1)
    if [ -z "$CONTAINER" ]; then
      echo "$(date -u) No postgres container found, skipping backup" >&2
      exit 0
    fi
    docker exec "$CONTAINER" pg_dump -U postgres --no-password \
      | gzip \
      | aws s3 cp - "s3://${local.backup_bucket_name}/daily/$DATE.sql.gz"
    echo "$(date -u) Backup OK: s3://${local.backup_bucket_name}/daily/$DATE.sql.gz"
  SCRIPT
}

# ── S3 Bucket ────────────────────────────────────────────────────────────────

resource "aws_s3_bucket" "db_backups" {
  bucket        = local.backup_bucket_name
  force_destroy = true

  tags = { Name = local.backup_bucket_name }
}

resource "aws_s3_bucket_public_access_block" "db_backups" {
  bucket = aws_s3_bucket.db_backups.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "db_backups" {
  bucket = aws_s3_bucket.db_backups.id

  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "db_backups" {
  bucket = aws_s3_bucket.db_backups.id

  rule {
    id     = "expire-daily-backups"
    status = "Enabled"

    filter {
      prefix = "daily/"
    }

    expiration {
      days = 30
    }
  }
}

# ── IAM: permite EC2 gravar no bucket ────────────────────────────────────────

resource "aws_iam_policy" "ec2_s3_backup" {
  name        = "${var.app_name}-ec2-s3-backup"
  description = "Allow EC2 to write pg_dump backups to S3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:PutObject"]
      Resource = "${aws_s3_bucket.db_backups.arn}/daily/*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_s3_backup" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = aws_iam_policy.ec2_s3_backup.arn
}

# ── SSM: instala o cron de backup no EC2 ─────────────────────────────────────

resource "aws_ssm_document" "pg_dump_cron" {
  name          = "${var.app_name}-pg-dump-cron"
  document_type = "Command"

  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Install pg_dump daily S3 backup cron on ${var.app_name} EC2"
    mainSteps = [{
      action = "aws:runShellScript"
      name   = "installPgDumpCron"
      inputs = {
        runCommand = [
          "#!/bin/bash",
          "set -e",
          # Escreve o script de backup decodificando base64 para evitar problemas
          # de escaping em shell-dentro-de-JSON-dentro-de-HCL.
          "echo '${base64encode(local.pg_dump_script)}' | base64 -d > /usr/local/bin/pg-dump-backup.sh",
          "chmod +x /usr/local/bin/pg-dump-backup.sh",
          # Cron: 05:00 UTC = 02:00 BRT (UTC-3)
          "echo '0 5 * * * root /usr/local/bin/pg-dump-backup.sh >> /var/log/pg-dump-backup.log 2>&1' > /etc/cron.d/pg-dump-backup",
          "chmod 644 /etc/cron.d/pg-dump-backup",
          "echo 'pg-dump backup cron instalado com sucesso'"
        ]
      }
    }]
  })
}

# Aplica o documento a toda instância com tag Name=savewithme-ec2.
# Roda na criação e semanalmente para garantir idempotência.
resource "aws_ssm_association" "pg_dump_cron" {
  name = aws_ssm_document.pg_dump_cron.name

  targets {
    key    = "tag:Name"
    values = ["${var.app_name}-ec2"]
  }

  schedule_expression    = "rate(7 days)"
  apply_only_at_cron_interval = false
}
