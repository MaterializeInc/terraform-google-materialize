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

## `materialize_instances` variable

The `materialize_instances` variable is a list of objects that define the configuration for each Materialize instance.

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
