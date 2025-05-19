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


## Disk Support for Materialize on GCP

This module supports configuring disk support for Materialize using local SSDs in GCP with OpenEBS and lgalloc.

### Machine Types with Local SSDs in GCP

When using disk support for Materialize on GCP, you need to use machine types that support local SSD attachment. Here are some recommended machine types:

* [N2 series](https://cloud.google.com/compute/docs/general-purpose-machines#n2d_machine_types) with local NVMe SSDs:
   * For memory-optimized workloads, consider `n2-highmem-16` or `n2-highmem-32` with local NVMe SSDs
   * Example: `n2-highmem-32` with 4 or more local SSDs

* [N2D series](https://cloud.google.com/compute/docs/general-purpose-machines#n2d_machine_types) with local NVMe SSDs:
   * For memory-optimized workloads, consider `n2d-highmem-16` or `n2d-highmem-32` with local NVMe SSDs
   * Example: `n2d-highmem-32` with 2 or more local SSDs

> [!NOTE] Your machine type may only support predefined number of local SSD
> disks. For instance, `n2d-highmem-32`
> only accepts `2`, `4`, `8`, `16`, or `24`. To determine the number of
> Local SSD disks to attach, see the [GCP
> documentation](https://cloud.google.com/compute/docs/disks/local-ssd#lssd_disk_options).

### Enabling Disk Support

By default, the module enables disk support. The default setting used by the Terraform module:

```hcl
enable_disk_support = true

gke_config = {
  node_count   = 1

  # This machine has 64GB RAM
  machine_type = "n2-highmem-8"

  # This is for the OS disk, not for Materialize data
  disk_size_gb = 100
  min_nodes    = 1
  max_nodes    = 2
}

disk_support_config = {
  install_openebs = true
  run_disk_setup_script = true
  
  # Each local NVMe SSD in GCP provides 375GB of storage.
  # local_ssd_count = 1 provides 1 x 375GB = 375GB of local SSD storage
  # Meeting/exceeding the minimum recommended 2:1 disk-to-RAM ratio (375GB disk:64GB RAM)
  local_ssd_count = 1
  
  create_storage_class = true
  openebs_version ="4.2.0"
  openebs_namespace = "openebs"
  storage_class_name = "openebs-lvm-instance-store-ext4"
}
  
```

This configuration:
1. Attaches one local SSD to each node, providing 375GB of storage per node. This ensures that the disk-to-RAM ratio is greater than the minimum 2:1 for the `n2-highmem-8` instance (which has 64GB RAM)
3. Installs OpenEBS via Helm to manage these local SSDs
4. Configures local NVMe SSD devices using the [bootstrap Docker image](https://github.com/MaterializeInc/ephemeral-storage-setup-imageh)
5. Creates appropriate storage classes for Materialize

### Advanced Configuration Example

For a different machine type with appropriate disk sizing:

```hcl
enable_disk_support = true

gke_config = {
  node_count   = 3
  # This machine has 256GB RAM
  machine_type = "n2d-highmem-32"
  disk_size_gb = 100 // This is for the OS disk, not for Materialize data
  min_nodes    = 3
  max_nodes    = 5
}

disk_support_config = {
  openebs_version    = "4.2.0"
  storage_class_name = "custom-storage-class"
  
  # Each local NVMe SSD in GCP provides 375GB of storage.
  # local_ssd_count provides 2 x 375GB = 750GB of local NVMe SSD storage per node.
  # Meets/exceeds the minimum 2:1 disk-to-RAM ratio (750GB disk: 256GB RAM)
  local_ssd_count = 2 // 
}
```

### Calculating the Right Number of Local SSDs

The following table helps you determine the appropriate number of local SSDs based on your chosen machine type to maintain the recommended 2:1 disk-to-RAM ratio:
> [!NOTE] The table below specifies a minimum number of local SSDs needed to
> meet the 2:1 ratio. However, your machine type may only support predefined
> number of local SSD. For instance, `n2-highmem-32`
> only accepts `4`, `8`, `16`, or `24`. To determine the valid number of
> Local SSD disks to attach for your machine type, see the [GCP
> documentation](https://cloud.google.com/compute/docs/disks/local-ssd#lssd_disk_options).

| Machine Type    | RAM     | Required Disk | Minimum Local SSD Count | Total SSD Storage |
|-----------------|---------|---------------|-----------------------------|-------------------|
| `n2-highmem-8`  | `64GB`  | `128GB`       | 1                           | `375GB`           |
| `n2-highmem-16` | `128GB` | `256GB`       | 1                           | `375GB`           |
| `n2-highmem-32` | `256GB` | `512GB`       | 2                           | `750GB`           |
| `n2-highmem-64` | `512GB` | `1024GB`      | 3                           | `1125GB`          |
| `n2-highmem-80` | `640GB` | `1280GB`      | 4                           | `1500GB`          |

Remember that each local NVMe SSD in GCP provides 375GB of storage.
Choose the appropriate `local_ssd_count` to make sure your total disk space is at least twice the amount of RAM in your machine type for optimal Materialize performance.

## `materialize_instances` variable

The `materialize_instances` variable is a list of objects that define the configuration for each Materialize instance.

### `environmentd_extra_env`

Optional list of extra environment variables to pass to the `environmentd` container. This allows you to pass any additional configuration supported by Materialize.

Each entry should be an object with `name` and `value` fields:

```hcl
environmentd_extra_env = [
  {
    name  = "MZ_LOG_FILTER"
    value = "materialized::coord=debug"
  }
]
```

### `environmentd_extra_args`

Optional list of additional command-line arguments to pass to the `environmentd` container. This can be used to override default system parameters or enable specific features.

```hcl
environmentd_extra_args = [
  "--system-parameter-default=max_clusters=1000",
  "--system-parameter-default=max_connections=1000",
  "--system-parameter-default=max_tables=1000",
]
```

These flags configure default limits for clusters, connections, and tables. You can provide any supported arguments [here](https://materialize.com/docs/sql/alter-system-set/#other-configuration-parameters).
