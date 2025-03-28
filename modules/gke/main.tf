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

    labels = merge(var.labels, {
      "materialize.cloud/disk" = var.enable_disk_setup ? "true" : "false"
      "workload"               = "materialize-instance"
    })

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

# Install OpenEBS for local SSD support
resource "kubernetes_namespace" "openebs" {
  count = var.install_openebs ? 1 : 0

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

# Create a ConfigMap containing the disk setup script
resource "kubernetes_config_map" "disk_setup_script" {
  count = var.enable_disk_setup ? 1 : 0

  metadata {
    name      = "disk-setup-script"
    namespace = kubernetes_namespace.disk_setup[0].metadata[0].name
  }

  data = {
    "bootstrap.sh" = file("${path.module}/bootstrap.sh")
  }

  depends_on = [
    kubernetes_namespace.disk_setup
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

        # Use host network and PID namespace
        host_network = true
        host_pid     = true

        init_container {
          name  = "disk-setup"
          image = "debian:bullseye-slim"

          command = ["/bin/bash", "/scripts/bootstrap.sh"]

          resources {
            limits = {
              cpu    = "200m"
              memory = "256Mi"
            }
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
          }

          security_context {
            privileged  = true
            run_as_user = 0
          }

          env {
            name  = "SCRIPT_VERBOSE"
            value = "true"
          }

          # Mount all necessary host paths
          volume_mount {
            name       = "scripts"
            mount_path = "/scripts"
          }

          volume_mount {
            name       = "mnt"
            mount_path = "/mnt"
          }
        }

        container {
          name  = "pause"
          image = "gcr.io/google_containers/pause:3.2"

          resources {
            limits = {
              cpu    = "50m"
              memory = "64Mi"
            }
            requests = {
              cpu    = "10m"
              memory = "32Mi"
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
          name = "scripts"
          config_map {
            name         = kubernetes_config_map.disk_setup_script[0].metadata[0].name
            default_mode = "0755"
          }
        }

        volume {
          name = "mnt"
          host_path {
            path = "/mnt"
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_config_map.disk_setup_script
  ]
}
