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

variable "service_account" {
  description = "The email of the service account to grant access to the bucket"
  type        = string
}

variable "labels" {
  description = "Labels to apply to resources"
  type        = map(string)
  default     = {}
}


variable "versioning" {
  description = "Enable bucket versioning (Disabled by default due to deletion timeouts)."
  type        = bool
  default     = false
}

variable "lifecycle_rules" {
  description = "List of lifecycle rules to configure"
  type = list(object({
    action = object({
      type          = string
      storage_class = optional(string)
    })
    condition = object({
      age                = optional(number)
      created_before     = optional(string)
      with_state         = optional(string)
      num_newer_versions = optional(number)
    })
  }))
  default = [
    {
      action = {
        type          = "SetStorageClass"
        storage_class = "NEARLINE"
      }
      condition = {
        age = 30
      }
    }
  ]
}

variable "version_ttl" {
  description = "Sets the TTL (in days) on non current sotarge bucket objects."
  type        = number
  default     = null

}
