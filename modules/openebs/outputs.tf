output "openebs_namespace" {
  description = "The namespace where OpenEBS is installed"
  value       = var.install_openebs ? var.openebs_namespace : null
}

output "openebs_installed" {
  description = "Whether OpenEBS is installed"
  value       = var.install_openebs
}

output "helm_release_name" {
  description = "The name of the OpenEBS Helm release"
  value       = var.install_openebs ? helm_release.openebs[0].name : null
}

output "helm_release_version" {
  description = "The version of the installed OpenEBS Helm chart"
  value       = var.install_openebs ? var.openebs_version : null
}

output "helm_release_status" {
  description = "The status of the OpenEBS Helm release"
  value       = var.install_openebs ? helm_release.openebs[0].status : null
} 