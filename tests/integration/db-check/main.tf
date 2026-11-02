# Helper for the integration test: resolves the endpoint and reads the secret metadata (not the value).
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    dns = {
      source = "hashicorp/dns"
    }
  }
}

variable "endpoint" {
  type = string
}

variable "secret_arn" {
  type = string
}

data "dns_a_record_set" "endpoint" {
  host = var.endpoint
}

data "aws_secretsmanager_secret" "master" {
  arn = var.secret_arn
}

output "addresses" {
  value = data.dns_a_record_set.endpoint.addrs
}

output "secret_arn" {
  value = data.aws_secretsmanager_secret.master.arn
}
