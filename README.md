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
- terraform-helm-materialize v0.1.12 (Materialize Operator v25.1.7)

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
| <a name="module_operator"></a> [operator](#module\_operator) | github.com/MaterializeInc/terraform-helm-materialize | v0.1.12 |
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
| <a name="input_gke_config"></a> [gke\_config](#input\_gke\_config) | GKE cluster configuration. Make sure to use large enough machine types for your Materialize instances. | <pre>object({<br/>    node_count   = number<br/>    machine_type = string<br/>    disk_size_gb = number<br/>    min_nodes    = number<br/>    max_nodes    = number<br/>  })</pre> | <pre>{<br/>  "disk_size_gb": 50,<br/>  "machine_type": "e2-standard-4",<br/>  "max_nodes": 2,<br/>  "min_nodes": 1,<br/>  "node_count": 1<br/>}</pre> | no |
| <a name="input_helm_chart"></a> [helm\_chart](#input\_helm\_chart) | Chart name from repository or local path to chart. For local charts, set the path to the chart directory. | `string` | `"materialize-operator"` | no |
| <a name="input_helm_values"></a> [helm\_values](#input\_helm\_values) | Values to pass to the Helm chart | `any` | `{}` | no |
| <a name="input_install_cert_manager"></a> [install\_cert\_manager](#input\_install\_cert\_manager) | Whether to install cert-manager. | `bool` | `true` | no |
| <a name="input_install_materialize_operator"></a> [install\_materialize\_operator](#input\_install\_materialize\_operator) | Whether to install the Materialize operator | `bool` | `true` | no |
| <a name="input_install_metrics_server"></a> [install\_metrics\_server](#input\_install\_metrics\_server) | Whether to install the metrics-server for the Materialize Console. Defaults to false since GKE installs one by default in the kube-system namespace. Only set to true if the GKE cluster was deployed with [monitoring explicitly turned off](https://cloud.google.com/kubernetes-engine/docs/how-to/configure-metrics#:~:text=To%20disable%20system%20metric%20collection,for%20the%20%2D%2Dmonitoring%20flag). Refer to the [GKE docs](https://cloud.google.com/kubernetes-engine/docs/how-to/configure-metrics#:~:text=To%20disable%20system%20metric%20collection,for%20the%20%2D%2Dmonitoring%20flag) for more information, including impact to GKE customer support efforts. | `bool` | `false` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | Labels to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_materialize_instances"></a> [materialize\_instances](#input\_materialize\_instances) | Configuration for Materialize instances | <pre>list(object({<br/>    name                    = string<br/>    namespace               = optional(string)<br/>    database_name           = string<br/>    create_database         = optional(bool, true)<br/>    create_load_balancer    = optional(bool, true)<br/>    internal_load_balancer  = optional(bool, true)<br/>    environmentd_version    = optional(string)<br/>    cpu_request             = optional(string, "1")<br/>    memory_request          = optional(string, "1Gi")<br/>    memory_limit            = optional(string, "1Gi")<br/>    in_place_rollout        = optional(bool, false)<br/>    request_rollout         = optional(string)<br/>    force_rollout           = optional(string)<br/>    balancer_memory_request = optional(string, "256Mi")<br/>    balancer_memory_limit   = optional(string, "256Mi")<br/>    balancer_cpu_request    = optional(string, "100m")<br/>    license_key             = optional(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Kubernetes namespace for Materialize | `string` | `"materialize"` | no |
| <a name="input_network_config"></a> [network\_config](#input\_network\_config) | Network configuration for the GKE cluster | <pre>object({<br/>    subnet_cidr   = string<br/>    pods_cidr     = string<br/>    services_cidr = string<br/>  })</pre> | n/a | yes |
| <a name="input_operator_namespace"></a> [operator\_namespace](#input\_operator\_namespace) | Namespace for the Materialize operator | `string` | `"materialize"` | no |
| <a name="input_operator_version"></a> [operator\_version](#input\_operator\_version) | Version of the Materialize operator to install | `string` | `null` | no |
| <a name="input_orchestratord_version"></a> [orchestratord\_version](#input\_orchestratord\_version) | Version of the Materialize orchestrator to install | `string` | `null` | no |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | Prefix to be used for resource names | `string` | `"materialize"` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The ID of the project where resources will be created | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | The region where resources will be created | `string` | `"us-central1"` | no |
| <a name="input_storage_bucket_version_ttl"></a> [storage\_bucket\_version\_ttl](#input\_storage\_bucket\_version\_ttl) | Sets the TTL (in days) on non current storage bucket objects. This must be set if storage\_bucket\_versioning is turned on. | `number` | `7` | no |
| <a name="input_storage_bucket_versioning"></a> [storage\_bucket\_versioning](#input\_storage\_bucket\_versioning) | Enable bucket versioning. This should be enabled for production deployments. | `bool` | `false` | no |
| <a name="input_use_local_chart"></a> [use\_local\_chart](#input\_use\_local\_chart) | Whether to use a local chart instead of one from a repository | `bool` | `false` | no |
| <a name="input_use_self_signed_cluster_issuer"></a> [use\_self\_signed\_cluster\_issuer](#input\_use\_self\_signed\_cluster\_issuer) | Whether to install and use a self-signed ClusterIssuer for TLS. To work around limitations in Terraform, this will be treated as `false` if no materialize instances are defined. | `bool` | `true` | no |

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

TLS support is provided by using `cert-manager` and a self-signed `ClusterIssuer`.

More advanced TLS support using user-provided CAs or per-Materialize `Issuer`s are out of scope for this Terraform module. Please refer to the [cert-manager documentation](https://cert-manager.io/docs/configuration/) for detailed guidance on more advanced usage.

## Upgrade Notes

#### v0.3.0

We now install `cert-manager` and configure a self-signed `ClusterIssuer` by default.

Due to limitations in Terraform, it cannot plan Kubernetes resources using CRDs that do not exist yet. We have worked around this for new users by only generating the certificate resources when creating Materialize instances that use them, which also cannot be created on the first run.

For existing users upgrading Materialize instances not previously configured for TLS:
1. Leave `install_cert_manager` at its default of `true`.
2. Set `use_self_signed_cluster_issuer` to `false`.
3. Run `terraform apply`. This will install cert-manager and its CRDs.
4. Set `use_self_signed_cluster_issuer` back to `true` (the default).
5. Update the `request_rollout` field of the Materialize instance.
6. Run `terraform apply`. This will generate the certificates and configure your Materialize instance to use them.
<!-- END_TF_DOCS -->



#### Storage Bucket Versioning
By default storage bucket versioning is turned off. This both reduces
costs and allows for easier cleanup of resources for testing. When running in
production, versioning should be turned on with a sufficient TTL to meet any
data-recovery requirements. See `storage_bucket_versioning` and `storage_bucket_version_ttl`.
