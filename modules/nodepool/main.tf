locals {
  node_taints = var.enable_disk_setup ? [
    {
      key    = "disk-unconfigured"
      value  = "true"
      effect = "NO_SCHEDULE"
    }
  ] : []

  node_labels = merge(
    var.labels,
    {
      "materialize.cloud/disk" = var.enable_disk_setup ? "true" : "false"
      "workload"               = "materialize-instance"
    },
    var.enable_disk_setup ? {
      "materialize.cloud/disk-config-required" = "true"
    } : {}
  )

  disk_setup_name = "disk-setup"

  disk_setup_labels = merge(
    var.labels,
    {
      "app"                          = local.disk_setup_name
    }
  )
}

resource "google_container_node_pool" "primary_nodes" {
  provider = google

  name     = "${var.nodepool_name}"
  location = var.region
  cluster  = var.cluster_name
  project  = var.project_id

  node_count = var.node_count

  autoscaling {
    min_node_count = var.min_nodes
    max_node_count = var.max_nodes
  }

  network_config {
    enable_private_nodes = var.enable_private_nodes
  }

  node_config {
    machine_type = var.machine_type
    disk_size_gb = var.disk_size_gb

    labels = local.node_labels

    dynamic "taint" {
      for_each = local.node_taints
      content {
        key    = taint.value.key
        value  = taint.value.value
        effect = taint.value.effect
      }
    }

    service_account = var.service_account_email

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    local_nvme_ssd_block_config {
      local_ssd_count = var.local_ssd_count
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }

  lifecycle {
    create_before_destroy = true
    prevent_destroy       = false
  }
}


resource "kubernetes_namespace" "disk_setup" {
  count = var.enable_disk_setup ? 1 : 0

  metadata {
    name = local.disk_setup_name
    labels = local.disk_setup_labels
  }

  depends_on = [
    google_container_node_pool.primary_nodes
  ]
}

resource "kubernetes_daemonset" "disk_setup" {
  count = var.enable_disk_setup ? 1 : 0
  depends_on = [
    kubernetes_namespace.disk_setup
  ]

  metadata {
    name      = local.disk_setup_name
    namespace = kubernetes_namespace.disk_setup[0].metadata[0].name
    labels = local.disk_setup_labels
  }

  spec {
    selector {
      match_labels = {
        app = local.disk_setup_name
      }
    }

    template {
      metadata {
        labels = local.disk_setup_labels
      }

      spec {
        security_context {
          run_as_non_root = false
          run_as_user     = 0
          fs_group        = 0
          seccomp_profile {
            type = "RuntimeDefault"
          }
        }

        affinity {
          node_affinity {
            required_during_scheduling_ignored_during_execution {
              node_selector_term {
                match_expressions {
                  key      = "materialize.cloud/disk"
                  operator = "In"
                  values   = ["true"]
                }
              }
            }
          }
        }

        toleration {
          key      = local.node_taints[0].key
          operator = "Exists"
          effect   = "NoSchedule"
        }

        # Use host network and PID namespace
        host_network = true
        host_pid     = true

        init_container {
          name    = local.disk_setup_name
          image   = var.disk_setup_image
          command = ["/usr/local/bin/configure-disks.sh"]
          args    = ["--cloud-provider", "gcp"]
          resources {
            limits = {
              memory = "128Mi"
            }
            requests = {
              memory = "128Mi"
              cpu    = "50m"
            }
          }

          security_context {
            privileged  = true
            run_as_user = 0
          }

          env {
            name = "NODE_NAME"
            value_from {
              field_ref {
                field_path = "spec.nodeName"
              }
            }
          }

          volume_mount {
            name       = "dev"
            mount_path = "/dev"
          }

          volume_mount {
            name       = "host-root"
            mount_path = "/host"
          }

        }

        init_container {
          name    = "taint-removal"
          image   = var.disk_setup_image
          command = ["/usr/local/bin/remove-taint.sh"]
          resources {
            limits = {
              memory = "64Mi"
            }
            requests = {
              memory = "64Mi"
              cpu    = "10m"
            }
          }
          security_context {
            run_as_user = 0
          }
          env {
            name = "NODE_NAME"
            value_from {
              field_ref {
                field_path = "spec.nodeName"
              }
            }
          }
        }

        container {
          name  = "pause"
          image = "gcr.io/google_containers/pause:3.2"

          resources {
            limits = {
              memory = "8Mi"
            }
            requests = {
              memory = "8Mi"
              cpu    = "1m"
            }
          }

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
            run_as_non_root            = true
            run_as_user                = 65534
          }

        }

        volume {
          name = "dev"
          host_path {
            path = "/dev"
          }
        }

        volume {
          name = "host-root"
          host_path {
            path = "/"
          }
        }

        service_account_name = kubernetes_service_account.disk_setup[0].metadata[0].name
      }
    }
  }
}

resource "kubernetes_service_account" "disk_setup" {
  count = var.enable_disk_setup ? 1 : 0
  depends_on = [
    kubernetes_namespace.disk_setup
  ]
  metadata {
    name      = local.disk_setup_name
    namespace = kubernetes_namespace.disk_setup[0].metadata[0].name
  }
}

resource "kubernetes_cluster_role" "disk_setup" {
  count = var.enable_disk_setup ? 1 : 0
  depends_on = [
    kubernetes_namespace.disk_setup
  ]
  metadata {
    name = local.disk_setup_name
  }
  rule {
    api_groups = [""]
    resources  = ["nodes"]
    verbs      = ["get", "patch"]
  }
}

resource "kubernetes_cluster_role_binding" "disk_setup" {
  count = var.enable_disk_setup ? 1 : 0
  metadata {
    name = local.disk_setup_name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.disk_setup[0].metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.disk_setup[0].metadata[0].name
    namespace = kubernetes_namespace.disk_setup[0].metadata[0].name
  }
}
