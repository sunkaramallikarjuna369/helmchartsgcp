# Create GKE Autopilot Cluster
# Run this script from PowerShell on Windows
#
# This script creates a Google Kubernetes Engine (GKE) Autopilot cluster.
# Autopilot is a managed Kubernetes service where Google handles node management,
# scaling, and security patches automatically.

# ============================================================================
# STEP 1: Validate Environment Variables
# ============================================================================
# Check if PROJECT_ID environment variable is set
# This should contain your GCP project ID
if (-not $env:PROJECT_ID) {
    Write-Host "ERROR: PROJECT_ID environment variable is not set!" -ForegroundColor Red
    Write-Host "Please set it with: `$env:PROJECT_ID = 'your-project-id'" -ForegroundColor Yellow
    exit 1
}

# Check if REGION is set, use default if not
# Region determines where your cluster will be physically located
if (-not $env:REGION) {
    Write-Host "WARNING: REGION not set, using default: us-central1" -ForegroundColor Yellow
    $env:REGION = "us-central1"
}

# Define cluster configuration
$CLUSTER_NAME = "helm-demo-cluster"  # Name of the Kubernetes cluster
$REGION = $env:REGION                # GCP region for the cluster

# ============================================================================
# STEP 2: Display Configuration and Get Confirmation
# ============================================================================
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "GKE Autopilot Cluster Creation" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Project ID: $env:PROJECT_ID" -ForegroundColor Yellow
Write-Host "Cluster Name: $CLUSTER_NAME" -ForegroundColor Yellow
Write-Host "Region: $REGION" -ForegroundColor Yellow
Write-Host ""

Write-Host "This will create a GKE Autopilot cluster with:" -ForegroundColor Green
Write-Host "  - Automatic node provisioning" -ForegroundColor White
Write-Host "  - Automatic scaling" -ForegroundColor White
Write-Host "  - Workload Identity enabled" -ForegroundColor White
Write-Host "  - Regional high availability" -ForegroundColor White
Write-Host ""
Write-Host "Estimated time: 5-10 minutes" -ForegroundColor Yellow
Write-Host "Estimated cost: ~`$73/month (covered by free tier credit)" -ForegroundColor Yellow
Write-Host ""

# Ask for user confirmation before proceeding
$confirmation = Read-Host "Do you want to proceed? (yes/no)"
if ($confirmation -ne "yes") {
    Write-Host "Cluster creation cancelled." -ForegroundColor Yellow
    exit 0
}

# ============================================================================
# STEP 3: Create GKE Autopilot Cluster
# ============================================================================
Write-Host ""
Write-Host "Creating GKE Autopilot cluster..." -ForegroundColor Green

# Command: gcloud container clusters create-auto
# Purpose: Creates a new GKE Autopilot cluster (fully managed Kubernetes)
# Parameters:
#   $CLUSTER_NAME - Name of the cluster to create
#   --region - GCP region where cluster will be created (regional = high availability)
#   --project - GCP project ID
#   --release-channel=regular - Use regular release channel for stable Kubernetes versions
#   --enable-autoscaling - Automatically scale nodes based on workload demand
#   --enable-autorepair - Automatically repair unhealthy nodes
#   --enable-autoupgrade - Automatically upgrade Kubernetes version
#   --workload-pool - Enable Workload Identity for secure GCP service access
# Note: Backtick (`) is PowerShell's line continuation character
$result = gcloud container clusters create-auto $CLUSTER_NAME `
    --region=$REGION `
    --project=$env:PROJECT_ID `
    --release-channel=regular `
    --enable-autoscaling `
    --enable-autorepair `
    --enable-autoupgrade `
    --workload-pool="$env:PROJECT_ID.svc.id.goog" 2>&1

# Check if cluster creation succeeded
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "ERROR: Failed to create cluster!" -ForegroundColor Red
    Write-Host $result -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "[SUCCESS] Cluster created successfully!" -ForegroundColor Green

# ============================================================================
# STEP 4: Configure kubectl to Access the Cluster
# ============================================================================
Write-Host ""
Write-Host "Getting cluster credentials..." -ForegroundColor Yellow

# Command: gcloud container clusters get-credentials
# Purpose: Downloads cluster credentials and configures kubectl to use them
# Parameters:
#   $CLUSTER_NAME - Name of the cluster to get credentials for
#   --region - Region where the cluster is located
#   --project - GCP project ID
# Result: Updates ~/.kube/config file with cluster authentication details
gcloud container clusters get-credentials $CLUSTER_NAME `
    --region=$REGION `
    --project=$env:PROJECT_ID

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to get cluster credentials!" -ForegroundColor Red
    exit 1
}

Write-Host "[SUCCESS] Credentials configured" -ForegroundColor Green

# ============================================================================
# STEP 5: Verify Cluster Connection
# ============================================================================
Write-Host ""
Write-Host "Verifying cluster connection..." -ForegroundColor Yellow
Write-Host ""

# Command: kubectl cluster-info
# Purpose: Displays information about the Kubernetes cluster
# Shows: Kubernetes master URL, CoreDNS URL, and other cluster services
kubectl cluster-info

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "ERROR: Failed to connect to cluster!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Checking nodes..." -ForegroundColor Yellow

# Command: kubectl get nodes
# Purpose: Lists all nodes (virtual machines) in the cluster
# Shows: Node name, status, roles, age, and Kubernetes version
# Note: In Autopilot, nodes are automatically provisioned as needed
kubectl get nodes

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "GKE Cluster Setup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Run .\setup-artifact-registry.ps1" -ForegroundColor White
Write-Host "  2. Run .\setup-workload-identity.ps1" -ForegroundColor White
Write-Host "  3. Start deploying Helm charts!" -ForegroundColor White
Write-Host ""
