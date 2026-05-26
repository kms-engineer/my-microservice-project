output "jenkins_release_name" {
  description = "The name of the Helm release"
  value       = helm_release.jenkins.name
}

output "jenkins_namespace" {
  description = "The namespace of the Helm release"
  value       = helm_release.jenkins.namespace
}
