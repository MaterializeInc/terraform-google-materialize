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
