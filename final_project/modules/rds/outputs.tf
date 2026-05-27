#-------------Endpoint-----------------
# Single endpoint regardless of mode — caller does not need to know
# whether Aurora or a regular instance is behind it.

output "endpoint" {
  description = "Writer endpoint of the database (cluster writer for Aurora, instance endpoint for RDS)."
  value = var.use_aurora ? (
    length(aws_rds_cluster.this) > 0 ? aws_rds_cluster.this[0].endpoint : null
    ) : (
    length(aws_db_instance.this) > 0 ? aws_db_instance.this[0].endpoint : null
  )
}

output "reader_endpoint" {
  description = "Reader endpoint (Aurora only). null when use_aurora = false."
  value       = var.use_aurora && length(aws_rds_cluster.this) > 0 ? aws_rds_cluster.this[0].reader_endpoint : null
}

output "port" {
  description = "Port the database listens on."
  value       = var.port
}

output "db_name" {
  description = "Name of the initial database."
  value       = var.db_name
}

output "username" {
  description = "Master username."
  value       = var.username
}

#-------------Resource identifiers-----------------

output "instance_id" {
  description = "Identifier of the RDS instance (only when use_aurora = false)."
  value       = var.use_aurora ? null : (length(aws_db_instance.this) > 0 ? aws_db_instance.this[0].id : null)
}

output "cluster_id" {
  description = "Identifier of the Aurora cluster (only when use_aurora = true)."
  value       = var.use_aurora && length(aws_rds_cluster.this) > 0 ? aws_rds_cluster.this[0].id : null
}

output "cluster_arn" {
  description = "ARN of the Aurora cluster (only when use_aurora = true)."
  value       = var.use_aurora && length(aws_rds_cluster.this) > 0 ? aws_rds_cluster.this[0].arn : null
}

output "cluster_member_identifiers" {
  description = "List of cluster instance identifiers (Aurora only)."
  value       = aws_rds_cluster_instance.this[*].identifier
}

#-------------Shared resources-----------------

output "security_group_id" {
  description = "ID of the security group attached to the database."
  value       = aws_security_group.this.id
}

output "subnet_group_name" {
  description = "Name of the DB subnet group."
  value       = aws_db_subnet_group.this.name
}

output "parameter_group_name" {
  description = "Name of the instance-level DB parameter group."
  value       = aws_db_parameter_group.this.name
}

output "cluster_parameter_group_name" {
  description = "Name of the cluster parameter group (Aurora only)."
  value       = length(aws_rds_cluster_parameter_group.this) > 0 ? aws_rds_cluster_parameter_group.this[0].name : null
}
