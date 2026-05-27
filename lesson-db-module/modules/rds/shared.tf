#-----------------------------------------------------------------
# Shared resources — created for both regular RDS and Aurora.
# DB Subnet Group, Security Group, Parameter Group(s).
#-----------------------------------------------------------------

locals {
  # Distinguish parameter group resource type:
  # Aurora uses aws_rds_cluster_parameter_group (cluster-wide) AND
  # aws_db_parameter_group (per-instance), while a regular RDS instance
  # only uses aws_db_parameter_group.
  is_aurora = var.use_aurora

  # Merge user-provided tags with module defaults.
  common_tags = merge(
    {
      "Name"      = var.name
      "ManagedBy" = "terraform"
      "Module"    = "rds"
    },
    var.tags
  )
}

#-------------DB Subnet Group-----------------

resource "aws_db_subnet_group" "this" {
  name        = "${var.name}-subnet-group"
  description = "Subnet group for ${var.name}"
  subnet_ids  = var.subnet_ids

  tags = merge(local.common_tags, {
    "Name" = "${var.name}-subnet-group"
  })
}

#-------------Security Group-----------------

resource "aws_security_group" "this" {
  name        = "${var.name}-sg"
  description = "Security group for ${var.name} database"
  vpc_id      = var.vpc_id

  ingress {
    description = "DB port from allowed CIDR blocks"
    from_port   = var.port
    to_port     = var.port
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    "Name" = "${var.name}-sg"
  })
}

#-------------DB Parameter Group (instance-level)-----------------
# Applied to every aws_db_instance and every aws_rds_cluster_instance.

resource "aws_db_parameter_group" "this" {
  name        = "${var.name}-pg"
  family      = var.family
  description = "Instance parameter group for ${var.name}"

  dynamic "parameter" {
    for_each = var.parameter_group_parameters
    content {
      name         = parameter.key
      value        = parameter.value
      apply_method = "pending-reboot"
    }
  }

  tags = local.common_tags

  lifecycle {
    create_before_destroy = true
  }
}

#-------------Cluster Parameter Group (Aurora only)-----------------
# Aurora additionally needs a cluster-level parameter group.

resource "aws_rds_cluster_parameter_group" "this" {
  count = local.is_aurora ? 1 : 0

  name        = "${var.name}-cluster-pg"
  family      = var.family
  description = "Cluster parameter group for ${var.name}"

  dynamic "parameter" {
    for_each = var.parameter_group_parameters
    content {
      name         = parameter.key
      value        = parameter.value
      apply_method = "pending-reboot"
    }
  }

  tags = local.common_tags

  lifecycle {
    create_before_destroy = true
  }
}
