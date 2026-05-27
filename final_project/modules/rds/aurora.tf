#-----------------------------------------------------------------
# Aurora cluster + writer/reader instances — created only when use_aurora = true.
#-----------------------------------------------------------------

resource "aws_rds_cluster" "this" {
  count = var.use_aurora ? 1 : 0

  cluster_identifier = var.name

  engine         = var.engine
  engine_version = var.engine_version
  port           = var.port

  database_name   = var.db_name
  master_username = var.username
  master_password = var.password

  db_subnet_group_name            = aws_db_subnet_group.this.name
  vpc_security_group_ids          = [aws_security_group.this.id]
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.this[0].name
  storage_encrypted               = true

  backup_retention_period   = var.backup_retention_period
  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.name}-final-snapshot"

  apply_immediately = true

  tags = merge(local.common_tags, {
    "Name" = var.name
  })
}

resource "aws_rds_cluster_instance" "this" {
  count = var.use_aurora ? var.aurora_instance_count : 0

  identifier         = "${var.name}-${count.index + 1}"
  cluster_identifier = aws_rds_cluster.this[0].id

  instance_class = var.instance_class
  engine         = aws_rds_cluster.this[0].engine
  engine_version = aws_rds_cluster.this[0].engine_version

  db_subnet_group_name    = aws_db_subnet_group.this.name
  db_parameter_group_name = aws_db_parameter_group.this.name
  publicly_accessible     = false

  apply_immediately = true

  tags = merge(local.common_tags, {
    "Name" = "${var.name}-${count.index + 1}"
    "Role" = count.index == 0 ? "writer" : "reader"
  })
}
