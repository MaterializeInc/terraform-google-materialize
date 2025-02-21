variable "project_id" {
  description = "The ID of the project where resources will be created"
  type        = string
}

variable "region" {
  description = "The region where resources will be created"
  type        = string
  default     = "us-central1"
}

variable "prefix" {
  description = "Prefix to be used for resource names"
  type        = string
  default     = "materialize"
}

variable "network_config" {
  description = "Network configuration for the GKE cluster"
  type = object({
    subnet_cidr   = string
    pods_cidr     = string
    services_cidr = string
  })
  default = {
    subnet_cidr   = "10.0.0.0/20"
    pods_cidr     = "10.48.0.0/14"
    services_cidr = "10.52.0.0/20"
  }
}

variable "gke_config" {
  description = "GKE cluster configuration. Make sure to use large enough machine types for your Materialize instances."
  type = object({
    node_count     = number
    machine_type   = string
    disk_size_gb   = number
    min_nodes      = number
    max_nodes      = number
    node_locations = list(string)
  })
  default = {
    node_count     = 1
    machine_type   = "e2-standard-4"
    disk_size_gb   = 50
    min_nodes      = 1
    max_nodes      = 2
    node_locations = []
  }
}

variable "database_config" {
  description = "Cloud SQL configuration"
  type = object({
    tier     = optional(string, "db-custom-2-4096")
    version  = optional(string, "POSTGRES_15")
    password = string
    username = optional(string, "materialize")
    db_name  = optional(string, "materialize")
  })

  validation {
    condition     = var.database_config.password != null
    error_message = "database_config.password must be provided"
  }
}

variable "namespace" {
  description = "Kubernetes namespace for Materialize"
  type        = string
  default     = "materialize"
}

variable "labels" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default     = {}
}

# Materialize Helm Chart Variables
variable "install_materialize_operator" {
  description = "Whether to install the Materialize operator"
  type        = bool
  default     = false
}

variable "helm_chart" {
  description = "Chart name from repository or local path to chart. For local charts, set the path to the chart directory."
  type        = string
  default     = "materialize-operator"
}

variable "use_local_chart" {
  description = "Whether to use a local chart instead of one from a repository"
  type        = bool
  default     = false
}

variable "helm_values" {
  description = "Values to pass to the Helm chart"
  type        = any
  default     = {}
}

variable "orchestratord_version" {
  description = "Version of the Materialize orchestrator to install"
  type        = string
  default     = "v0.130.1"
}

variable "materialize_instances" {
  description = "Configuration for Materialize instances"
  type = list(object({
    name                 = string
    namespace            = optional(string)
    database_name        = string
    create_database      = optional(bool, true)
    environmentd_version = optional(string, "v0.130.1")
    cpu_request          = optional(string, "1")
    memory_request       = optional(string, "1Gi")
    memory_limit         = optional(string, "1Gi")
    in_place_rollout     = optional(bool, false)
    request_rollout      = optional(string)
    force_rollout        = optional(string)
  }))
  default = []

  validation {
    condition = alltrue([
      for instance in var.materialize_instances :
      instance.request_rollout == null ||
      can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", instance.request_rollout))
    ])
    error_message = "Request rollout must be a valid UUID in the format xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  }

  validation {
    condition = alltrue([
      for instance in var.materialize_instances :
      instance.force_rollout == null ||
      can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", instance.force_rollout))
    ])
    error_message = "Force rollout must be a valid UUID in the format xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  }
}

variable "operator_version" {
  description = "Version of the Materialize operator to install"
  type        = string
  default     = null
}

variable "operator_namespace" {
  description = "Namespace for the Materialize operator"
  type        = string
  default     = "materialize"
}

variable "install_metrics_server" {
  description = "Whether to install the metrics-server for the Materialize Console. Defaults to false since GKE installs one by default in the kube-system namespace. Only set to true if the GKE cluster was deployed with [monitoring explicitly turned off](https://cloud.google.com/kubernetes-engine/docs/how-to/configure-metrics#:~:text=To%20disable%20system%20metric%20collection,for%20the%20%2D%2Dmonitoring%20flag). Refer to the [GKE docs](https://cloud.google.com/kubernetes-engine/docs/how-to/configure-metrics#:~:text=To%20disable%20system%20metric%20collection,for%20the%20%2D%2Dmonitoring%20flag) for more information, including impact to GKE customer support efforts."
  type        = bool
  default     = false
}
