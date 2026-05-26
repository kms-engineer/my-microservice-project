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
