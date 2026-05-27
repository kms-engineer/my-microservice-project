#-------------Backend-----------------

output "s3_bucket_name" {
  description = "Name of the S3 bucket for storing Terraform state files"
  value       = module.s3_backend.s3_bucket_name
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table for state locking"
  value       = module.s3_backend.dynamodb_table_name
}

#-------------VPC-----------------

output "vpc_id" {
  description = "ID of the created VPC"
  value       = module.vpc.vpc_id
}

output "public_subnets" {
  description = "List of public subnet IDs"
  value       = module.vpc.public_subnets
}

output "private_subnets" {
  description = "List of private subnet IDs"
  value       = module.vpc.private_subnets
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = module.vpc.internet_gateway_id
}

#-------------ECR-----------------

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = module.ecr.ecr_repository_url
}

#-------------EKS-----------------

output "eks_cluster_endpoint" {
  description = "EKS API endpoint for connecting to the cluster"
  value       = module.eks.eks_cluster_endpoint
}

output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.eks_cluster_name
}

output "eks_node_role_arn" {
  description = "IAM role ARN for EKS Worker Nodes"
  value       = module.eks.eks_node_role_arn
}

#-------------Jenkins-----------------

output "jenkins_release" {
  description = "Name of the Jenkins Helm release"
  value       = module.jenkins.jenkins_release_name
}

output "jenkins_namespace" {
  description = "Namespace of the Jenkins Helm release"
  value       = module.jenkins.jenkins_namespace
}

#-------------OIDC-----------------

output "oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider"
  value       = module.eks.oidc_provider_arn
}

output "oidc_provider_url" {
  description = "URL of the EKS OIDC provider"
  value       = module.eks.oidc_provider_url
}

#-------------Argo CD-----------------

output "argocd_release" {
  description = "Name of the Argo CD Helm release"
  value       = module.argo_cd.argocd_release_name
}

output "argocd_namespace" {
  description = "Namespace of the Argo CD Helm release"
  value       = module.argo_cd.argocd_namespace
}

#-------------RDS / Aurora-----------------

output "db_endpoint" {
  description = "Database writer endpoint (Aurora writer or RDS instance endpoint)"
  value       = module.rds.endpoint
}

output "db_reader_endpoint" {
  description = "Database reader endpoint (Aurora only, null for regular RDS)"
  value       = module.rds.reader_endpoint
}

output "db_port" {
  description = "Database port"
  value       = module.rds.port
}

output "db_name" {
  description = "Initial database name"
  value       = module.rds.db_name
}

output "db_username" {
  description = "Master username"
  value       = module.rds.username
}

output "db_security_group_id" {
  description = "Security group attached to the database"
  value       = module.rds.security_group_id
}

output "db_subnet_group_name" {
  description = "DB subnet group name"
  value       = module.rds.subnet_group_name
}

output "db_parameter_group_name" {
  description = "DB parameter group name"
  value       = module.rds.parameter_group_name
}

output "db_cluster_id" {
  description = "Aurora cluster identifier (null when use_aurora = false)"
  value       = module.rds.cluster_id
}

output "db_instance_id" {
  description = "RDS instance identifier (null when use_aurora = true)"
  value       = module.rds.instance_id
}

#-------------Monitoring-----------------

output "monitoring_namespace" {
  description = "Namespace where Prometheus and Grafana are installed"
  value       = module.monitoring.namespace
}

output "monitoring_release" {
  description = "Helm release name for kube-prometheus-stack"
  value       = module.monitoring.release_name
}

output "grafana_port_forward_cmd" {
  description = "Command to access Grafana locally"
  value       = module.monitoring.port_forward_grafana_cmd
}

output "prometheus_port_forward_cmd" {
  description = "Command to access Prometheus locally"
  value       = module.monitoring.port_forward_prometheus_cmd
}
