variable "namespace" {
  description = "Kubernetes namespace where Prometheus and Grafana will be installed."
  type        = string
  default     = "monitoring"
}

variable "chart_version" {
  description = "Version of the kube-prometheus-stack Helm chart."
  type        = string
  default     = "65.5.0"
}

variable "grafana_admin_password" {
  description = "Admin password for Grafana. Pass via TF_VAR_grafana_admin_password."
  type        = string
  sensitive   = true
  default     = "admin"
}

variable "grafana_service_type" {
  description = "Kubernetes Service type for Grafana (ClusterIP for port-forward, LoadBalancer for public access)."
  type        = string
  default     = "ClusterIP"
}

variable "prometheus_retention" {
  description = "How long Prometheus keeps metrics (e.g. 7d, 15d)."
  type        = string
  default     = "7d"
}

variable "storage_class" {
  description = "Kubernetes StorageClass used for Prometheus / Grafana persistent volumes."
  type        = string
  default     = "gp2"
}

variable "prometheus_storage_size" {
  description = "Size of Prometheus persistent volume."
  type        = string
  default     = "10Gi"
}

variable "grafana_storage_size" {
  description = "Size of Grafana persistent volume."
  type        = string
  default     = "5Gi"
}
