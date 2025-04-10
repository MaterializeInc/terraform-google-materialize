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
   * For memory-optimized workloads similar to AWS r7gd, consider `n2-highmem-16` or `n2-highmem-32` with local NVMe SSDs
   * Example: `n2-highmem-32` with 2 or more local SSDs

### Enabling Disk Support

To enable disk support with default settings in your Terraform configuration:

```hcl
enable_disk_support = true

gke_config = {
  node_count   = 3

  # This machine has 256GB RAM
  machine_type = "n2-highmem-32"

  # This is for the OS disk, not for Materialize data
  disk_size_gb = 100
  min_nodes    = 3
  max_nodes    = 5

  # This provides 2 x 375GB = 750GB of local SSD storage
  # Exceeding the 2:1 disk-to-RAM ratio (256GB RAM : 750GB disk)
  local_ssd_count = 2
}
```

This configuration:
1. Attaches two local SSDs to each node, providing 750GB of storage per node
2. Ensures the disk-to-RAM ratio is greater than 2:1 for the n2-highmem-32 instance (which has 256GB RAM)
3. Installs OpenEBS via Helm to manage these local SSDs
4. Configures local NVMe SSD devices using the [bootstrap](./modules/gke/bootstrap.sh) script
5. Creates appropriate storage classes for Materialize

### Advanced Configuration Example

For a different machine type with appropriate disk sizing:

```hcl
enable_disk_support = true

gke_config = {
  node_count   = 3
  # This machine has 128GB RAM
  machine_type = "n2-highmem-16"
  disk_size_gb = 100
  min_nodes    = 3
  max_nodes    = 5
  # This provides 1 x 375GB = 375GB of local NVMe SSD storage
  # Exceeding the 2:1 disk-to-RAM ratio (128GB RAM : 375GB disk)
  local_ssd_count = 1
}

disk_support_config = {
  openebs_version    = "4.2.0"
  storage_class_name = "custom-storage-class"
}
```

### Calculating the Right Number of Local SSDs

The following table helps you determine the appropriate number of local SSDs based on your chosen machine type to maintain the recommended 2:1 disk-to-RAM ratio:

| Machine Type    | RAM     | Required Disk | Recommended Local SSD Count | Total SSD Storage |
|-----------------|---------|---------------|-----------------------------|-------------------|
| `n2-highmem-8`  | `64GB`  | `128GB`       | 1                           | `375GB`           |
| `n2-highmem-16` | `128GB` | `256GB`       | 1                           | `375GB`           |
| `n2-highmem-32` | `256GB` | `512GB`       | 2                           | `750GB`           |
| `n2-highmem-64` | `512GB` | `1024GB`      | 3                           | `1125GB`          |
| `n2-highmem-80` | `640GB` | `1280GB`      | 4                           | `1500GB`          |

Remember that each local NVMe SSD in GCP provides 375GB of storage.
Choose the appropriate `local_ssd_count` to make sure your total disk space is at least twice the amount of RAM in your machine type for optimal Materialize performance.

### Local SSD Limitations in GCP

Note that there are some differences between AWS NVMe instance store and GCP local SSDs:

1. GCP local NVMe SSDs have a fixed size of 375 GB each
2. Local SSDs must be attached at instance creation time
3. The number of local SSDs you can attach depends on the machine type
4. Data on local SSDs is lost when the instance stops or is deleted
