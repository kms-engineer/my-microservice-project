#-------------General-----------------

variable "name" {
  description = "Base name used as a prefix for all DB-related resources (subnet group, SG, parameter group, instance/cluster)."
  type        = string
}

variable "use_aurora" {
  description = "If true — create an Aurora cluster (aws_rds_cluster + aws_rds_cluster_instance). If false — create a single aws_db_instance."
  type        = bool
  default     = false
}

#-------------Networking-----------------

variable "vpc_id" {
  description = "ID of the VPC where the database will be created."
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the DB Subnet Group (must be in at least two AZs)."
  type        = list(string)
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks that are allowed to connect to the database port."
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

#-------------Engine-----------------

variable "engine" {
  description = "Database engine. For regular RDS use 'postgres' or 'mysql'. For Aurora use 'aurora-postgresql' or 'aurora-mysql'."
  type        = string
  default     = "postgres"
}

variable "engine_version" {
  description = "Engine version (e.g. '15.7' for postgres, '8.0' for mysql, '15.4' for aurora-postgresql)."
  type        = string
  default     = "15.7"
}

variable "family" {
  description = "Parameter group family (e.g. 'postgres15', 'mysql8.0', 'aurora-postgresql15', 'aurora-mysql8.0')."
  type        = string
  default     = "postgres15"
}

variable "port" {
  description = "Port the database listens on. Defaults to 5432 for postgres engines, 3306 for mysql engines."
  type        = number
  default     = 5432
}

#-------------Instance sizing-----------------

variable "instance_class" {
  description = "DB instance class (e.g. 'db.t3.micro', 'db.t3.small', 'db.r6g.large')."
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Allocated storage in GB. Only used for regular RDS (use_aurora = false). Aurora storage is auto-scaled."
  type        = number
  default     = 20
}

variable "storage_type" {
  description = "Storage type for regular RDS: 'gp2', 'gp3', 'io1'. Ignored for Aurora."
  type        = string
  default     = "gp3"
}

variable "multi_az" {
  description = "Enable Multi-AZ deployment. For regular RDS — creates standby replica. For Aurora — pass the number of cluster instances via aurora_instance_count instead."
  type        = bool
  default     = false
}

variable "aurora_instance_count" {
  description = "Number of instances in the Aurora cluster (writer + readers). Only used when use_aurora = true."
  type        = number
  default     = 1
}

#-------------Credentials-----------------

variable "db_name" {
  description = "Name of the initial database to create."
  type        = string
  default     = "appdb"
}

variable "username" {
  description = "Master username for the database."
  type        = string
  default     = "dbadmin"
}

variable "password" {
  description = "Master password for the database. Should be passed via TF_VAR_password or a secret manager, not hardcoded."
  type        = string
  sensitive   = true
}

#-------------Backups & maintenance-----------------

variable "backup_retention_period" {
  description = "Number of days to keep automated backups (0-35)."
  type        = number
  default     = 7
}

variable "deletion_protection" {
  description = "If true — the database cannot be deleted. Set to false for lab environments."
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "If true — no final snapshot is created on deletion. Convenient for labs, dangerous for prod."
  type        = bool
  default     = true
}

#-------------Parameter group-----------------

variable "parameter_group_parameters" {
  description = "Map of DB parameters applied via the parameter group (max_connections, log_statement, work_mem, etc.). Keys are parameter names, values are strings."
  type        = map(string)
  default = {
    max_connections = "100"
    log_statement   = "all"
    work_mem        = "4096"
  }
}

#-------------Tags-----------------

variable "tags" {
  description = "Additional tags applied to all module resources."
  type        = map(string)
  default     = {}
}
