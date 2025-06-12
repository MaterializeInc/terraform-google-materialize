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
