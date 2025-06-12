resource "google_compute_network" "vpc" {
  name                    = "${var.prefix}-network"
  auto_create_subnetworks = false
  project                 = var.project_id
  mtu                     = 1460 # Optimized for GKE

  lifecycle {
    create_before_destroy = true
    prevent_destroy       = false
  }
}


resource "google_compute_route" "default_route" {
  name             = "${var.prefix}-default-route"
  project          = var.project_id
  network          = google_compute_network.vpc.name
  dest_range       = "0.0.0.0/0"
  priority         = 1000
  next_hop_gateway = "default-internet-gateway"

  # Ensure this is destroyed before the network
  depends_on = [google_compute_network.vpc]

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_subnetwork" "subnet" {
  name          = "${var.prefix}-subnet"
  project       = var.project_id
  network       = google_compute_network.vpc.id
  ip_cidr_range = var.subnet_cidr
  region        = var.region

  private_ip_google_access = true
  purpose                  = "PRIVATE"

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.pods_cidr
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.services_cidr
  }

  lifecycle {
    create_before_destroy = true
  }

}

# Cloud Router for NAT Gateway
resource "google_compute_router" "router" {
  name    = "${var.prefix}-router"
  project = var.project_id
  region  = var.region
  network = google_compute_network.vpc.name

  bgp {
    asn = 64514
  }
}

# Cloud NAT for outbound internet access from private nodes
resource "google_compute_router_nat" "nat" {
  name                               = "${var.prefix}-nat"
  project                            = var.project_id
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_global_address" "private_ip_address" {
  provider      = google
  project       = var.project_id
  name          = "${var.prefix}-private-ip"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.id

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_service_networking_connection" "private_vpc_connection" {
  provider                = google
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]

  lifecycle {
    create_before_destroy = true
  }

  deletion_policy = "ABANDON"
}
