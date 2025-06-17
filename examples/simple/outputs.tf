output "gke_cluster" {
  description = "GKE cluster details"
  value = {
    name           = module.gke.cluster_name
    endpoint       = module.gke.cluster_endpoint
    location       = module.gke.cluster_location
    ca_certificate = module.gke.cluster_ca_certificate
  }
  sensitive = true
}

output "network" {
  description = "Network details"
  value = {
    network_id   = module.networking.network_id
    network_name = module.networking.network_name
    subnet_name  = module.networking.subnet_name
  }
}

output "database" {
  description = "Cloud SQL instance details"
  value = {
    name           = module.database.instance_name
    connection_url = module.database.connection_url
    private_ip     = module.database.private_ip
  }
  sensitive = true
}

output "storage" {
  description = "GCS bucket details"
  value = {
    name      = module.storage.bucket_name
    url       = module.storage.bucket_url
    self_link = module.storage.bucket_self_link
  }
}

output "service_accounts" {
  description = "Service account details"
  value = {
    gke_sa         = module.gke.service_account_email
    materialize_sa = module.gke.workload_identity_sa_email
  }
}

output "connection_strings" {
  description = "Formatted connection strings for Materialize"
  value = {
    metadata_backend_url = local.metadata_backend_url
    persist_backend_url  = local.persist_backend_url
  }
  sensitive = true
}

output "operator" {
  description = "Materialize operator details"
  value = var.install_materialize_operator ? {
    namespace             = module.operator[0].operator_namespace
    release_name          = module.operator[0].operator_release_name
    release_status        = module.operator[0].operator_release_status
  } : null
}

output "materialize_instance" {
  description = "Materialize instance details"
  sensitive = true
  value = var.install_materialize_instance ? {
    name = module.materialize_instance[0].instance_name
    namespace = module.materialize_instance[0].instance_namespace
    resource_id = module.materialize_instance[0].instance_resource_id
    metadata_backend_url = module.materialize_instance[0].metadata_backend_url
    persist_backend_url = module.materialize_instance[0].persist_backend_url
  } : null
}

output "load_balancer_details" {
  description = "Details of the Materialize instance load balancers."
  value = {
    for load_balancer in module.load_balancers : load_balancer.instance_name => {
      console_load_balancer_ip   = load_balancer.console_load_balancer_ip
      balancerd_load_balancer_ip = load_balancer.balancerd_load_balancer_ip
    }
  }
}
