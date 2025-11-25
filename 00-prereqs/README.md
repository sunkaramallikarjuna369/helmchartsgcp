# Prerequisites - GCP Setup

## What

One-time setup of your Google Cloud Platform environment to run Helm charts on Google Kubernetes Engine (GKE). This includes creating a GCP project, enabling APIs, creating a GKE Autopilot cluster, setting up Artifact Registry for Helm charts, and configuring Workload Identity for secure pod-to-GCP authentication.

**Resources Created:**
- GCP Project (if new)
- GKE Autopilot cluster
- Artifact Registry repository (Docker format for Helm OCI)
- GCP Service Account with Workload Identity bindings
- Kubernetes Service Account with annotations

## Why

**Why This Setup Matters:**
- **Foundation**: All other sections depend on this setup
- **Security**: Workload Identity eliminates service account keys
- **Cost Efficiency**: Autopilot mode reduces operational overhead and costs
- **Best Practices**: Uses GCP-recommended patterns (Autopilot, Workload Identity, Artifact Registry)
- **Automation**: Scripts make setup repeatable and consistent

**Why GKE Autopilot:**
- No node management or patching
- Automatic scaling based on pod requirements
- Built-in security and compliance
- Pay only for pods, not nodes
- Reduced operational complexity

**Why Workload Identity:**
- No service account keys to manage or rotate
- Automatic credential rotation
- Fine-grained IAM permissions per workload
- Audit trail in Cloud Logging
- Industry best practice for GKE

**Trade-offs:**
- **Autopilot Restrictions**: No hostPath, privileged pods, or DaemonSets
- **Regional Cluster**: Higher availability but slightly higher cost than zonal
- **Learning Curve**: Workload Identity requires understanding IAM bindings
- **GCP Lock-in**: These patterns are GCP-specific

## When

**Complete This Setup When:**
- Starting with Helm on GCP for the first time
- Setting up a new GCP project for Kubernetes learning
- Need a clean environment for testing Helm charts
- Want to follow GCP best practices from the start

