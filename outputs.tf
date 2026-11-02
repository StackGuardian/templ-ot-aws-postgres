output "endpoint" {
  description = "Host name of the database"
  value       = aws_db_instance.this.address
}

output "port" {
  description = "Port of the database"
  value       = aws_db_instance.this.port
}

output "database_name" {
  description = "Name of the initial database"
  value       = aws_db_instance.this.db_name
}

output "master_username" {
  description = "Master user name"
  value       = aws_db_instance.this.username
}

output "master_user_secret_arn" {
  description = "ARN of the Secrets Manager secret with the master password"
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
}

output "vpc_id" {
  description = "ID of the VPC, for clients that need to reach the database"
  value       = aws_vpc.this.id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}
