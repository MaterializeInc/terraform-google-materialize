

locals {
  default_helm_values = {
    image = var.orchestratord_version == null ? {} : {
      tag = var.orchestratord_version
    },
    observability = {
      podMetrics = {
        enabled = true
      }
    }
    operator = {
      cloudProvider = {
        type   = "gcp"
        region = var.region
        providers = {
          gcp = {
            enabled = true
          }
        }
      }
    }
    storage = var.enable_disk_support ? {
      storageClass = {
        create      = local.disk_config.create_storage_class
        name        = local.disk_config.storage_class_name
        provisioner = local.disk_config.storage_class_provisioner
        parameters  = local.disk_config.storage_class_parameters
      }
    } : {}
    tls = var.use_self_signed_cluster_issuer ? {
      defaultCertificateSpecs = {
        balancerdExternal = {
          dnsNames = [
            "balancerd",
          ]
          issuerRef = {
            name = "${var.name_prefix}-root-ca"
            kind = "ClusterIssuer"
          }
        }
        consoleExternal = {
          dnsNames = [
            "console",
          ]
          issuerRef = {
            name = "${var.name_prefix}-root-ca"
            kind = "ClusterIssuer"
          }
        }
        internal = {
          issuerRef = {
            name = "${var.name_prefix}-root-ca"
            kind = "ClusterIssuer"
          }
        }
      }
    } : {}
  }

  # Requires OpenEBS to be installed
  disk_config = {
    create_storage_class      = var.enable_disk_support ? lookup(var.disk_support_config, "create_storage_class", true) : false
    storage_class_name        = lookup(var.disk_support_config, "storage_class_name", "openebs-lvm-instance-store-ext4")
    storage_class_provisioner = "local.csi.openebs.io"
    storage_class_parameters = {
      storage  = "lvm"
      fsType   = "ext4"
      volgroup = "instance-store-vg"
    }
  }
}

resource "kubernetes_namespace" "materialize" {
  metadata {
    name = var.operator_namespace
  }
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = var.monitoring_namespace
  }
}

resource "helm_release" "materialize_operator" {
	name      = var.name_prefix
	namespace = kubernetes_namespace.materialize.metadata[0].name

	repository = var.use_local_chart ? null : var.helm_repository
	chart      = var.helm_chart
	version    = var.use_local_chart ? null : var.operator_version

	values = [
		yamlencode(merge(local.default_helm_values, var.helm_values))
	]

	depends_on = [kubernetes_namespace.materialize]
}
  
# Install the metrics-server for monitoring
# Required for the Materialize Console to display cluster metrics
# Defaults to false because GKE provides metrics-server by default
# Enable this when metrics collection is disabled in the cluster
# https://cloud.google.com/kubernetes-engine/docs/how-to/configure-metrics
# TODO: we should rather rely on GKE metrics-server instead of installing our own, confirm with team
resource "helm_release" "metrics_server" {
count = var.install_metrics_server ? 1 : 0

name       = "${var.name_prefix}-metrics-server"
namespace  = kubernetes_namespace.monitoring.metadata[0].name
repository = "https://kubernetes-sigs.github.io/metrics-server/"
chart      = "metrics-server"
version    = var.metrics_server_version

# Common configuration values
set {
	name  = "args[0]"
	value = "--kubelet-insecure-tls"
}

set {
	name  = "metrics.enabled"
	value = "true"
}

depends_on = [
	kubernetes_namespace.monitoring
]
}