**Prerequisites:**
- GCP account (new accounts get $300 free trial credits for 90 days)
- Basic command-line skills (bash, terminal)
- gcloud CLI installed (or use Cloud Shell)
- Credit card for GCP account verification (won't be charged with free tier)

**When to Re-run:**
- Setting up a new GCP project
- Creating additional clusters
- After running cleanup scripts
- When switching between projects

**Sequencing:**
1. Install tools (gcloud, kubectl, helm) - 5 minutes
2. Create GCP project and enable billing - 5 minutes
3. Enable required APIs - 2 minutes
4. Create GKE Autopilot cluster - 10-15 minutes
5. Set up Artifact Registry - 2 minutes
6. Configure Workload Identity - 5 minutes
**Total Time**: ~30-40 minutes

## Where

**GCP Services:**
- **Google Kubernetes Engine (GKE)**: Managed Kubernetes with Autopilot mode
- **Artifact Registry**: Store Helm charts (OCI format) and container images
- **Cloud Resource Manager API**: Project management
- **IAM API**: Service account and Workload Identity configuration
- **Compute Engine API**: Underlying infrastructure for GKE
- **Cloud Monitoring & Logging**: Observability (enabled by default)
- **Secret Manager**: Secrets management (enabled for later use)
- **Cloud SQL Admin API**: Database management (enabled for later use)

**IAM Roles Required:**
- `roles/owner` OR combination of:
  - `roles/editor`: General project access
  - `roles/container.admin`: Create and manage GKE clusters
  - `roles/iam.serviceAccountAdmin`: Create service accounts and Workload Identity bindings
  - `roles/artifactregistry.admin`: Create and manage Artifact Registry repositories

**Kubernetes Resources:**
- **Namespace**: default (or custom namespaces created later)
- **ServiceAccount**: Kubernetes service accounts with Workload Identity annotations
- **Nodes**: Managed automatically by Autopilot (no manual node management)

**Repository Locations:**
- `00-prereqs/enable-apis.sh`: Script to enable all required GCP APIs
- `00-prereqs/create-gke-autopilot.sh`: Script to create GKE Autopilot cluster
- `00-prereqs/artifact-registry-helm.sh`: Script to set up Artifact Registry
- `00-prereqs/workload-identity.sh`: Script to configure Workload Identity
- `00-prereqs/cleanup.sh`: Script to delete all resources and avoid charges

**Environment Variables to Set:**
```bash
export PROJECT_ID="your-gcp-project-id"
export REGION="us-central1"
export ZONE="us-central1-a"
export CLUSTER_NAME="helm-learning-cluster"
export HELM_REGISTRY="${REGION}-docker.pkg.dev/${PROJECT_ID}/helm-charts"
```

**Where Costs Accrue:**
- **GKE Autopilot**: ~$0.10/hour per vCPU, $0.011/hour per GB RAM
  - Minimal cost with small workloads (100m CPU, 128Mi RAM)
  - Example: 1 pod with 250m CPU, 512Mi RAM = ~$0.03/hour = ~$22/month
- **Persistent Disks**: $0.04/GB/month (standard) to $0.17/GB/month (SSD)
- **Load Balancers**: $18-25/month per Ingress (created in later sections)
- **Artifact Registry**: $0.10/GB/month storage (minimal for Helm charts)
- **Data Transfer**: $0.01-0.12/GB egress (minimal for learning)

**Free Tier:**
- $300 trial credits for 90 days (new accounts)
- GKE Autopilot: $74.40/month free cluster management fee
- Always Free tier for many services (Cloud Logging, Monitoring, etc.)

## How

### Quickstart (30-40 minutes)

```bash
# 1. Install required tools (if not already installed)
# gcloud CLI
curl https://sdk.cloud.google.com | bash
exec -l $SHELL

# kubectl
gcloud components install kubectl

# Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify installations
gcloud version
kubectl version --client
helm version

# 2. Set environment variables
export PROJECT_ID="my-helm-gcp-project"  # Change this
export REGION="us-central1"
export ZONE="us-central1-a"
export CLUSTER_NAME="helm-learning-cluster"

# 3. Create GCP project (if new)
gcloud projects create $PROJECT_ID --name="Helm GCP Learning"
gcloud config set project $PROJECT_ID

# 4. Link billing account (required)
gcloud billing accounts list
gcloud billing projects link $PROJECT_ID --billing-account=BILLING_ACCOUNT_ID

# 5. Enable required APIs (2 minutes)
cd 00-prereqs
./enable-apis.sh

# 6. Create GKE Autopilot cluster (10-15 minutes)
./create-gke-autopilot.sh

# 7. Set up Artifact Registry (2 minutes)
./artifact-registry-helm.sh

# 8. Configure Workload Identity (5 minutes)
./workload-identity.sh

# 9. Add environment variables to shell profile
cat >> ~/.bashrc <<EOF
export PROJECT_ID="$PROJECT_ID"
export REGION="$REGION"
export ZONE="$ZONE"
export CLUSTER_NAME="$CLUSTER_NAME"
export HELM_REGISTRY="${REGION}-docker.pkg.dev/${PROJECT_ID}/helm-charts"
EOF

source ~/.bashrc
```

### Verify Setup

```bash
# Check cluster is running
kubectl get nodes
# Should show nodes in Ready state

# Check cluster info
kubectl cluster-info
gcloud container clusters describe $CLUSTER_NAME --region=$REGION

# Check Helm
helm version
# Should show version 3.x

# Check Workload Identity
kubectl get serviceaccount -n default
kubectl describe serviceaccount default -n default
# Should show iam.gke.io/gcp-service-account annotation

# Check Artifact Registry
gcloud artifacts repositories list
# Should show helm-charts repository

# Check enabled APIs
gcloud services list --enabled | grep -E 'container|artifact|sql|secret'
```

### Cleanup (IMPORTANT)

```bash
# Run cleanup script to delete all resources
cd 00-prereqs
./cleanup.sh

# Verify all resources deleted
gcloud container clusters list
gcloud artifacts repositories list
gcloud compute forwarding-rules list
gcloud sql instances list
gcloud compute disks list --filter="name~gke-"

# All commands should return empty or "Listed 0 items"
```

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
