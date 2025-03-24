# Materialize on Google Cloud Platform

Terraform module for deploying Materialize on Google Cloud Platform (GCP) with all required infrastructure components.

This module sets up:
- GKE cluster for Materialize workloads
- Cloud SQL PostgreSQL instance for metadata storage
- Cloud Storage bucket for persistence
- Required networking and security configurations
- Service accounts with proper IAM permissions

> [!WARNING]
> This module is provided on a best-effort basis and Materialize cannot offer support for it.
>
> It is not guaranteed to be forward-compatible and may include breaking changes in future versions.
>
> The module is intended for demonstration and evaluation purposes only, not for production use.
>
> Instead, consider forking this repository as a starting point for building your own production infrastructure.

The module has been tested with:
- GKE version 1.28
- PostgreSQL 15
- Materialize Operator v0.1.0
