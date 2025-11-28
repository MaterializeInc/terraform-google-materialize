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
}

variable "system_node_group_node_count" {
  description = "Number of nodes in the system node group"
  type        = number
  default     = 1
}

variable "system_node_group_machine_type" {
  description = "Machine type for system nodes"
  type        = string
  default     = "n2-highmem-8"
}

variable "system_node_group_disk_size_gb" {
  description = "Size of the disk attached to each system node"
  type        = number
  default     = 100
}

variable "system_node_group_min_nodes" {
  description = "Minimum number of system nodes"
  type        = number
  default     = 1
}

variable "system_node_group_max_nodes" {
  description = "Maximum number of system nodes"
  type        = number
  default     = 2
}

variable "materialize_node_group_min_nodes" {
  description = "Minimum number of Materialize worker nodes"
  type        = number
  default     = 1
}

variable "materialize_node_group_max_nodes" {
  description = "Maximum number of Materialize worker nodes"
  type        = number
  default     = 2
}

variable "materialize_node_group_machine_type" {
  description = "Machine type for Materialize worker nodes"
  type        = string
  default     = "n2-highmem-8"
}

variable "materialize_node_group_disk_size_gb" {
  description = "Size of the disk attached to each Materialize worker node"
  type        = number
  default     = 100
}

variable "materialize_node_group_local_ssd_count" {
  description = "Number of local NVMe SSDs to attach to each Materialize node. In GCP, each disk is 375GB."
  type        = number
  default     = 1
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

variable "database_vpc_wait_duration" {
  description = "Duration to wait for VPC resources to be ready before creating the database (e.g., '60s', '2m')"
  type        = string
  default     = "60s"
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
  default     = true
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
  default     = null
}

variable "materialize_instances" {
  description = "Configuration for Materialize instances"
  type = list(object({
    name                              = string
    namespace                         = optional(string)
    database_name                     = string
    create_database                   = optional(bool, true)
    create_load_balancer              = optional(bool, true)
    internal_load_balancer            = optional(bool, true)
    environmentd_version              = optional(string)
    cpu_request                       = optional(string, "1")
    memory_request                    = optional(string, "1Gi")
    memory_limit                      = optional(string, "1Gi")
    in_place_rollout                  = optional(bool, false)
    request_rollout                   = optional(string)
    force_rollout                     = optional(string)
    balancer_memory_request           = optional(string, "256Mi")
    balancer_memory_limit             = optional(string, "256Mi")
    balancer_cpu_request              = optional(string, "100m")
    license_key                       = optional(string)
    authenticator_kind                = optional(string, "None")
    external_login_password_mz_system = optional(string)
    environmentd_extra_args           = optional(list(string), [])
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

variable "storage_bucket_versioning" {
  description = "Enable bucket versioning. This should be enabled for production deployments."
  type        = bool
  default     = false
}

variable "storage_bucket_version_ttl" {
  description = "Sets the TTL (in days) on non current storage bucket objects. This must be set if storage_bucket_versioning is turned on."
  type        = number
  default     = 7
}

variable "install_cert_manager" {
  description = "Whether to install cert-manager."
  type        = bool
  default     = true
}

variable "use_self_signed_cluster_issuer" {
  description = "Whether to install and use a self-signed ClusterIssuer for TLS. To work around limitations in Terraform, this will be treated as `false` if no materialize instances are defined."
  type        = bool
  default     = true
}

variable "cert_manager_namespace" {
  description = "The name of the namespace in which cert-manager is or will be installed."
  type        = string
  default     = "cert-manager"
}

variable "cert_manager_install_timeout" {
  description = "Timeout for installing the cert-manager helm chart, in seconds."
  type        = number
  default     = 300
}

variable "cert_manager_chart_version" {
  description = "Version of the cert-manager helm chart to install."
  type        = string
  default     = "v1.17.1"
}
