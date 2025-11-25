#!/bin/bash

set -e

echo "Creating GKE Autopilot cluster..."

if [ -z "$PROJECT_ID" ]; then
    echo "ERROR: PROJECT_ID environment variable is not set"
    echo "Please run: export PROJECT_ID=your-project-id"
    exit 1
fi

if [ -z "$REGION" ]; then
    echo "WARNING: REGION not set, using default: us-central1"
    export REGION="us-central1"
fi

CLUSTER_NAME="${CLUSTER_NAME:-helm-learning-cluster}"

echo "Configuration:"
echo "  Project ID: $PROJECT_ID"
echo "  Region: $REGION"
echo "  Cluster Name: $CLUSTER_NAME"
echo ""

echo "Creating Autopilot cluster (this takes 5-10 minutes)..."
gcloud container clusters create-auto $CLUSTER_NAME \
  --region=$REGION \
  --project=$PROJECT_ID

echo "✓ Cluster created successfully!"
echo ""

echo "Configuring kubectl..."
gcloud container clusters get-credentials $CLUSTER_NAME \
  --region=$REGION \
  --project=$PROJECT_ID

echo "✓ kubectl configured!"
echo ""

echo "Verifying cluster..."
kubectl get nodes
kubectl cluster-info

echo ""
echo "✓ GKE Autopilot cluster is ready!"
echo ""
echo "Cluster details:"
kubectl get nodes -o wide
echo ""
echo "Next step: Run ./artifact-registry-helm.sh to set up Helm registry"
