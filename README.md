<!-- BEGIN_TF_DOCS -->
# Materialize on Google Cloud Platform

Terraform module for deploying Materialize on Google Cloud Platform (GCP) with all required infrastructure components.

This module sets up:
- GKE cluster for Materialize workloads
- Cloud SQL PostgreSQL instance for metadata storage
- Cloud Storage bucket for persistence
- Required networking and security configurations
- Service accounts with proper IAM permissions

> [!WARNING]
> This module is intended for demonstration/evaluation purposes as well as for serving as a template when building your own production deployment of Materialize.
>
> This module should not be directly relied upon for production deployments: **future releases of the module will contain breaking changes.** Instead, to use as a starting point for your own production deployment, either:
> - Fork this repo and pin to a specific version, or
> - Use the code as a reference when developing your own deployment.

The module has been tested with:
- GKE version 1.28
- PostgreSQL 15
- Materialize Operator v0.1.0

## Disk Support for Materialize on GCP

This module supports configuring disk support for Materialize using local SSDs in GCP with OpenEBS and lgalloc.

### Machine Types with Local SSDs in GCP

When using disk support for Materialize on GCP, you need to use machine types that support local SSD attachment. Here are some recommended machine types:

1. [N2 series](https://cloud.google.com/compute/docs/general-purpose-machines#n2d_machine_types) with local SSDs:
   - For memory-optimized workloads similar to AWS r7gd, consider `n2-highmem-16` or `n2-highmem-32` with local SSDs
   - Example: `n2-highmem-32` with 2 or more local SSDs

2. [C2 series](https://cloud.google.com/compute/docs/compute-optimized-machines#c2_machine_types) with local SSDs:
   - For compute-optimized workloads
   - Example: `c2-standard-16` with local SSDs

3. [N2D series](https://cloud.google.com/compute/docs/general-purpose-machines#n2d_machine_types) with local SSDs:
   - AMD EPYC-based instances, often with good price/performance ratio
   - Example: `n2d-highmem-32` with local SSDs

### Enabling Disk Support

To enable disk support with default settings in your Terraform configuration:

```hcl
enable_disk_support = true

gke_config = {
  node_count   = 3
  machine_type = "n2-highmem-32"  # Choose a machine type that supports local SSDs
  disk_size_gb = 100
  min_nodes    = 3
  max_nodes    = 5
}
```

This will:
1. Attach local SSDs to each node in the GKE cluster
2. Install OpenEBS via Helm
3. Configure local SSD devices using the [bootstrap](./modules/gke/bootstrap.sh) script
4. Create appropriate storage classes for Materialize

### Advanced Configuration

For more control over the disk setup:

```hcl
enable_disk_support = true

disk_support_config = {
  local_ssd_count    = 1
  openebs_version    = "4.2.0"
  storage_class_name = "custom-storage-class"
}
```

### Local SSD Limitations in GCP

Note that there are some differences between AWS NVMe instance store and GCP local SSDs:

1. GCP local SSDs have a fixed size of 375 GB each
2. Local SSDs must be attached at instance creation time
3. The number of local SSDs you can attach depends on the machine type
4. Data on local SSDs is lost when the instance stops or is deleted

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 6.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 2.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 2.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_certificates"></a> [certificates](#module\_certificates) | ./modules/certificates | n/a |
| <a name="module_database"></a> [database](#module\_database) | ./modules/database | n/a |
| <a name="module_gke"></a> [gke](#module\_gke) | ./modules/gke | n/a |
| <a name="module_load_balancers"></a> [load\_balancers](#module\_load\_balancers) | ./modules/load_balancers | n/a |
| <a name="module_networking"></a> [networking](#module\_networking) | ./modules/networking | n/a |
| <a name="module_operator"></a> [operator](#module\_operator) | github.com/MaterializeInc/terraform-helm-materialize | v0.1.9 |
| <a name="module_storage"></a> [storage](#module\_storage) | ./modules/storage | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cert_manager_chart_version"></a> [cert\_manager\_chart\_version](#input\_cert\_manager\_chart\_version) | Version of the cert-manager helm chart to install. | `string` | `"v1.17.1"` | no |
| <a name="input_cert_manager_install_timeout"></a> [cert\_manager\_install\_timeout](#input\_cert\_manager\_install\_timeout) | Timeout for installing the cert-manager helm chart, in seconds. | `number` | `300` | no |
| <a name="input_cert_manager_namespace"></a> [cert\_manager\_namespace](#input\_cert\_manager\_namespace) | The name of the namespace in which cert-manager is or will be installed. | `string` | `"cert-manager"` | no |
| <a name="input_database_config"></a> [database\_config](#input\_database\_config) | Cloud SQL configuration | <pre>object({<br/>    tier     = optional(string, "db-custom-2-4096")<br/>    version  = optional(string, "POSTGRES_15")<br/>    password = string<br/>    username = optional(string, "materialize")<br/>    db_name  = optional(string, "materialize")<br/>  })</pre> | n/a | yes |
| <a name="input_disk_support_config"></a> [disk\_support\_config](#input\_disk\_support\_config) | Advanced configuration for disk support (only used when enable\_disk\_support = true) | <pre>object({<br/>    install_openebs           = optional(bool, true)<br/>    run_disk_setup_script     = optional(bool, true)<br/>    local_ssd_count           = optional(number, 1)<br/>    create_storage_class      = optional(bool, true)<br/>    openebs_version           = optional(string, "4.2.0")<br/>    openebs_namespace         = optional(string, "openebs")<br/>    storage_class_name        = optional(string, "openebs-lvm-instance-store-ext4")<br/>    storage_class_provisioner = optional(string, "local.csi.openebs.io")<br/>    storage_class_parameters = optional(object({<br/>      storage  = optional(string, "lvm")<br/>      fsType   = optional(string, "ext4")<br/>      volgroup = optional(string, "instance-store-vg")<br/>    }), {})<br/>  })</pre> | `{}` | no |
| <a name="input_enable_disk_support"></a> [enable\_disk\_support](#input\_enable\_disk\_support) | Enable disk support for Materialize using OpenEBS and local SSDs. When enabled, this configures OpenEBS, runs the disk setup script, and creates appropriate storage classes. | `bool` | `true` | no |
| <a name="input_gke_config"></a> [gke\_config](#input\_gke\_config) | GKE cluster configuration. Make sure to use large enough machine types for your Materialize instances. | <pre>object({<br/>    node_count   = number<br/>    machine_type = string<br/>    disk_size_gb = number<br/>    min_nodes    = number<br/>    max_nodes    = number<br/>  })</pre> | <pre>{<br/>  "disk_size_gb": 100,<br/>  "machine_type": "n2-highmem-8",<br/>  "max_nodes": 2,<br/>  "min_nodes": 1,<br/>  "node_count": 1<br/>}</pre> | no |
| <a name="input_helm_chart"></a> [helm\_chart](#input\_helm\_chart) | Chart name from repository or local path to chart. For local charts, set the path to the chart directory. | `string` | `"materialize-operator"` | no |
| <a name="input_helm_values"></a> [helm\_values](#input\_helm\_values) | Values to pass to the Helm chart | `any` | `{}` | no |
| <a name="input_install_cert_manager"></a> [install\_cert\_manager](#input\_install\_cert\_manager) | Whether to install cert-manager. | `bool` | `false` | no |
| <a name="input_install_materialize_operator"></a> [install\_materialize\_operator](#input\_install\_materialize\_operator) | Whether to install the Materialize operator | `bool` | `true` | no |
| <a name="input_install_metrics_server"></a> [install\_metrics\_server](#input\_install\_metrics\_server) | Whether to install the metrics-server for the Materialize Console. Defaults to false since GKE installs one by default in the kube-system namespace. Only set to true if the GKE cluster was deployed with [monitoring explicitly turned off](https://cloud.google.com/kubernetes-engine/docs/how-to/configure-metrics#:~:text=To%20disable%20system%20metric%20collection,for%20the%20%2D%2Dmonitoring%20flag). Refer to the [GKE docs](https://cloud.google.com/kubernetes-engine/docs/how-to/configure-metrics#:~:text=To%20disable%20system%20metric%20collection,for%20the%20%2D%2Dmonitoring%20flag) for more information, including impact to GKE customer support efforts. | `bool` | `false` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | Labels to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_materialize_instances"></a> [materialize\_instances](#input\_materialize\_instances) | Configuration for Materialize instances | <pre>list(object({<br/>    name                    = string<br/>    namespace               = optional(string)<br/>    database_name           = string<br/>    create_database         = optional(bool, true)<br/>    create_load_balancer    = optional(bool, true)<br/>    internal_load_balancer  = optional(bool, true)<br/>    environmentd_version    = optional(string)<br/>    cpu_request             = optional(string, "1")<br/>    memory_request          = optional(string, "1Gi")<br/>    memory_limit            = optional(string, "1Gi")<br/>    in_place_rollout        = optional(bool, false)<br/>    request_rollout         = optional(string)<br/>    force_rollout           = optional(string)<br/>    balancer_memory_request = optional(string, "256Mi")<br/>    balancer_memory_limit   = optional(string, "256Mi")<br/>    balancer_cpu_request    = optional(string, "100m")<br/>  }))</pre> | `[]` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Kubernetes namespace for Materialize | `string` | `"materialize"` | no |
| <a name="input_network_config"></a> [network\_config](#input\_network\_config) | Network configuration for the GKE cluster | <pre>object({<br/>    subnet_cidr   = string<br/>    pods_cidr     = string<br/>    services_cidr = string<br/>  })</pre> | n/a | yes |
| <a name="input_operator_namespace"></a> [operator\_namespace](#input\_operator\_namespace) | Namespace for the Materialize operator | `string` | `"materialize"` | no |
| <a name="input_operator_version"></a> [operator\_version](#input\_operator\_version) | Version of the Materialize operator to install | `string` | `null` | no |
| <a name="input_orchestratord_version"></a> [orchestratord\_version](#input\_orchestratord\_version) | Version of the Materialize orchestrator to install | `string` | `null` | no |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | Prefix to be used for resource names | `string` | `"materialize"` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The ID of the project where resources will be created | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | The region where resources will be created | `string` | `"us-central1"` | no |
| <a name="input_use_local_chart"></a> [use\_local\_chart](#input\_use\_local\_chart) | Whether to use a local chart instead of one from a repository | `bool` | `false` | no |
| <a name="input_use_self_signed_cluster_issuer"></a> [use\_self\_signed\_cluster\_issuer](#input\_use\_self\_signed\_cluster\_issuer) | Whether to install and use a self-signed ClusterIssuer for TLS. Due to limitations in Terraform, this may not be enabled before the cert-manager CRDs are installed. | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_connection_strings"></a> [connection\_strings](#output\_connection\_strings) | Formatted connection strings for Materialize |
| <a name="output_database"></a> [database](#output\_database) | Cloud SQL instance details |
| <a name="output_gke_cluster"></a> [gke\_cluster](#output\_gke\_cluster) | GKE cluster details |
| <a name="output_load_balancer_details"></a> [load\_balancer\_details](#output\_load\_balancer\_details) | Details of the Materialize instance load balancers. |
| <a name="output_network"></a> [network](#output\_network) | Network details |
| <a name="output_operator"></a> [operator](#output\_operator) | Materialize operator details |
| <a name="output_service_accounts"></a> [service\_accounts](#output\_service\_accounts) | Service account details |
| <a name="output_storage"></a> [storage](#output\_storage) | GCS bucket details |

## Connecting to Materialize instances

Access to the database is through the balancerd pods on:
* Port 6875 for SQL connections.
* Port 6876 for HTTP(S) connections.

Access to the web console is through the console pods on port 8080.

#### TLS support

For example purposes, optional TLS support is provided by using `cert-manager` and a self-signed `ClusterIssuer`.

More advanced TLS support using user-provided CAs or per-Materialize `Issuer`s are out of scope for this Terraform module. Please refer to the [cert-manager documentation](https://cert-manager.io/docs/configuration/) for detailed guidance on more advanced usage.

###### To enable installation of `cert-manager` and configuration of the self-signed `ClusterIssuer`
1. Set `install_cert_manager` to `true`.
1. Run `terraform apply`.
1. Set `use_self_signed_cluster_issuer` to `true`.
1. Run `terraform apply`.

Due to limitations in Terraform, it cannot plan Kubernetes resources using CRDs that do not exist yet. We need to first install `cert-manager` in the first `terraform apply`, before defining any `ClusterIssuer` or `Certificate` resources which get created in the second `terraform apply`.
<!-- END_TF_DOCS -->
