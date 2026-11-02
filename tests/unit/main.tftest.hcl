# Unit tests: plan only, providers are mocked. No cloud account, no cost.
# Run: tofu test -test-directory=tests/unit
# Test case catalog: tests/README.md

mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["eu-central-1a", "eu-central-1b"]
    }
  }

  # Some arguments are validated as ARNs, so mocked values must look like ARNs.
  mock_resource "aws_cloudwatch_log_group" {
    defaults = {
      arn = "arn:aws:logs:eu-central-1:123456789012:log-group:mock"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/mock"
    }
  }

  mock_resource "aws_db_instance" {
    defaults = {
      master_user_secret = [{
        secret_arn    = "arn:aws:secretsmanager:eu-central-1:123456789012:secret:rds-mock"
        secret_status = "active"
        kms_key_id    = ""
      }]
    }
  }
}

# U-01
run "defaults_are_valid" {
  command = plan

  assert {
    condition = (
      local.tags["Environment"] == "demo" &&
      local.tags["ManagedBy"] == "opentofu" &&
      local.tags["Project"] == var.name_prefix &&
      local.tags["Repository"] != ""
    )
    error_message = "Default tags are missing or wrong."
  }
}

# U-02
run "invalid_name_prefix_is_rejected" {
  command = plan

  variables {
    name_prefix = "Invalid_Prefix"
  }

  expect_failures = [var.name_prefix]
}

# U-03
run "custom_tags_are_merged" {
  command = plan

  variables {
    tags = {
      Owner = "tester"
    }
  }

  assert {
    condition     = local.tags["Owner"] == "tester" && local.tags["ManagedBy"] == "opentofu"
    error_message = "Custom tags are not merged with the default tags."
  }
}

# U-04
run "database_is_not_public" {
  command = apply

  assert {
    condition     = !aws_db_instance.this.publicly_accessible
    error_message = "The database must not be publicly accessible."
  }

  assert {
    condition     = alltrue([for r in [aws_vpc_security_group_ingress_rule.db] : r.cidr_ipv4 == var.vpc_cidr && r.from_port == 5432 && r.to_port == 5432])
    error_message = "Port 5432 must be open only to the VPC."
  }
}

# U-05
run "storage_is_encrypted" {
  command = apply

  assert {
    condition     = aws_db_instance.this.storage_encrypted
    error_message = "Storage encryption must be enabled."
  }
}

# U-06
run "password_is_managed_by_secrets_manager" {
  command = apply

  assert {
    condition     = aws_db_instance.this.manage_master_user_password && aws_db_instance.this.password == null
    error_message = "The master password must be managed by Secrets Manager, not set in code."
  }

  assert {
    condition     = startswith(output.master_user_secret_arn, "arn:aws:secretsmanager:")
    error_message = "The secret ARN must be an output."
  }
}

# U-07
run "ssl_is_enforced" {
  command = apply

  assert {
    condition     = contains([for p in aws_db_parameter_group.this.parameter : "${p.name}=${p.value}"], "rds.force_ssl=1")
    error_message = "The parameter group must set rds.force_ssl = 1."
  }

  assert {
    condition     = aws_db_parameter_group.this.family == "postgres17" && aws_db_instance.this.parameter_group_name == aws_db_parameter_group.this.name
    error_message = "The instance must use the parameter group for its major version."
  }
}

# U-08
run "backups_are_enabled" {
  command = apply

  assert {
    condition     = aws_db_instance.this.backup_retention_period >= 1
    error_message = "Automated backups must be enabled."
  }
}

# U-09
run "backups_cannot_be_disabled" {
  command = plan

  variables {
    backup_retention_days = 0
  }

  expect_failures = [var.backup_retention_days]
}

# U-10
run "subnets_are_private" {
  command = apply

  assert {
    condition = (
      aws_db_subnet_group.this.subnet_ids == toset(aws_subnet.private[*].id) &&
      length(distinct(aws_subnet.private[*].availability_zone)) == 2 &&
      alltrue([for s in aws_subnet.private : !s.map_public_ip_on_launch])
    )
    error_message = "The database must use two private subnets."
  }
}

# U-11
run "logging_and_monitoring_are_enabled" {
  command = apply

  assert {
    condition     = toset(aws_db_instance.this.enabled_cloudwatch_logs_exports) == toset(["postgresql", "upgrade"])
    error_message = "PostgreSQL logs must be exported to CloudWatch."
  }

  assert {
    condition     = aws_db_instance.this.monitoring_interval > 0
    error_message = "Enhanced monitoring must be enabled."
  }

  assert {
    condition     = aws_flow_log.this.traffic_type == "ALL"
    error_message = "VPC flow logs must capture all traffic."
  }
}
