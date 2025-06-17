variable "nodepool_name" {
  description = "The name of the node pool"
  type        = string
}

variable "region" {
  description = "The region where the cluster is located"
  type        = string
}

variable "enable_disk_setup" {
  description = "Whether to enable the local NVMe SSD disks setup script for NVMe storage"
  type        = bool
  default     = true
}

variable "cluster_name" {
  description = "The name of the GKE cluster"
  type        = string
}

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "node_count" {
  description = "The number of nodes in the node pool"
  type        = number
  default     = 3
}

variable "min_nodes" {
  description = "The minimum number of nodes in the autoscaling group"
  type        = number
  default     = 1
}

variable "max_nodes" {
  description = "The maximum number of nodes in the autoscaling group"
  type        = number
  default     = 10
}

variable "machine_type" {
  description = "The machine type for the nodes"
  type        = string
  default     = "e2-medium"
}

variable "disk_size_gb" {
  description = "The disk size in GB for each node"
  type        = number
  default     = 100
}

variable "labels" {
  description = "Labels to apply to the nodes"
  type        = map(string)
  default     = {}
}

variable "service_account_email" {
  description = "The email of the service account to use for the nodes"
  type        = string
}

variable "local_ssd_count" {
  description = "Number of local NVMe SSDs to attach to each node. In GCP, each disk is 375GB. For Materialize, you need to have a 1:2 ratio of disk to memory. If you have 8 CPUs and 64GB of memory, you need 128GB of disk. This means you need at least 1 local NVMe SSD. If you go with a larger machine type, you can increase the number of local NVMe SSDs."
  type        = number
  default     = 1
}

variable "enable_private_nodes" {
  description = "Whether to enable private nodes"
  type        = bool
  default     = true
}

variable "disk_setup_image" {
  description = "Docker image for the disk setup script"
  type        = string
  default     = "materialize/ephemeral-storage-setup-image:v0.1.1"
}
