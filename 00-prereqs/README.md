# Prerequisites - GCP Setup

This guide walks you through setting up your GCP environment for running Helm charts on GKE.

## Overview

Before deploying Helm charts, you need to:
1. Create a GCP project
2. Enable required APIs
3. Create a GKE Autopilot cluster
4. Set up Artifact Registry for Helm charts
5. Configure Workload Identity
6. Install required tools

## Cost Considerations

**Free Tier Coverage:**
- GKE Autopilot: $74.40/month free cluster management fee
- $300 free trial credits for 90 days
- Always Free tier for many services

**What Consumes Credits:**
- GKE Autopilot compute resources (minimal with small workloads)
- Cloud SQL instances
- Load Balancers
- Persistent Disks

**Cost Savings:**
- Use Autopilot (no node management fees)
- Keep resource requests small (100m CPU, 128Mi memory)
- Delete resources when not in use
- Use in-cluster databases for learning

## Prerequisites

### Required Tools

```bash
# Install gcloud CLI
curl https://sdk.cloud.google.com | bash
exec -l $SHELL

# Install kubectl
gcloud components install kubectl

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify installations
gcloud version
kubectl version --client
helm version
```

## Setup Steps

### 1. Create GCP Project

```bash
# Set your project ID (change this to your desired project ID)
export PROJECT_ID="my-helm-gcp-project"
export REGION="us-central1"
export ZONE="us-central1-a"

# Create project
gcloud projects create $PROJECT_ID --name="Helm GCP Learning"

# Set as default project
gcloud config set project $PROJECT_ID

# Link billing account (required for free trial)
# List billing accounts
gcloud billing accounts list

# Link billing (replace BILLING_ACCOUNT_ID)
gcloud billing projects link $PROJECT_ID --billing-account=BILLING_ACCOUNT_ID
```

### 2. Enable Required APIs

Run the provided script:

```bash
./enable-apis.sh
```

Or manually:

```bash
# Enable required APIs
gcloud services enable container.googleapis.com \
  artifactregistry.googleapis.com \
  sqladmin.googleapis.com \
  secretmanager.googleapis.com \
  monitoring.googleapis.com \
  logging.googleapis.com \
  cloudresourcemanager.googleapis.com \
  iam.googleapis.com \
  compute.googleapis.com
```

### 3. Create GKE Autopilot Cluster

Run the provided script:

```bash
./create-gke-autopilot.sh
```

Or manually:

```bash
# Create Autopilot cluster (minimal cost, fully managed)
gcloud container clusters create-auto helm-learning-cluster \
  --region=$REGION \
  --project=$PROJECT_ID

# Get credentials
gcloud container clusters get-credentials helm-learning-cluster \
  --region=$REGION \
  --project=$PROJECT_ID

# Verify cluster
kubectl get nodes
kubectl cluster-info
```

**Autopilot Benefits:**
- No node management
- Automatic scaling
- Built-in security
- Pay only for pods
- Minimal operational overhead

### 4. Set Up Artifact Registry

Run the provided script:

```bash
./artifact-registry-helm.sh
```

Or manually:

```bash
# Create Artifact Registry repository for Helm charts
gcloud artifacts repositories create helm-charts \
  --repository-format=docker \
  --location=$REGION \
  --description="Helm charts repository"

# Configure Docker/Helm authentication
gcloud auth configure-docker ${REGION}-docker.pkg.dev

# Configure Helm to use OCI registry
export HELM_REGISTRY="${REGION}-docker.pkg.dev/${PROJECT_ID}/helm-charts"

# Test Helm OCI login
echo "Helm registry configured at: $HELM_REGISTRY"
```

### 5. Configure Workload Identity

Run the provided script:

```bash
./workload-identity.sh
```

This sets up Workload Identity for secure access to GCP services from pods.

**What is Workload Identity?**
- Allows Kubernetes service accounts to act as GCP service accounts
- No need for service account keys
- Automatic credential rotation
- Fine-grained IAM permissions

**Example Setup:**

```bash
# Create GCP service account
gcloud iam service-accounts create my-app-sa \
  --display-name="My App Service Account"

# Grant permissions (example: Cloud SQL client)
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:my-app-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/cloudsql.client"

# Create Kubernetes service account
kubectl create serviceaccount my-app-ksa -n default

# Bind KSA to GSA
gcloud iam service-accounts add-iam-policy-binding \
  my-app-sa@${PROJECT_ID}.iam.gserviceaccount.com \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:${PROJECT_ID}.svc.id.goog[default/my-app-ksa]"

# Annotate KSA
kubectl annotate serviceaccount my-app-ksa \
  iam.gke.io/gcp-service-account=my-app-sa@${PROJECT_ID}.iam.gserviceaccount.com
```

## Environment Variables

Add these to your `~/.bashrc` or `~/.zshrc`:

```bash
export PROJECT_ID="my-helm-gcp-project"
export REGION="us-central1"
export ZONE="us-central1-a"
export HELM_REGISTRY="${REGION}-docker.pkg.dev/${PROJECT_ID}/helm-charts"
export CLUSTER_NAME="helm-learning-cluster"
```

## Verification

```bash
# Check cluster status
kubectl get nodes
kubectl get namespaces

# Check Helm
helm version
helm repo list

# Check gcloud config
gcloud config list
gcloud projects describe $PROJECT_ID
```

## Cleanup

**IMPORTANT**: Run this when you're done to avoid charges:

```bash
./cleanup.sh
```

This will:
- Delete the GKE cluster
- Delete Artifact Registry repositories
- Delete any Load Balancers
- Delete Cloud SQL instances
- Delete persistent disks

**Manual Cleanup:**

```bash
# Delete cluster
gcloud container clusters delete helm-learning-cluster \
  --region=$REGION \
  --quiet

# Delete Artifact Registry
gcloud artifacts repositories delete helm-charts \
  --location=$REGION \
  --quiet

# List and delete any Load Balancers
gcloud compute forwarding-rules list
gcloud compute forwarding-rules delete FORWARDING_RULE_NAME --region=$REGION

# List and delete Cloud SQL instances
gcloud sql instances list
gcloud sql instances delete INSTANCE_NAME --quiet
```

## Troubleshooting

### Issue: Billing not enabled

```bash
# Check billing status
gcloud billing projects describe $PROJECT_ID

# Enable billing
gcloud billing projects link $PROJECT_ID --billing-account=BILLING_ACCOUNT_ID
```

### Issue: API not enabled

```bash
# Check enabled APIs
gcloud services list --enabled

# Enable specific API
gcloud services enable SERVICE_NAME.googleapis.com
```

### Issue: Insufficient permissions

```bash
# Check your permissions
gcloud projects get-iam-policy $PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:user:YOUR_EMAIL"

# You need at least:
# - roles/owner OR
# - roles/editor + roles/container.admin + roles/iam.serviceAccountAdmin
```

### Issue: Cluster creation fails

```bash
# Check quotas
gcloud compute project-info describe --project=$PROJECT_ID

# Try different region
export REGION="us-west1"
```

## Next Steps

Once your environment is set up:
1. Explore [01-helm-basics](../01-helm-basics/README.md) to learn Helm fundamentals
2. Try deploying your first chart
3. Explore database examples in [06-datastores](../06-datastores/README.md)

## Resources

- [GKE Autopilot Documentation](https://cloud.google.com/kubernetes-engine/docs/concepts/autopilot-overview)
- [Workload Identity Documentation](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity)
- [Artifact Registry Documentation](https://cloud.google.com/artifact-registry/docs)
- [GCP Free Tier](https://cloud.google.com/free)
