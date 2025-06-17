variable "name_prefix" {
  description = "Prefix for all resource names (replaces separate namespace and environment variables)"
  type        = string
}

variable "operator_version" {
  description = "Version of the Materialize operator to install"
  type        = string
  default     = "v25.1.12" # META: helm-chart version
  nullable    = false
}

variable "orchestratord_version" {
  description = "Version of the Materialize orchestrator to install"
  type        = string
  default     = null
}

variable "helm_repository" {
  description = "Repository URL for the Materialize operator Helm chart. Leave empty if using local chart."
  type        = string
  default     = "https://materializeinc.github.io/materialize/"
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

variable "operator_namespace" {
  description = "Namespace for the Materialize operator"
  type        = string
  default     = "materialize"
}

variable "monitoring_namespace" {
  description = "Namespace for monitoring resources"
  type        = string
  default     = "monitoring"
}

variable "metrics_server_version" {
  description = "Version of metrics-server to install"
  type        = string
  default     = "3.12.2"
}

variable "install_metrics_server" {
  description = "Whether to install the metrics-server"
  type        = bool
  default     = false
}

variable "region" {
  description = "Region/Zone for the operator Helm values."
  type        = string
  default     = "us-central1"
}

variable "use_self_signed_cluster_issuer" {
  description = "Whether to use a self-signed cluster issuer for cert-manager."
  type        = bool
  default     = false
}

variable "enable_disk_support" {
  description = "Enable disk support for Materialize using OpenEBS and NVMe instance storage. When enabled, this configures OpenEBS, runs the disk setup script for NVMe devices, and creates appropriate storage classes."
  type        = bool
  default     = true
}

variable "disk_support_config" {
  description = "Advanced configuration for disk support (only used when enable_disk_support = true)"
  type = object({
    create_storage_class      = optional(bool, true)
    storage_class_name        = optional(string, "openebs-lvm-instance-store-ext4")
    storage_class_provisioner = optional(string, "local.csi.openebs.io")
    storage_class_parameters = optional(object({
      storage  = optional(string, "lvm")
      fsType   = optional(string, "ext4")
      volgroup = optional(string, "instance-store-vg")
    }), {})
  })
  default = {}
}
