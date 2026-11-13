# Integration tests: deploy real resources, check them, then destroy them.
# This costs money and needs cloud credentials.
# Run: tofu test -test-directory=tests/integration
# Test case catalog: tests/README.md

variables {
  name_prefix = "itest"
  advanced_settings = {
    tags = {
      Purpose = "integration-test"
    }
  }
}

# I-01
run "deploy" {
  command = apply

  assert {
    condition     = aws_db_instance.this.status == "available"
    error_message = "The DB instance is not available."
  }
}

# I-02, I-03
run "endpoint_is_private_and_secret_exists" {
  module {
    source = "./tests/integration/db-check"
  }

  variables {
    endpoint   = run.deploy.endpoint
    secret_arn = run.deploy.master_user_secret_arn
  }

  assert {
    condition     = length(output.addresses) > 0 && alltrue([for ip in output.addresses : cidrcontains("10.0.0.0/16", ip)])
    error_message = "The endpoint must resolve to private IPs inside the VPC."
  }

  assert {
    condition     = output.secret_arn == run.deploy.master_user_secret_arn
    error_message = "The master password secret does not exist."
  }
}
