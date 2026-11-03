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

variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "Must be a valid IPv4 CIDR block."
  }
}

variable "engine_version" {
  description = "PostgreSQL major version"
  type        = string
  default     = "17"
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t4g.micro"
}

variable "allocated_storage" {
  description = "Storage in GiB"
  type        = number
  default     = 20
}

variable "database_name" {
  description = "Name of the initial database"
  type        = string
  default     = "app"
}

variable "master_username" {
  description = "Master user name. The password is generated and stored in Secrets Manager."
  type        = string
  default     = "dbadmin"
}

variable "multi_az" {
  description = "Run a standby in a second AZ"
  type        = bool
  default     = false
}

variable "backup_retention_days" {
  description = "Days to keep automated backups"
  type        = number
  default     = 7

  validation {
    condition     = var.backup_retention_days >= 1
    error_message = "Automated backups must be enabled (at least 1 day)."
  }
}

variable "deletion_protection" {
  description = "Protect the instance from deletion. Off by default so the demo can be destroyed."
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "Skip the final snapshot on destroy"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "Retention of database and flow logs in CloudWatch"
  type        = number
  default     = 90

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "CloudWatch Logs accepts only fixed retention values, for example 30, 90 or 365."
  }
}
