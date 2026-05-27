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

#-------------Backend / shared infra-----------------

module "s3_backend" {
  source      = "./modules/s3-backend"
  bucket_name = "mykyta-terraform-state-bucket"
  table_name  = "terraform-locks"
}

module "vpc" {
  source             = "./modules/vpc"
  vpc_cidr_block     = "10.0.0.0/16"
  public_subnets     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnets    = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  availability_zones = ["us-west-2a", "us-west-2b", "us-west-2c"]
  vpc_name           = "lesson-db-module-vpc"
}

module "ecr" {
  source       = "./modules/ecr"
  ecr_name     = "lesson-db-module-ecr"
  scan_on_push = true
}

module "eks" {
  source        = "./modules/eks"
  cluster_name  = "eks-cluster-demo"
  subnet_ids    = module.vpc.public_subnets
  instance_type = "t3.small"
  desired_size  = 3
  max_size      = 4
  min_size      = 1
}

#-------------RDS / Aurora (universal module)-----------------
# Flip var.use_aurora to switch between a regular RDS instance and an Aurora cluster.
# All other variables stay the same.

module "rds" {
  source = "./modules/rds"

  name       = "lesson-db-module"
  use_aurora = var.use_aurora

  vpc_id              = module.vpc.vpc_id
  subnet_ids          = module.vpc.private_subnets
  allowed_cidr_blocks = ["10.0.0.0/16"]

  # When use_aurora = true — change engine to "aurora-postgresql" and family to "aurora-postgresql15"
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
    Environment = "lab"
    Lesson      = "db-module"
  }
}

#-------------Kubernetes providers-----------------

data "aws_eks_cluster" "eks" {
  name = module.eks.eks_cluster_name
}

data "aws_eks_cluster_auth" "eks" {
  name = module.eks.eks_cluster_name
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.eks.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.eks.token
  }
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.eks.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.eks.token
}

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
  git_target_revision = "lesson-db-module"
  app_chart_path      = "lesson-db-module/charts/django-app"
  app_namespace       = "django"

  providers = {
    helm       = helm
    kubernetes = kubernetes
  }
}
