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

locals {
  metadata_backend_url = format(
    "postgres://%s:%s@%s:5432/%s?sslmode=disable",
    var.database_config.username,
    var.database_config.password,
    module.database.private_ip,
    var.database_config.db_name
  )

  encoded_endpoint = urlencode("https://storage.googleapis.com")
  encoded_secret   = urlencode(module.storage.hmac_secret)

  persist_backend_url = format(
    "s3://%s:%s@%s/materialize?endpoint=%s&region=%s",
    module.storage.hmac_access_id,
    local.encoded_secret,
    module.storage.bucket_name,
    local.encoded_endpoint,
    var.region
  )
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
    instances             = module.operator[0].materialize_instances
    instance_resource_ids = module.operator[0].materialize_instance_resource_ids
  } : null
}
