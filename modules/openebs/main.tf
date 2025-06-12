

resource "kubernetes_namespace" "openebs" {
  count = var.install_openebs && var.create_namespace ? 1 : 0

  metadata {
    name = var.openebs_namespace
  }
}

resource "helm_release" "openebs" {
  count = var.install_openebs ? 1 : 0

  name       = "openebs"
  namespace  = var.openebs_namespace
  repository = "https://openebs.github.io/openebs"
  chart      = "openebs"
  version    = var.openebs_version

  set {
    name  = "engines.replicated.mayastor.enabled"
    value = "false"
  }

  # Unable to continue with install: CustomResourceDefinition "volumesnapshotclasses.snapshot.storage.k8s.io"
  # in namespace "" exists and cannot be imported into the current release
  # https://github.com/openebs/website/pull/506
  set {
    name  = "openebs-crds.csi.volumeSnapshots.enabled"
    value = "false"
  }

  depends_on = [
    kubernetes_namespace.openebs
  ]
}
