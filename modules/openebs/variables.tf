variable "install_openebs" {
  description = "Whether to install OpenEBS or not"
  type        = bool
  default     = true
}

variable "openebs_namespace" {
  description = "The namespace where OpenEBS will be installed"
  type        = string
  default     = "openebs"
}

variable "create_namespace" {
  description = "Whether to create the namespace where OpenEBS will be installed"
  type        = bool
  default     = true
}

variable "openebs_version" {
  description = "The version of OpenEBS Helm chart to install"
  type        = string
  default     = "3.9.0"
}
