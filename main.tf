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

  node_count   = var.system_node_group_node_count
  machine_type = var.system_node_group_machine_type
  disk_size_gb = var.system_node_group_disk_size_gb
  min_nodes    = var.system_node_group_min_nodes
  max_nodes    = var.system_node_group_max_nodes

  namespace = var.namespace
  labels    = local.common_labels
}

module "materialize_nodepool" {
  source     = "./modules/nodepool"
  depends_on = [module.gke]

  prefix                = "${var.prefix}-mz-swap"
  region                = var.region
  enable_private_nodes  = true
  cluster_name          = module.gke.cluster_name
  project_id            = var.project_id
  min_nodes             = var.materialize_node_group_min_nodes
  max_nodes             = var.materialize_node_group_max_nodes
  machine_type          = var.materialize_node_group_machine_type
  disk_size_gb          = var.materialize_node_group_disk_size_gb
  service_account_email = module.gke.service_account_email
  labels                = local.common_labels

  swap_enabled    = true
  local_ssd_count = var.materialize_node_group_local_ssd_count
}

moved {
  from = module.swap_nodepool[0]
  to   = module.materialize_nodepool
}

module "database" {
  source = "./modules/database"

  depends_on = [
    module.networking,
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
  versioning      = var.storage_bucket_versioning
  version_ttl     = var.storage_bucket_version_ttl

  labels = local.common_labels
}

module "certificates" {
  source = "./modules/certificates"

  install_cert_manager           = var.install_cert_manager
  cert_manager_install_timeout   = var.cert_manager_install_timeout
  cert_manager_chart_version     = var.cert_manager_chart_version
  use_self_signed_cluster_issuer = var.use_self_signed_cluster_issuer && length(var.materialize_instances) > 0
  cert_manager_namespace         = var.cert_manager_namespace
  name_prefix                    = var.prefix

  depends_on = [
    module.gke,
  ]
}

module "operator" {
  source = "github.com/MaterializeInc/terraform-helm-materialize?ref=v0.1.35"

  count = var.install_materialize_operator ? 1 : 0

  install_metrics_server = var.install_metrics_server

  depends_on = [
    module.gke,
    module.materialize_nodepool,
    module.database,
    module.storage,
    module.certificates,
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

module "load_balancers" {
  source = "./modules/load_balancers"

  for_each = { for idx, instance in local.instances : instance.name => instance if lookup(instance, "create_load_balancer", false) }

  instance_name = each.value.name
  namespace     = module.operator[0].materialize_instances[each.value.name].namespace
  resource_id   = module.operator[0].materialize_instance_resource_ids[each.value.name]
  internal      = each.value.internal_load_balancer

  depends_on = [
    module.operator,
    module.gke,
  ]
}

locals {
  default_helm_values = {
    observability = {
      podMetrics = {
        enabled = true
      }
    }
    operator = {
      image = var.orchestratord_version == null ? {} : {
        tag = var.orchestratord_version
      },
      cloudProvider = {
        type   = "gcp"
        region = var.region
        providers = {
          gcp = {
            enabled = true
          }
        }
      }
      clusters = {
        swap_enabled = true
      }
    }
    tls = (var.use_self_signed_cluster_issuer && length(var.materialize_instances) > 0) ? {
      defaultCertificateSpecs = {
        balancerdExternal = {
          dnsNames = [
            "balancerd",
          ]
          issuerRef = {
            name = module.certificates.cluster_issuer_name
            kind = "ClusterIssuer"
          }
        }
        consoleExternal = {
          dnsNames = [
            "console",
          ]
          issuerRef = {
            name = module.certificates.cluster_issuer_name
            kind = "ClusterIssuer"
          }
        }
        internal = {
          issuerRef = {
            name = module.certificates.cluster_issuer_name
            kind = "ClusterIssuer"
          }
        }
      }
    } : {}
  }

  merged_helm_values = provider::deepmerge::mergo(local.default_helm_values, var.helm_values)
}

locals {
  instances = [
    for instance in var.materialize_instances : {
      name                   = instance.name
      namespace              = instance.namespace
      database_name          = instance.database_name
      create_database        = instance.create_database
      create_load_balancer   = instance.create_load_balancer
      internal_load_balancer = instance.internal_load_balancer
      environmentd_version   = instance.environmentd_version

      environmentd_extra_args = instance.environmentd_extra_args

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

      license_key = instance.license_key

      authenticator_kind = instance.authenticator_kind

      external_login_password_mz_system = instance.external_login_password_mz_system != null ? instance.external_login_password_mz_system : null

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
