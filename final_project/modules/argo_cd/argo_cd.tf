resource "helm_release" "argo_cd" {
  name             = "argocd"
  namespace        = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "7.8.26"
  create_namespace = true

  values = [
    file("${path.module}/values.yaml")
  ]
}

resource "helm_release" "argo_cd_apps" {
  name      = "argocd-apps"
  namespace = "argocd"
  chart     = "${path.module}/charts"

  set {
    name  = "applications[0].name"
    value = "django-app"
  }

  set {
    name  = "applications[0].repoURL"
    value = var.git_repo_url
  }

  set {
    name  = "applications[0].targetRevision"
    value = var.git_target_revision
  }

  set {
    name  = "applications[0].chartPath"
    value = var.app_chart_path
  }

  set {
    name  = "applications[0].namespace"
    value = var.app_namespace
  }

  set {
    name  = "applications[0].syncPolicy"
    value = "automated"
  }

  depends_on = [
    helm_release.argo_cd
  ]
}

