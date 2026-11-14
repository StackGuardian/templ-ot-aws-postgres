locals {
  identifier = "${var.name_prefix}-postgres"
}

resource "aws_db_subnet_group" "this" {
  name       = local.identifier
  subnet_ids = aws_subnet.private[*].id
}

resource "aws_db_parameter_group" "this" {
  name   = local.identifier
  family = "postgres${split(".", var.advanced_settings.engine_version)[0]}"

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Created up front so the retention applies to the exported logs.
resource "aws_cloudwatch_log_group" "db" {
  #checkov:skip=CKV_AWS_338:Demo template, retention is configurable via advanced_settings.log_retention_days
  #checkov:skip=CKV_AWS_158:Encrypted with AWS-managed keys, customer-managed KMS is out of scope for the demo
  for_each = toset(["postgresql", "upgrade"])

  name              = "/aws/rds/instance/${local.identifier}/${each.key}"
  retention_in_days = var.advanced_settings.log_retention_days
}

resource "aws_iam_role" "monitoring" {
  name = "${var.name_prefix}-rds-monitoring"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "monitoring" {
  role       = aws_iam_role.monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

resource "aws_db_instance" "this" {
  #checkov:skip=CKV_AWS_157:Multi-AZ is configurable via advanced_settings.multi_az, off by default for cost
  #checkov:skip=CKV_AWS_293:Deletion protection is configurable, off by default so the demo can be destroyed
  #checkov:skip=CKV_AWS_353:Performance Insights is not available on the smallest instance classes
  identifier     = local.identifier
  engine         = "postgres"
  engine_version = var.advanced_settings.engine_version
  instance_class = var.advanced_settings.instance_class
  db_name        = var.advanced_settings.database_name
  username       = var.advanced_settings.master_username

  # Password is generated and rotated by RDS in Secrets Manager. It never appears in state.
  manage_master_user_password = true

  allocated_storage     = var.advanced_settings.allocated_storage
  max_allocated_storage = var.advanced_settings.allocated_storage * 2
  storage_type          = "gp3"
  storage_encrypted     = true

  db_subnet_group_name   = aws_db_subnet_group.this.name
  parameter_group_name   = aws_db_parameter_group.this.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false
  multi_az               = var.advanced_settings.multi_az

  iam_database_authentication_enabled = true
  auto_minor_version_upgrade          = true
  enabled_cloudwatch_logs_exports     = ["postgresql", "upgrade"]
  monitoring_interval                 = 60
  monitoring_role_arn                 = aws_iam_role.monitoring.arn

  # lookup() with the default as fallback: checkov cannot resolve optional object attributes
  # and would flag the backup policy (CKV_AWS_133). The key always exists, the type sets a default.
  backup_retention_period   = lookup(var.advanced_settings, "backup_retention_days", 7)
  copy_tags_to_snapshot     = true
  deletion_protection       = var.advanced_settings.deletion_protection
  skip_final_snapshot       = var.advanced_settings.skip_final_snapshot
  final_snapshot_identifier = var.advanced_settings.skip_final_snapshot ? null : "${local.identifier}-final"
  apply_immediately         = true

  depends_on = [aws_cloudwatch_log_group.db]
}
