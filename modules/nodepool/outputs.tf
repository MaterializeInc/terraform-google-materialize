output "node_pool_name" {
  description = "The name of the node pool"
  value       = google_container_node_pool.primary_nodes.name
}

output "node_pool_id" {
  description = "The ID of the node pool"
  value       = google_container_node_pool.primary_nodes.id
}

output "instance_group_urls" {
  description = "List of instance group URLs for the node pool"
  value       = google_container_node_pool.primary_nodes.instance_group_urls
}

output "node_count" {
  description = "The current number of nodes in the pool"
  value       = google_container_node_pool.primary_nodes.node_count
}
