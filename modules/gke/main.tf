locals {
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

  node_taints = var.enable_disk_setup ? [
    {
      key    = "disk-unconfigured"
      value  = "true"
      effect = "NO_SCHEDULE"
    }
  ] : []
}

resource "google_service_account" "gke_sa" {
  project      = var.project_id
  account_id   = "${var.prefix}-gke-sa"
  display_name = "GKE Service Account for Materialize"
}

resource "google_service_account" "workload_identity_sa" {
  project      = var.project_id
  account_id   = "${var.prefix}-materialize-sa"
  display_name = "Materialize Workload Identity Service Account"
}

resource "google_container_cluster" "primary" {
  provider = google

  deletion_protection = false

  depends_on = [
    google_service_account.gke_sa,
    google_service_account.workload_identity_sa,
  ]

  name     = "${var.prefix}-gke"
  location = var.region
  project  = var.project_id

  networking_mode = "VPC_NATIVE"
  network         = var.network_name
  subnetwork      = var.subnet_name

  remove_default_node_pool = true
  initial_node_count       = 1

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  release_channel {
    channel = "REGULAR"
  }

  addons_config {
    horizontal_pod_autoscaling {
      disabled = false
    }
    http_load_balancing {
      disabled = false
    }
    gce_persistent_disk_csi_driver_config {
      enabled = true
    }
  }
}

resource "google_container_node_pool" "primary_nodes" {
  provider = google

  name     = "${var.prefix}-node-pool"
  location = var.region
  cluster  = google_container_cluster.primary.name
  project  = var.project_id

  node_count = var.node_count

  autoscaling {
    min_node_count = var.min_nodes
    max_node_count = var.max_nodes
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

    service_account = google_service_account.gke_sa.email

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

resource "google_service_account_iam_binding" "workload_identity" {
  depends_on = [
    google_service_account.workload_identity_sa,
    google_container_cluster.primary
  ]
  service_account_id = google_service_account.workload_identity_sa.name
  role               = "roles/iam.workloadIdentityUser"
  members = [
    "serviceAccount:${var.project_id}.svc.id.goog[${var.namespace}/orchestratord]"
  ]
}

resource "kubernetes_namespace" "openebs" {
  count = var.install_openebs ? 1 : 0

  metadata {
    name = var.openebs_namespace
  }

  depends_on = [
    google_container_cluster.primary,
    google_container_node_pool.primary_nodes
  ]
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
    google_container_cluster.primary,
    google_container_node_pool.primary_nodes,
    kubernetes_namespace.openebs
  ]
}

resource "kubernetes_namespace" "disk_setup" {
  count = var.enable_disk_setup ? 1 : 0

  metadata {
    name = "disk-setup"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "materialize"
    }
  }

  depends_on = [
    google_container_node_pool.primary_nodes
  ]
}

resource "kubernetes_daemonset" "disk_setup" {
  count = var.enable_disk_setup ? 1 : 0

  metadata {
    name      = "disk-setup"
    namespace = kubernetes_namespace.disk_setup[0].metadata[0].name
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "materialize"
      "app"                          = "disk-setup"
    }
  }

  spec {
    selector {
      match_labels = {
        app = "disk-setup"
      }
    }

    template {
      metadata {
        labels = {
          app = "disk-setup"
        }
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
          key      = "disk-unconfigured"
          operator = "Exists"
          effect   = "NoSchedule"
        }

        # Use host network and PID namespace
        host_network = true
        host_pid     = true

        init_container {
          name    = "disk-setup"
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
  metadata {
    name      = "disk-setup"
    namespace = kubernetes_namespace.disk_setup[0].metadata[0].name
  }
}

resource "kubernetes_cluster_role" "disk_setup" {
  count = var.enable_disk_setup ? 1 : 0
  metadata {
    name = "disk-setup"
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
    name = "disk-setup"
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
