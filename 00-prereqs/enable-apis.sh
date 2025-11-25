#!/bin/bash

set -e

echo "Enabling required GCP APIs..."

if [ -z "$PROJECT_ID" ]; then
    echo "ERROR: PROJECT_ID environment variable is not set"
    echo "Please run: export PROJECT_ID=your-project-id"
    exit 1
fi

echo "Project ID: $PROJECT_ID"

gcloud services enable container.googleapis.com \
  artifactregistry.googleapis.com \
  sqladmin.googleapis.com \
  secretmanager.googleapis.com \
  monitoring.googleapis.com \
  logging.googleapis.com \
  cloudresourcemanager.googleapis.com \
  iam.googleapis.com \
  compute.googleapis.com \
  --project=$PROJECT_ID

echo "✓ All required APIs enabled successfully!"
echo ""
echo "Enabled APIs:"
echo "  - Kubernetes Engine API (container.googleapis.com)"
echo "  - Artifact Registry API (artifactregistry.googleapis.com)"
echo "  - Cloud SQL Admin API (sqladmin.googleapis.com)"
echo "  - Secret Manager API (secretmanager.googleapis.com)"
echo "  - Cloud Monitoring API (monitoring.googleapis.com)"
echo "  - Cloud Logging API (logging.googleapis.com)"
echo "  - Cloud Resource Manager API (cloudresourcemanager.googleapis.com)"
echo "  - IAM API (iam.googleapis.com)"
echo "  - Compute Engine API (compute.googleapis.com)"
echo ""
echo "Next step: Run ./create-gke-autopilot.sh to create your cluster"
