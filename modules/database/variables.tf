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

variable "network_id" {
  description = "The ID of the VPC network to connect the database to"
  type        = string
}

variable "private_vpc_connection" {
  description = "The private VPC connection dependency"
  type        = any
  default     = null
}

variable "tier" {
  description = "The machine tier for the database instance"
  type        = string
}

variable "db_version" {
  description = "The PostgreSQL version to use"
  type        = string
  validation {
    condition     = can(regex("^POSTGRES_[0-9]+$", var.db_version))
    error_message = "Version must be in format POSTGRES_XX where XX is the version number"
  }
}

variable "password" {
  description = "The password for the database user"
  type        = string
  sensitive   = true
}

variable "database_user" {
  description = "The name of the database user"
  default     = "materialize"
  type        = string
}

variable "database_name" {
  description = "The name of the database"
  default     = "materialize"
  type        = string
}

variable "labels" {
  description = "Labels to apply to resources"
  type        = map(string)
  default     = {}
}

variable "vpc_wait_duration" {
  description = "Duration to wait for VPC resources to be ready (e.g., '60s')"
  type        = string
  default     = "60s"
}
