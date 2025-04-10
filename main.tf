locals {
  common_labels = merge(var.labels, {
    managed_by = "terraform"
    module     = "materialize"
  })

  # Disk support configuration
  disk_config = {
    install_openebs           = var.enable_disk_support ? lookup(var.disk_support_config, "install_openebs", true) : false
    run_disk_setup_script     = var.enable_disk_support ? lookup(var.disk_support_config, "run_disk_setup_script", true) : false
    local_ssd_count           = lookup(var.disk_support_config, "local_ssd_count", 1)
    create_storage_class      = var.enable_disk_support ? lookup(var.disk_support_config, "create_storage_class", true) : false
    openebs_version           = lookup(var.disk_support_config, "openebs_version", "4.2.0")
    openebs_namespace         = lookup(var.disk_support_config, "openebs_namespace", "openebs")
    storage_class_name        = lookup(var.disk_support_config, "storage_class_name", "openebs-lvm-instance-store-ext4")
    storage_class_provisioner = "local.csi.openebs.io"
    storage_class_parameters = {
      storage  = "lvm"
      fsType   = "ext4"
      volgroup = "instance-store-vg"
    }
  }
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

  # Disk support configuration
  enable_disk_setup = local.disk_config.run_disk_setup_script
  local_ssd_count   = local.disk_config.local_ssd_count
  install_openebs   = local.disk_config.install_openebs
  openebs_namespace = local.disk_config.openebs_namespace
  openebs_version   = local.disk_config.openebs_version

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
  source = "github.com/MaterializeInc/terraform-helm-materialize?ref=v0.1.12"

  count = var.install_materialize_operator ? 1 : 0

  install_metrics_server = var.install_metrics_server

  depends_on = [
    module.gke,
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
    }
    storage = var.enable_disk_support ? {
      storageClass = {
        create      = local.disk_config.create_storage_class
        name        = local.disk_config.storage_class_name
        provisioner = local.disk_config.storage_class_provisioner
        parameters  = local.disk_config.storage_class_parameters
      }
    } : {}
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

  merged_helm_values = merge(local.default_helm_values, var.helm_values)
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
