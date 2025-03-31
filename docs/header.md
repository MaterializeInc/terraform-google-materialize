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
