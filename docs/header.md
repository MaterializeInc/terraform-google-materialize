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
