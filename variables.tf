variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
  default     = "demo"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,15}$", var.name_prefix))
    error_message = "Use 2-16 lowercase letters, digits or hyphens, starting with a letter."
  }
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

# Grouped so the StackGuardian form can show them in one "Advanced Settings" section.
variable "advanced_settings" {
  description = "Settings most deployments keep at their defaults"
  type = object({
    vpc_cidr              = optional(string, "10.0.0.0/16")  # CIDR block of the VPC
    engine_version        = optional(string, "17")           # PostgreSQL major version
    instance_class        = optional(string, "db.t4g.micro") # RDS instance class
    allocated_storage     = optional(number, 20)             # Storage in GiB, autoscaling up to twice the size
    database_name         = optional(string, "app")          # Name of the initial database
    master_username       = optional(string, "dbadmin")      # Master user name. The password is generated and stored in Secrets Manager.
    multi_az              = optional(bool, false)            # Run a standby in a second AZ
    backup_retention_days = optional(number, 7)              # Days to keep automated backups
    deletion_protection   = optional(bool, false)            # Protect the instance from deletion. Off by default so the demo can be destroyed.
    skip_final_snapshot   = optional(bool, true)             # Skip the final snapshot on destroy
    log_retention_days    = optional(number, 90)             # Retention of database and flow logs in CloudWatch
    tags                  = optional(map(string), {})        # Additional tags for all resources
  })
  default  = {}
  nullable = false

  validation {
    condition     = can(cidrnetmask(var.advanced_settings.vpc_cidr))
    error_message = "Must be a valid IPv4 CIDR block."
  }

  validation {
    condition     = var.advanced_settings.backup_retention_days >= 1
    error_message = "Automated backups must be enabled (at least 1 day)."
  }

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.advanced_settings.log_retention_days)
    error_message = "CloudWatch Logs accepts only fixed retention values, for example 30, 90 or 365."
  }
}
