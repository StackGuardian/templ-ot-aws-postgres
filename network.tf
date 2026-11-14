data "aws_availability_zones" "available" {
  #checkov:skip=CKV_AWS_394:Only the first two zones are used
  state = "available"
}

resource "aws_vpc" "this" {
  cidr_block           = var.advanced_settings.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${var.name_prefix}-vpc" }
}

# Remove all rules from the default security group.
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id
}

# Private subnets only, no internet gateway. RDS needs subnets in two AZs.
resource "aws_subnet" "private" {
  count = 2

  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.advanced_settings.vpc_cidr, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false

  tags = { Name = "${var.name_prefix}-private-${count.index}" }
}

resource "aws_security_group" "db" {
  name        = "${var.name_prefix}-postgres"
  description = "PostgreSQL from inside the VPC"
  vpc_id      = aws_vpc.this.id
}

resource "aws_vpc_security_group_ingress_rule" "db" {
  security_group_id = aws_security_group.db.id
  description       = "PostgreSQL from the VPC"
  cidr_ipv4         = var.advanced_settings.vpc_cidr
  ip_protocol       = "tcp"
  from_port         = 5432
  to_port           = 5432
}

# VPC flow logs
#trivy:ignore:AVD-AWS-0017 Encrypted with AWS-managed keys, customer-managed KMS is out of scope for the demo
resource "aws_cloudwatch_log_group" "flow_logs" {
  #checkov:skip=CKV_AWS_338:Demo template, retention is configurable via advanced_settings.log_retention_days
  #checkov:skip=CKV_AWS_158:Encrypted with AWS-managed keys, customer-managed KMS is out of scope for the demo
  name              = "/${var.name_prefix}/vpc-flow-logs"
  retention_in_days = var.advanced_settings.log_retention_days
}

resource "aws_iam_role" "flow_logs" {
  name = "${var.name_prefix}-vpc-flow-logs"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "flow_logs" {
  name = "write-flow-logs"
  role = aws_iam_role.flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams",
      ]
      Resource = "${aws_cloudwatch_log_group.flow_logs.arn}:*"
    }]
  })
}

resource "aws_flow_log" "this" {
  vpc_id          = aws_vpc.this.id
  traffic_type    = "ALL"
  log_destination = aws_cloudwatch_log_group.flow_logs.arn
  iam_role_arn    = aws_iam_role.flow_logs.arn
}
