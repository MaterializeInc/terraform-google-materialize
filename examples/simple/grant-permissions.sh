#!/bin/bash

# Script to grant required IAM permissions to fix Terraform permission errors
# Replace PROJECT_ID and USER_EMAIL with your actual values

PROJECT_ID=<PROJECT_ID>
USER_EMAIL=<USER_EMAIL>

echo "Granting required IAM permissions to $USER_EMAIL for project $PROJECT_ID..."

# Grant Service Account Admin role for IAM operations
echo "Granting Service Account Admin role..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="user:$USER_EMAIL" \
  --role="roles/iam.serviceAccountAdmin"

# Alternative: Grant specific workload identity permission (less permissive)
echo "Granting Workload Identity User role..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="user:$USER_EMAIL" \
  --role="roles/iam.workloadIdentityUser"

# Grant Container Admin role for full cluster access
echo "Granting Container Admin role for GKE cluster management..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="user:$USER_EMAIL" \
  --role="roles/container.admin"

echo "Permissions granted! You should now be able to run terraform apply successfully."
