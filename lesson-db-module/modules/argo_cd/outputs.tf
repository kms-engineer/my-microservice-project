output "argocd_release_name" {
  description = "The name of the Argo CD Helm release"
  value       = helm_release.argo_cd.name
}

output "argocd_namespace" {
  description = "The namespace where Argo CD is deployed"
  value       = helm_release.argo_cd.namespace
}
