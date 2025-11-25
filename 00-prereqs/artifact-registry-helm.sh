#!/bin/bash

set -e

echo "Setting up Artifact Registry for Helm charts..."

if [ -z "$PROJECT_ID" ]; then
    echo "ERROR: PROJECT_ID environment variable is not set"
    echo "Please run: export PROJECT_ID=your-project-id"
    exit 1
fi

if [ -z "$REGION" ]; then
    echo "WARNING: REGION not set, using default: us-central1"
    export REGION="us-central1"
fi

REPO_NAME="${REPO_NAME:-helm-charts}"

echo "Configuration:"
echo "  Project ID: $PROJECT_ID"
echo "  Region: $REGION"
echo "  Repository Name: $REPO_NAME"
echo ""

echo "Creating Artifact Registry repository..."
gcloud artifacts repositories create $REPO_NAME \
  --repository-format=docker \
  --location=$REGION \
  --description="Helm charts repository" \
  --project=$PROJECT_ID

echo "✓ Repository created successfully!"
echo ""

echo "Configuring Docker authentication..."
gcloud auth configure-docker ${REGION}-docker.pkg.dev

echo "✓ Docker authentication configured!"
echo ""

export HELM_REGISTRY="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}"

echo "✓ Helm registry configured!"
echo ""
echo "Helm Registry URL: $HELM_REGISTRY"
echo ""
echo "Add this to your ~/.bashrc or ~/.zshrc:"
echo "export HELM_REGISTRY=\"${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}\""
echo ""
echo "To push a Helm chart:"
echo "  helm package my-chart/"
echo "  helm push my-chart-0.1.0.tgz oci://\$HELM_REGISTRY"
echo ""
echo "To pull a Helm chart:"
echo "  helm pull oci://\$HELM_REGISTRY/my-chart --version 0.1.0"
echo ""
echo "Next step: Run ./workload-identity.sh to configure Workload Identity"
