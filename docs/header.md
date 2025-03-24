# Materialize on Google Cloud Platform

Terraform module for deploying Materialize on Google Cloud Platform (GCP) with all required infrastructure components.

This module sets up:
- GKE cluster for Materialize workloads
- Cloud SQL PostgreSQL instance for metadata storage
- Cloud Storage bucket for persistence
- Required networking and security configurations
- Service accounts with proper IAM permissions

> [!WARNING]
> This module is intended to be used for demonstrations, simple evaluations, and as a template for building your own production deployment of Materialize.
>
> This module should not be relied upon for production deployments directly: future releases of the module will contain breaking changes. When used as a starting point for a production deployment, you must either fork this repo and pin to a specific version, or use the code as a reference when developing your own deployment.

The module has been tested with:
- GKE version 1.28
- PostgreSQL 15
- Materialize Operator v0.1.0
