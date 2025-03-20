terraform {
  required_version = ">= 1.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Configure kubernetes provider with GKE cluster credentials
data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = "https://${module.materialize.gke_cluster.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(module.materialize.gke_cluster.ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = "https://${module.materialize.gke_cluster.endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(module.materialize.gke_cluster.ca_certificate)
  }
}

module "materialize" {
  # Referencing the root module directory:
  source = "../.."

  # Alternatively, you can use the GitHub source URL:
  # source = "github.com/MaterializeInc/terraform-google-materialize?ref=v0.1.0"

  project_id = var.project_id
  region     = var.region
  prefix     = var.prefix

  network_config = {
    subnet_cidr   = "10.0.0.0/20"
    pods_cidr     = "10.48.0.0/14"
    services_cidr = "10.52.0.0/20"
  }

  database_config = {
    tier     = "db-custom-2-4096"
    version  = "POSTGRES_15"
    password = random_password.pass.result
  }

  labels = {
    environment = "simple"
    example     = "true"
  }

  install_materialize_operator = true

  operator_version      = var.operator_version
  orchestratord_version = var.orchestratord_version

  # Once the operator is installed, you can define your Materialize instances here.
  materialize_instances = var.materialize_instances

  providers = {
    google     = google
    kubernetes = kubernetes
    helm       = helm
  }
}

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "prefix" {
  description = "Used to prefix the names of the resources"
  type        = string
  default     = "mz-simple"
}

resource "random_password" "pass" {
  length  = 20
  special = false
}

output "gke_cluster" {
  description = "GKE cluster details"
  value       = module.materialize.gke_cluster
  sensitive   = true
}

output "service_accounts" {
  description = "Service account details"
  value       = module.materialize.service_accounts
}

output "connection_strings" {
  description = "Connection strings for metadata and persistence backends"
  value       = module.materialize.connection_strings
  sensitive   = true
}

variable "operator_version" {
  description = "Version of the Materialize operator to install"
  type        = string
  default     = null
}

output "network" {
  description = "Network details"
  value       = module.materialize.network
}

variable "orchestratord_version" {
  description = "Version of the Materialize orchestrator to install"
  type        = string
  default     = "v0.130.4"
}

variable "materialize_instances" {
  description = "List of Materialize instances to be created."
  type = list(object({
    name                    = string
    namespace               = optional(string)
    database_name           = string
    create_database         = optional(bool, true)
    environmentd_version    = optional(string, "v0.130.4")
    cpu_request             = optional(string, "1")
    memory_request          = optional(string, "1Gi")
    memory_limit            = optional(string, "1Gi")
    in_place_rollout        = optional(bool, false)
    request_rollout         = optional(string)
    force_rollout           = optional(string)
    balancer_memory_request = optional(string, "256Mi")
    balancer_memory_limit   = optional(string, "256Mi")
    balancer_cpu_request    = optional(string, "100m")
  }))
  default = []
}
