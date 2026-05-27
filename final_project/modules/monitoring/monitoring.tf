resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = var.namespace
    labels = {
      "managed-by" = "terraform"
      "purpose"    = "monitoring"
    }
  }
}

resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.chart_version
  namespace  = kubernetes_namespace.monitoring.metadata[0].name

  values = [
    templatefile("${path.module}/values.yaml", {
      grafana_admin_password  = var.grafana_admin_password
      grafana_service_type    = var.grafana_service_type
      storage_class           = var.storage_class
      grafana_storage_size    = var.grafana_storage_size
      prometheus_retention    = var.prometheus_retention
      prometheus_storage_size = var.prometheus_storage_size
    })
  ]

  # Kube-prometheus-stack ships with large CRDs — give Helm enough time.
  timeout = 900
  wait    = true

  depends_on = [kubernetes_namespace.monitoring]
}
