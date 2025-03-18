locals {
  common_labels = merge(var.labels, {
    managed_by = "terraform"
    module     = "materialize"
  })
}

module "networking" {
  source = "./modules/networking"

  project_id    = var.project_id
  region        = var.region
  prefix        = var.prefix
  subnet_cidr   = var.network_config.subnet_cidr
  pods_cidr     = var.network_config.pods_cidr
  services_cidr = var.network_config.services_cidr
}

module "gke" {
  source = "./modules/gke"

  depends_on = [module.networking]

  project_id   = var.project_id
  region       = var.region
  prefix       = var.prefix
  network_name = module.networking.network_name
  subnet_name  = module.networking.subnet_name

  node_count   = var.gke_config.node_count
  machine_type = var.gke_config.machine_type
  disk_size_gb = var.gke_config.disk_size_gb
  min_nodes    = var.gke_config.min_nodes
  max_nodes    = var.gke_config.max_nodes

  namespace = var.namespace
  labels    = local.common_labels
}

module "database" {
  source = "./modules/database"

  depends_on = [
    module.networking,
    module.gke
  ]

  database_name = var.database_config.db_name
  database_user = var.database_config.username

  project_id = var.project_id
  region     = var.region
  prefix     = var.prefix
  network_id = module.networking.network_id

  tier       = var.database_config.tier
  db_version = var.database_config.version
  password   = var.database_config.password

  labels = local.common_labels
}

module "storage" {
  source = "./modules/storage"

  project_id      = var.project_id
  region          = var.region
  prefix          = var.prefix
  service_account = module.gke.workload_identity_sa_email

  labels = local.common_labels
}

module "operator" {
  source = "github.com/MaterializeInc/terraform-helm-materialize?ref=v0.1.8"

  count = var.install_materialize_operator ? 1 : 0

  install_metrics_server = var.install_metrics_server

  depends_on = [
    module.gke,
    module.database,
    module.storage
  ]

  namespace          = var.namespace
  environment        = var.prefix
  operator_version   = var.operator_version
  operator_namespace = var.operator_namespace

  helm_values = local.merged_helm_values

  instances = local.instances

  // For development purposes, you can use a local Helm chart instead of fetching it from the Helm repository
  use_local_chart = var.use_local_chart
  helm_chart      = var.helm_chart

  providers = {
    kubernetes = kubernetes
    helm       = helm
  }
}

locals {
  default_helm_values = {
    observability = {
      podMetrics = {
        enabled = true
      }
    }
    operator = {
      image = {
        tag = var.orchestratord_version
      }
      cloudProvider = {
        type   = "gcp"
        region = var.region
        providers = {
          gcp = {
            enabled = true
          }
        }
      }
    }
  }

  merged_helm_values = merge(local.default_helm_values, var.helm_values)
}

locals {
  instances = [
    for instance in var.materialize_instances : {
      name                 = instance.name
      namespace            = instance.namespace
      database_name        = instance.database_name
      create_database      = instance.create_database
      environmentd_version = instance.environmentd_version

      metadata_backend_url = format(
        "postgres://%s:%s@%s:5432/%s?sslmode=disable",
        var.database_config.username,
        urlencode(var.database_config.password),
        module.database.private_ip,
        coalesce(instance.database_name, instance.name)
      )

      persist_backend_url = format(
        "s3://%s:%s@%s/materialize?endpoint=%s&region=%s",
        module.storage.hmac_access_id,
        local.encoded_secret,
        module.storage.bucket_name,
        local.encoded_endpoint,
        var.region
      )

      cpu_request    = instance.cpu_request
      memory_request = instance.memory_request
      memory_limit   = instance.memory_limit

      # Rollout options
      in_place_rollout = instance.in_place_rollout
      request_rollout  = instance.request_rollout
      force_rollout    = instance.force_rollout
    }
  ]
}
