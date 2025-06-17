
provider "google" {
  project = var.project_id
  region  = var.region
}

# Configure kubernetes provider with GKE cluster credentials
data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = "https://${module.gke.cluster_endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(module.gke.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = "https://${module.gke.cluster_endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(module.gke.cluster_ca_certificate)
  }
}


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

  metadata_backend_url = format(
    "postgres://%s:%s@%s:5432/%s?sslmode=disable",
    var.database_config.username,
    random_password.database_password.result,
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

module "networking" {
  source = "../../modules/networking"

  project_id    = var.project_id
  region        = var.region
  prefix        = var.prefix
  subnet_cidr   = var.network_config.subnet_cidr
  pods_cidr     = var.network_config.pods_cidr
  services_cidr = var.network_config.services_cidr
}

module "gke" {
  source = "../../modules/gke"

  depends_on = [module.networking]

  project_id   = var.project_id
  region       = var.region
  prefix       = var.prefix
  network_name = module.networking.network_name
  subnet_name  = module.networking.subnet_name
  namespace = var.namespace
}


module "nodepool" {
  source = "../../modules/nodepool"
  depends_on = [module.gke]
  
  nodepool_name = "${var.prefix}-node-pool"
  region = var.region
  enable_private_nodes = true
  cluster_name = module.gke.cluster_name
  project_id = var.project_id
  node_count = var.gke_config.node_count
  min_nodes = var.gke_config.min_nodes
  max_nodes = var.gke_config.max_nodes
  machine_type = var.gke_config.machine_type
  disk_size_gb = var.gke_config.disk_size_gb
  service_account_email = module.gke.service_account_email
  labels = local.common_labels

  disk_setup_image = var.disk_setup_image
  enable_disk_setup = local.disk_config.run_disk_setup_script
  local_ssd_count = local.disk_config.local_ssd_count
}

module "openebs" {
  source = "../../modules/openebs"
  depends_on = [
    module.gke,
    module.nodepool
  ]

  install_openebs = local.disk_config.install_openebs
  create_namespace = true
  openebs_namespace = local.disk_config.openebs_namespace
  openebs_version = local.disk_config.openebs_version
}

resource "random_password" "database_password" {
  length  = 20
  special = false
}

module "database" {
  source = "../../modules/database"

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
  password   = random_password.database_password.result

  labels = local.common_labels
}

module "storage" {
  source = "../../modules/storage"

  project_id      = var.project_id
  region          = var.region
  prefix          = var.prefix
  service_account = module.gke.workload_identity_sa_email
  versioning      = var.storage_bucket_versioning
  version_ttl     = var.storage_bucket_version_ttl

  labels = local.common_labels
}

module "certificates" {
  source = "../../modules/certificates"

  install_cert_manager           = var.install_cert_manager
  cert_manager_install_timeout   = var.cert_manager_install_timeout
  cert_manager_chart_version     = var.cert_manager_chart_version
  use_self_signed_cluster_issuer = var.install_materialize_instance
  cert_manager_namespace         = var.cert_manager_namespace
  name_prefix                    = var.prefix

  depends_on = [
    module.gke,
    module.nodepool,
  ]
}

module "operator" {
  count = var.install_materialize_operator ? 1 : 0
  source = "../../modules/operator"

  name_prefix                    = var.prefix
  use_self_signed_cluster_issuer = var.install_materialize_instance
  region = var.region

  depends_on = [
    module.gke,
    module.nodepool,
    module.database,
    module.storage,
    module.certificates,
  ]
}

module "materialize_instance" {
  count = var.install_materialize_instance ? 1 : 0

  source               = "../../modules/materialize-instance"
  instance_name        = "main"
  instance_namespace   = "materialize-environment"
  metadata_backend_url = local.metadata_backend_url
  persist_backend_url  = local.persist_backend_url

  depends_on = [
    module.gke,
    module.database,
    module.storage,
    module.networking,
    module.certificates,
    module.operator,
    module.nodepool,
    module.openebs,
  ]
}

module "load_balancers" {
  count = var.install_materialize_instance ? 1 : 0

  source = "../../modules/load_balancers"

  instance_name = "main"
  namespace     = "materialize-environment"
  resource_id   = module.materialize_instance[0].instance_resource_id

  depends_on = [
    module.materialize_instance,
  ]
}
