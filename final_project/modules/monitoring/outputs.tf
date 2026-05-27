output "namespace" {
  description = "Kubernetes namespace where monitoring stack is installed."
  value       = kubernetes_namespace.monitoring.metadata[0].name
}

output "release_name" {
  description = "Name of the kube-prometheus-stack Helm release."
  value       = helm_release.kube_prometheus_stack.name
}

output "release_version" {
  description = "Version of the deployed Helm chart."
  value       = helm_release.kube_prometheus_stack.version
}

output "grafana_service" {
  description = "Kubernetes service name for Grafana (use with kubectl port-forward)."
  value       = "kube-prometheus-stack-grafana"
}

output "prometheus_service" {
  description = "Kubernetes service name for Prometheus."
  value       = "kube-prometheus-stack-prometheus"
}

output "port_forward_grafana_cmd" {
  description = "Ready-to-use kubectl port-forward command for Grafana UI."
  value       = "kubectl port-forward svc/kube-prometheus-stack-grafana 3000:80 -n ${kubernetes_namespace.monitoring.metadata[0].name}"
}

output "port_forward_prometheus_cmd" {
  description = "Ready-to-use kubectl port-forward command for Prometheus UI."
  value       = "kubectl port-forward svc/kube-prometheus-stack-prometheus 9090:9090 -n ${kubernetes_namespace.monitoring.metadata[0].name}"
}
