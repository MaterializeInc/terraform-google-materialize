locals {
  # Map GCP taint effects to Kubernetes toleration effects
  taint_effect_map = {
    "NO_SCHEDULE"        = "NoSchedule"
    "NO_EXECUTE"         = "NoExecute"
    "PREFER_NO_SCHEDULE" = "PreferNoSchedule"
  }

  # Swap-specific taints that are automatically added when swap is enabled
  swap_taints = var.swap_enabled ? [
    {
      key    = "startup-taint.cluster-autoscaler.kubernetes.io/disk-unconfigured"
      value  = "true"
      effect = "NO_SCHEDULE"
    }
  ] : []

  # Combine user-specified taints with swap-related taints
  node_taints = concat(var.node_taints, local.swap_taints)

  node_labels = merge(
    var.labels,
    var.swap_enabled ? {
      "materialize.cloud/swap" = "true"
    } : {}
  )

  disk_setup_name = "${var.prefix}-disk-setup"

  disk_setup_labels = merge(
    var.labels,
    {
      "app" = local.disk_setup_name
    }
  )
}

resource "google_container_node_pool" "primary_nodes" {
  provider = google

  name     = "${var.prefix}-nodepool"
  location = var.region
  cluster  = var.cluster_name
  project  = var.project_id

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

    oauth_scopes = var.oauth_scopes

    local_nvme_ssd_block_config {
      local_ssd_count = var.local_ssd_count
    }

    workload_metadata_config {
      mode = var.workload_metadata_mode
    }

    linux_node_config {
      sysctls = {
        "vm.swappiness"             = "100",
        "vm.min_free_kbytes"        = "1048576",
        "vm.watermark_scale_factor" = "100",
      }
    }
  }

  lifecycle {
    create_before_destroy = true
    prevent_destroy       = false
  }
}


resource "kubernetes_namespace" "disk_setup" {
  count = var.swap_enabled ? 1 : 0

  metadata {
    name   = local.disk_setup_name
    labels = local.disk_setup_labels
  }

  depends_on = [
    google_container_node_pool.primary_nodes
  ]
}

resource "kubernetes_daemonset" "disk_setup" {
  count = var.swap_enabled ? 1 : 0
  depends_on = [
    kubernetes_namespace.disk_setup
  ]

  metadata {
    name      = local.disk_setup_name
    namespace = kubernetes_namespace.disk_setup[0].metadata[0].name
    labels    = local.disk_setup_labels
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
                  key      = "materialize.cloud/swap"
                  operator = "In"
                  values   = ["true"]
                }
              }
            }
          }
        }

        # Tolerate all taints (includes both user-provided and swap taints)
        dynamic "toleration" {
          for_each = local.node_taints
          content {
            key      = toleration.value.key
            operator = "Exists"
            effect   = lookup(local.taint_effect_map, toleration.value.effect, toleration.value.effect)
          }
        }

        # GKE adds a silly taint to prevent things from going to arm nodes.
        # Our image is multi-arch, so we can tolerate that taint.
        toleration {
          key      = "kubernetes.io/arch"
          operator = "Equal"
          value    = "arm64"
          effect   = "NoSchedule"
        }

        # Use host network and PID namespace
        host_network = true
        host_pid     = true

        init_container {
          name    = local.disk_setup_name
          image   = var.disk_setup_image
          command = ["ephemeral-storage-setup"]
          args = [
            "swap",
            "--cloud-provider",
            "gcp",
            "--taint-key",
            local.swap_taints[0].key,
            "--remove-taint",
            "--hack-restart-kubelet-enable-swap",
            "--apply-sysctls",
          ]
          resources {
            limits = {
              memory = var.disk_setup_container_resource_config.memory_limit
            }
            requests = {
              memory = var.disk_setup_container_resource_config.memory_request
              cpu    = var.disk_setup_container_resource_config.cpu_request
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

        container {
          name    = "pause"
          image   = var.disk_setup_image
          command = ["ephemeral-storage-setup"]
          args    = ["sleep"]

          resources {
            limits = {
              memory = var.pause_container_resource_config.memory_limit
            }
            requests = {
              memory = var.pause_container_resource_config.memory_request
              cpu    = var.pause_container_resource_config.cpu_request
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
  count = var.swap_enabled ? 1 : 0
  metadata {
    name      = local.disk_setup_name
    namespace = kubernetes_namespace.disk_setup[0].metadata[0].name
  }
}

resource "kubernetes_cluster_role" "disk_setup" {
  count = var.swap_enabled ? 1 : 0
  depends_on = [
    kubernetes_namespace.disk_setup
  ]
  metadata {
    name = local.disk_setup_name
  }
  rule {
    api_groups = [""]
    resources  = ["nodes"]
    verbs      = ["get", "patch", "update"]
  }
}

resource "kubernetes_cluster_role_binding" "disk_setup" {
  count = var.swap_enabled ? 1 : 0
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
