variable "cluster_name" {
  description = "Назва Kubernetes кластера"
  type        = string
}

variable "git_repo_url" {
  description = "URL Git-репозиторію з Helm-чартом для Argo CD Application"
  type        = string
  default     = "https://github.com/kms-engineer/my-microservice-project.git"
}

variable "git_target_revision" {
  description = "Git branch або tag для Argo CD"
  type        = string
  default     = "lesson-8-9"
}

variable "app_chart_path" {
  description = "Шлях до Helm-чарта всередині Git-репозиторію"
  type        = string
  default     = "charts/django-app"
}

variable "app_namespace" {
  description = "Kubernetes namespace для деплою застосунку"
  type        = string
  default     = "django"
}
