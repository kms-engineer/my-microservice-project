terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = "us-west-2"
}

#-------------Root variables-----------------

variable "db_password" {
  description = "Master password for the database. Pass via TF_VAR_db_password env var."
  type        = string
  sensitive   = true
}

variable "use_aurora" {
  description = "Toggle between Aurora cluster (true) and regular RDS instance (false)."
  type        = bool
  default     = false
}

variable "grafana_admin_password" {
  description = "Admin password for Grafana. Pass via TF_VAR_grafana_admin_password."
  type        = string
  sensitive   = true
  default     = "admin"
}

#-------------Backend / shared infra-----------------

module "s3_backend" {
  source      = "./modules/s3-backend"
  bucket_name = "mykyta-final-project-state"
  table_name  = "final-project-locks"
}

module "vpc" {
  source             = "./modules/vpc"
  vpc_cidr_block     = "10.0.0.0/16"
  public_subnets     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnets    = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  availability_zones = ["us-west-2a", "us-west-2b", "us-west-2c"]
  vpc_name           = "final-project-vpc"
}

module "ecr" {
  source       = "./modules/ecr"
  ecr_name     = "final-project-ecr"
  scan_on_push = true
}

module "eks" {
  source        = "./modules/eks"
  cluster_name  = "final-project-eks"
  subnet_ids    = module.vpc.public_subnets
  instance_type = "t3.small" # Free Tier compatible (t3.medium blocked on Free Tier accounts)
  desired_size  = 4           # 4 nodes needed: 3 wasn't enough for Prometheus+ArgoCD+Jenkins+Django
  max_size      = 6
  min_size      = 3
}

#-------------RDS / Aurora (universal module from lesson-db-module)-----------------

module "rds" {
  source = "./modules/rds"

  name       = "final-project-db"
  use_aurora = var.use_aurora

  vpc_id              = module.vpc.vpc_id
  subnet_ids          = module.vpc.private_subnets
  allowed_cidr_blocks = ["10.0.0.0/16"]

  engine         = var.use_aurora ? "aurora-postgresql" : "postgres"
  engine_version = var.use_aurora ? "15.4" : "15.18"
  family         = var.use_aurora ? "aurora-postgresql15" : "postgres15"
  port           = 5432

  instance_class        = "db.t3.micro"
  allocated_storage     = 20
  storage_type          = "gp3"
  multi_az              = false
  aurora_instance_count = 1

  db_name  = "appdb"
  username = "dbadmin"
  password = var.db_password

  backup_retention_period = 0 # Free Tier allows max 0 days
  deletion_protection     = false
  skip_final_snapshot     = true

  parameter_group_parameters = {
    max_connections = "100"
    log_statement   = "all"
    work_mem        = "4096"
  }

  tags = {
    Environment = "production"
    Project     = "final-project"
  }
}

#-------------Kubernetes providers-----------------
# Using exec-based auth instead of data sources so that providers are
# configured from module.eks outputs (resolved AFTER the cluster is created),
# not from data sources that fail on the first plan.

provider "helm" {
  kubernetes {
    host                   = module.eks.eks_cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.eks_cluster_certificate_authority)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.eks_cluster_name, "--region", "us-west-2"]
    }
  }
}

provider "kubernetes" {
  host                   = module.eks.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.eks_cluster_certificate_authority)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.eks_cluster_name, "--region", "us-west-2"]
  }
}

#-------------CI/CD-----------------

module "jenkins" {
  source            = "./modules/jenkins"
  cluster_name      = module.eks.eks_cluster_name
  kubeconfig        = "~/.kube/config"
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url

  providers = {
    helm       = helm
    kubernetes = kubernetes
  }
}

module "argo_cd" {
  source              = "./modules/argo_cd"
  cluster_name        = module.eks.eks_cluster_name
  git_repo_url        = "https://github.com/kms-engineer/my-microservice-project.git"
  git_target_revision = "final_project"
  app_chart_path      = "final_project/charts/django-app"
  app_namespace       = "django"

  providers = {
    helm       = helm
    kubernetes = kubernetes
  }
}

#-------------Monitoring (Prometheus + Grafana)-----------------

module "monitoring" {
  source = "./modules/monitoring"

  namespace              = "monitoring"
  chart_version          = "65.5.0"
  grafana_admin_password = var.grafana_admin_password
  grafana_service_type   = "ClusterIP"
  prometheus_retention   = "7d"
  storage_class          = "gp2"

  providers = {
    helm       = helm
    kubernetes = kubernetes
  }

  depends_on = [module.eks]
}
