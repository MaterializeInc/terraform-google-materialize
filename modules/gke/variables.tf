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
  description = "Whether to enable the local SSD disk setup script for NVMe storage"
  type        = bool
  default     = true
}

variable "local_ssd_count" {
  description = "Number of local SSDs to attach to each node"
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
