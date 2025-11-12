variable "prefix" {
  description = "Prefix to be used for resource names"
  type        = string
  nullable    = false
}

variable "region" {
  description = "The region where the cluster is located"
  type        = string
  nullable    = false
}

variable "cluster_name" {
  description = "The name of the GKE cluster"
  type        = string
  nullable    = false
}

variable "project_id" {
  description = "The GCP project ID"
  type        = string
  nullable    = false
}
variable "min_nodes" {
  description = "The minimum number of nodes in the autoscaling group"
  type        = number
  default     = 1
  nullable    = false
}

variable "max_nodes" {
  description = "The maximum number of nodes in the autoscaling group"
  type        = number
  default     = 10
  nullable    = false
}

variable "machine_type" {
  description = "The machine type for the nodes"
  type        = string
  default     = "e2-medium"
  nullable    = false
}

variable "disk_size_gb" {
  description = "The disk size in GB for each node"
  type        = number
  default     = 100
  nullable    = false
}

variable "labels" {
  description = "Labels to apply to the nodes"
  type        = map(string)
  default     = {}
}

variable "node_taints" {
  description = "Taints to apply to the node pool."
  type = list(object({
    key    = string
    value  = string
    effect = string
  }))
  default = []
}

variable "service_account_email" {
  description = "The email of the service account to use for the nodes"
  type        = string
  nullable    = false
}

variable "local_ssd_count" {
  description = "Number of local NVMe SSDs to attach to each node. In GCP, each disk is 375GB. For Materialize, you need to have a 1:2 ratio of disk to memory. If you have 8 CPUs and 64GB of memory, you need 128GB of disk. This means you need at least 1 local NVMe SSD. If you go with a larger machine type, you can increase the number of local NVMe SSDs."
  type        = number
  default     = 1
  nullable    = false
}

variable "enable_private_nodes" {
  description = "Whether to enable private nodes"
  type        = bool
  default     = true
  nullable    = false
}

variable "oauth_scopes" {
  description = "OAuth scopes to assign to the node pool service account"
  type        = list(string)
  default     = ["https://www.googleapis.com/auth/cloud-platform"]
  nullable    = false
}

variable "workload_metadata_mode" {
  description = "Mode for workload metadata configuration"
  type        = string
  default     = "GKE_METADATA"
  nullable    = false
}

variable "swap_enabled" {
  description = "Whether to enable swap on the local NVMe disks."
  type        = bool
  default     = true
}

variable "disk_setup_image" {
  description = "Docker image for the disk setup script"
  type        = string
  default     = "materialize/ephemeral-storage-setup-image:v0.4.0"
  nullable    = false
}

variable "disk_setup_container_resource_config" {
  description = "Resource configuration for disk setup init container"
  type = object({
    memory_limit   = string
    memory_request = string
    cpu_request    = string
  })
  default = {
    memory_limit   = "128Mi"
    memory_request = "128Mi"
    cpu_request    = "50m"
  }
  nullable = false
}

variable "pause_container_resource_config" {
  description = "Resource configuration for pause container"
  type = object({
    memory_limit   = string
    memory_request = string
    cpu_request    = string
  })
  default = {
    memory_limit   = "8Mi"
    memory_request = "8Mi"
    cpu_request    = "1m"
  }
  nullable = false
}
