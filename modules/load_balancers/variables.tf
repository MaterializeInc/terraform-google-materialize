variable "instance_name" {
  description = "The name of the Materialize instance."
  type        = string
}

variable "namespace" {
  description = "The kubernetes namespace to create the LoadBalancer Service in."
  type        = string
}

variable "resource_id" {
  description = "The resource_id in the Materialize status."
  type        = string
}

variable "internal" {
  description = "Whether the load balancer is internal to the VPC."
  type        = bool
  default     = true
}
