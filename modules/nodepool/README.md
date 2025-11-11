## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 6.31, < 7 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.10.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | >= 6.31, < 7 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | >= 2.10.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [google_container_node_pool.primary_nodes](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_node_pool) | resource |
| [kubernetes_cluster_role.disk_setup](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role) | resource |
| [kubernetes_cluster_role_binding.disk_setup](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role_binding) | resource |
| [kubernetes_daemonset.disk_setup](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/daemonset) | resource |
| [kubernetes_namespace.disk_setup](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_service_account.disk_setup](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | The name of the GKE cluster | `string` | n/a | yes |
| <a name="input_disk_setup_container_resource_config"></a> [disk\_setup\_container\_resource\_config](#input\_disk\_setup\_container\_resource\_config) | Resource configuration for disk setup init container | <pre>object({<br/>    memory_limit   = string<br/>    memory_request = string<br/>    cpu_request    = string<br/>  })</pre> | <pre>{<br/>  "cpu_request": "50m",<br/>  "memory_limit": "128Mi",<br/>  "memory_request": "128Mi"<br/>}</pre> | no |
| <a name="input_disk_setup_image"></a> [disk\_setup\_image](#input\_disk\_setup\_image) | Docker image for the disk setup script | `string` | `"materialize/ephemeral-storage-setup-image:v0.4.0"` | no |
| <a name="input_disk_size_gb"></a> [disk\_size\_gb](#input\_disk\_size\_gb) | The disk size in GB for each node | `number` | `100` | no |
| <a name="input_enable_private_nodes"></a> [enable\_private\_nodes](#input\_enable\_private\_nodes) | Whether to enable private nodes | `bool` | `true` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | Labels to apply to the nodes | `map(string)` | `{}` | no |
| <a name="input_local_ssd_count"></a> [local\_ssd\_count](#input\_local\_ssd\_count) | Number of local NVMe SSDs to attach to each node. In GCP, each disk is 375GB. For Materialize, you need to have a 1:2 ratio of disk to memory. If you have 8 CPUs and 64GB of memory, you need 128GB of disk. This means you need at least 1 local NVMe SSD. If you go with a larger machine type, you can increase the number of local NVMe SSDs. | `number` | `1` | no |
| <a name="input_machine_type"></a> [machine\_type](#input\_machine\_type) | The machine type for the nodes | `string` | `"e2-medium"` | no |
| <a name="input_max_nodes"></a> [max\_nodes](#input\_max\_nodes) | The maximum number of nodes in the autoscaling group | `number` | `10` | no |
| <a name="input_min_nodes"></a> [min\_nodes](#input\_min\_nodes) | The minimum number of nodes in the autoscaling group | `number` | `1` | no |
| <a name="input_node_taints"></a> [node\_taints](#input\_node\_taints) | Taints to apply to the node pool. | <pre>list(object({<br/>    key    = string<br/>    value  = string<br/>    effect = string<br/>  }))</pre> | `[]` | no |
| <a name="input_oauth_scopes"></a> [oauth\_scopes](#input\_oauth\_scopes) | OAuth scopes to assign to the node pool service account | `list(string)` | <pre>[<br/>  "https://www.googleapis.com/auth/cloud-platform"<br/>]</pre> | no |
| <a name="input_pause_container_resource_config"></a> [pause\_container\_resource\_config](#input\_pause\_container\_resource\_config) | Resource configuration for pause container | <pre>object({<br/>    memory_limit   = string<br/>    memory_request = string<br/>    cpu_request    = string<br/>  })</pre> | <pre>{<br/>  "cpu_request": "1m",<br/>  "memory_limit": "8Mi",<br/>  "memory_request": "8Mi"<br/>}</pre> | no |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | Prefix to be used for resource names | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The GCP project ID | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | The region where the cluster is located | `string` | n/a | yes |
| <a name="input_service_account_email"></a> [service\_account\_email](#input\_service\_account\_email) | The email of the service account to use for the nodes | `string` | n/a | yes |
| <a name="input_swap_enabled"></a> [swap\_enabled](#input\_swap\_enabled) | Whether to enable swap on the local NVMe disks. | `bool` | `true` | no |
| <a name="input_workload_metadata_mode"></a> [workload\_metadata\_mode](#input\_workload\_metadata\_mode) | Mode for workload metadata configuration | `string` | `"GKE_METADATA"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_instance_group_urls"></a> [instance\_group\_urls](#output\_instance\_group\_urls) | List of instance group URLs for the node pool |
| <a name="output_node_count"></a> [node\_count](#output\_node\_count) | The current number of nodes in the pool |
| <a name="output_node_pool_id"></a> [node\_pool\_id](#output\_node\_pool\_id) | The ID of the node pool |
| <a name="output_node_pool_name"></a> [node\_pool\_name](#output\_node\_pool\_name) | The name of the node pool |
