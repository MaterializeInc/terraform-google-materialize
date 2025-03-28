# Materialize on Google Cloud Platform (GCP) - Setup Guide

## Overview
This guide helps you set up the required infrastructure for running Materialize on Google Cloud Platform (GCP). It handles the creation of:
- A Kubernetes cluster (GKE) for running Materialize
- A managed PostgreSQL database (Cloud SQL)
- Storage buckets
- Networking setup

## Prerequisites

### 1. GCP Account & Project
You need a GCP account and a project. If you don't have one:
1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create a new project or select an existing one
3. Make sure billing is enabled for your project

### 2. Required APIs
Your GCP project needs several APIs enabled. Here's what each API does in simple terms:

```bash
# Enable these APIs in your project
gcloud services enable container.googleapis.com          # For creating Kubernetes clusters
gcloud services enable sqladmin.googleapis.com          # For creating databases
gcloud services enable cloudresourcemanager.googleapis.com    # For managing GCP resources
gcloud services enable servicenetworking.googleapis.com       # For private network connections
gcloud services enable iamcredentials.googleapis.com          # For security and authentication
```

### 3. Required Permissions
The account or service account running Terraform needs these permissions:

1. **Editor** (`roles/editor`)
   - Allows creation and management of most GCP resources
   - Like having admin access to create infrastructure

2. **Service Account Admin** (`roles/iam.serviceAccountAdmin`)
   - Allows creation and management of service accounts
   - Think of this as being able to create "robot users" for different services

3. **Service Networking Admin** (`roles/servicenetworking.networksAdmin`)
   - Allows setting up private network connections
   - Needed for secure communication between services

To grant these permissions, run:
```bash
# Replace these with your values:
PROJECT_ID="your-project-id"
SERVICE_ACCOUNT="your-service-account@your-project.iam.gserviceaccount.com"

# Grant the permissions
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SERVICE_ACCOUNT" \
  --role="roles/editor"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SERVICE_ACCOUNT" \
  --role="roles/iam.serviceAccountAdmin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SERVICE_ACCOUNT" \
  --role="roles/servicenetworking.networksAdmin"
```

Install the GKE `gcloud` authentication plugin to interact with GKE clusters

```bash
gcloud components install gke-gcloud-auth-plugin --project=$PROJECT_ID
```

## Setting Up Terraform

### 1. Authentication
There are several ways to authenticate with GCP, see the [Terraform GCP provider documentation](https://registry.terraform.io/providers/hashicorp/google/latest/docs/guides/provider_reference#authentication) for more information.

Here are two common ways:

1. **Service Account Key File**:
   ```bash
   export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account-key.json"
   ```

2. **Google Cloud SDK** (Good for local development):
   ```bash
   gcloud auth application-default login
   ```

### 2. Deploying

Access the `examples/simple` directory and follow these steps:

1. Initialize Terraform:
   ```bash
   terraform init
   ```

2. Preview the changes:
   ```bash
   terraform plan \
     -var project_id="your-project-id" \
     -var prefix="your-resource-prefix" \
     -var region="us-central1"
   ```

   Alternatively, you can set these variables in a `terraform.tfvars` file:
   ```bash
    project_id = "your-project-id"
    prefix = "your-resource-prefix"
    region="your-region"
    ```

3. Apply the changes:
   ```bash
   terraform apply \
     -var project_id="your-project-id" \
     -var prefix="your-resource-prefix" \
     -var region="us-central1"
   ```

4. When you're done, clean up:
   ```bash
   terraform destroy \
     -var project_id="your-project-id" \
     -var prefix="your-resource-prefix" \
     -var region="us-central1"
   ```

5. The `connection_strings` output will provide you with the connection strings for metadata and persistence backends.

After successfully deploying the infrastructure, you'll need to configure `kubectl` to interact with your new GKE cluster. Here's how:

```sh
# Get cluster credentials and configure kubectl
gcloud container clusters get-credentials $(terraform output -json gke_cluster | jq -r .name) \
    --region $(terraform output -json gke_cluster | jq -r .location) \
    --project materialize-ci
```

After running this command, you can verify your connection:

```sh
# Verify cluster connection
kubectl cluster-info
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 6.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 2.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 2.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | 6.23.0 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.7.1 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_materialize"></a> [materialize](#module\_materialize) | ../.. | n/a |

## Resources

| Name | Type |
|------|------|
| [random_password.pass](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [google_client_config.default](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/client_config) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_install_cert_manager"></a> [install\_cert\_manager](#input\_install\_cert\_manager) | Whether to install cert-manager. | `bool` | `false` | no |
| <a name="input_materialize_instances"></a> [materialize\_instances](#input\_materialize\_instances) | List of Materialize instances to be created. | <pre>list(object({<br/>    name                    = string<br/>    namespace               = optional(string)<br/>    database_name           = string<br/>    create_database         = optional(bool, true)<br/>    environmentd_version    = optional(string, "v0.130.4")<br/>    cpu_request             = optional(string, "1")<br/>    memory_request          = optional(string, "1Gi")<br/>    memory_limit            = optional(string, "1Gi")<br/>    in_place_rollout        = optional(bool, false)<br/>    request_rollout         = optional(string)<br/>    force_rollout           = optional(string)<br/>    balancer_memory_request = optional(string, "256Mi")<br/>    balancer_memory_limit   = optional(string, "256Mi")<br/>    balancer_cpu_request    = optional(string, "100m")<br/>  }))</pre> | `[]` | no |
| <a name="input_operator_version"></a> [operator\_version](#input\_operator\_version) | Version of the Materialize operator to install | `string` | `null` | no |
| <a name="input_orchestratord_version"></a> [orchestratord\_version](#input\_orchestratord\_version) | Version of the Materialize orchestrator to install | `string` | `null` | no |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | Used to prefix the names of the resources | `string` | `"mz-simple"` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | GCP Project ID | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | GCP Region | `string` | `"us-central1"` | no |
| <a name="input_use_self_signed_cluster_issuer"></a> [use\_self\_signed\_cluster\_issuer](#input\_use\_self\_signed\_cluster\_issuer) | Whether to install and use a self-signed ClusterIssuer for TLS. Due to limitations in Terraform, this may not be enabled before the cert-manager CRDs are installed. | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_connection_strings"></a> [connection\_strings](#output\_connection\_strings) | Connection strings for metadata and persistence backends |
| <a name="output_gke_cluster"></a> [gke\_cluster](#output\_gke\_cluster) | GKE cluster details |
| <a name="output_network"></a> [network](#output\_network) | Network details |
| <a name="output_service_accounts"></a> [service\_accounts](#output\_service\_accounts) | Service account details |
<!-- END_TF_DOCS -->