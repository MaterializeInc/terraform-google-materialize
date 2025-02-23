terraform {
  required_version = ">= 1.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

module "materialize" {
  # Referencing the root module directory:
  source = "../.."

  # Alternatively, you can use the GitHub source URL:
  # source = "github.com/MaterializeInc/terraform-google-materialize?ref=v0.1.0"

  project_id = var.project_id
  region     = var.region
  prefix     = "mz-simple"

  database_config = {
    tier     = "db-custom-2-4096"
    version  = "POSTGRES_15"
    password = var.database_password
  }

  labels = {
    environment = "simple"
    example     = "true"
  }

  install_materialize_operator = true

  # Once the operator is installed, you can define your Materialize instances here.
  materialize_instances = var.materialize_instances
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

variable "database_password" {
  description = "Password for Cloud SQL database user"
  default     = "your-strong-password"
  type        = string
  sensitive   = true
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

variable "materialize_instances" {
  description = "List of Materialize instances to be created."
  type = list(object({
    name            = string
    namespace       = string
    database_name   = string
    cpu_request     = string
    memory_request  = string
    memory_limit    = string
    create_database = optional(bool)
  }))
  default = []
}
