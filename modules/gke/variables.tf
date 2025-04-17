variable "project_id" {
  description = "The ID of the project where resources will be created"
  type        = string
}

variable "region" {
  description = "The region where resources will be created"
  type        = string
}

variable "prefix" {
  description = "Prefix to be used for resource names"
  type        = string
}

variable "network_name" {
  description = "The name of the VPC network"
  type        = string
}

variable "subnet_name" {
  description = "The name of the subnet"
  type        = string
}

variable "node_count" {
  description = "Number of nodes in the GKE cluster"
  type        = number
}

variable "machine_type" {
  description = "Machine type for GKE nodes"
  type        = string
}

variable "disk_size_gb" {
  description = "Size of the disk attached to each node"
  type        = number
}

variable "min_nodes" {
  description = "Minimum number of nodes in the node pool"
  type        = number
}

variable "max_nodes" {
  description = "Maximum number of nodes in the node pool"
  type        = number
}

variable "namespace" {
  description = "Kubernetes namespace for Materialize"
  type        = string
}

variable "labels" {
  description = "Labels to apply to resources"
  type        = map(string)
  default     = {}
}

# Disk setup variables
variable "enable_disk_setup" {
  description = "Whether to enable the local NVMe SSD disks setup script for NVMe storage"
  type        = bool
  default     = true
}

variable "local_ssd_count" {
  description = "Number of local NVMe SSDs to attach to each node. In GCP, each disk is 375GB. For Materialize, you need to have a 1:2 ratio of disk to memory. If you have 8 CPUs and 64GB of memory, you need 128GB of disk. This means you need at least 1 local NVMe SSD. If you go with a larger machine type, you can increase the number of local NVMe SSDs."
  type        = number
  default     = 1
}

variable "install_openebs" {
  description = "Whether to install OpenEBS for NVMe storage"
  type        = bool
  default     = true
}

variable "openebs_namespace" {
  description = "Namespace for OpenEBS components"
  type        = string
  default     = "openebs"
}

variable "openebs_version" {
  description = "Version of OpenEBS Helm chart to install"
  type        = string
  default     = "4.2.0"
}

variable "disk_setup_image" {
  description = "Docker image for the disk setup script"
  type        = string
}
