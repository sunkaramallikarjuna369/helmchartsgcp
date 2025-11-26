# Cleanup Script - Remove all GCP resources
# Run this script from PowerShell on Windows
#
# WARNING: This script permanently deletes all resources created by the setup scripts.
# Use this when you're done with the demo or want to start fresh.
# This helps avoid ongoing charges for GCP resources.

# ============================================================================
# STEP 1: Validate Environment Variables
# ============================================================================
# Check if PROJECT_ID environment variable is set
if (-not $env:PROJECT_ID) {
    Write-Host "ERROR: PROJECT_ID environment variable is not set!" -ForegroundColor Red
    Write-Host "Please set it with: `$env:PROJECT_ID = 'your-project-id'" -ForegroundColor Yellow
    exit 1
}

# Check if REGION is set, use default if not
if (-not $env:REGION) {
    Write-Host "WARNING: REGION not set, using default: us-central1" -ForegroundColor Yellow
    $env:REGION = "us-central1"
}

# Define resource names (must match the names used in setup scripts)
$CLUSTER_NAME = "helm-demo-cluster"      # GKE cluster name
$INSTANCE_NAME = "helm-demo-postgres"    # Cloud SQL instance name
$REPO_NAME = "helm-charts"               # Artifact Registry repository name
$GSA_NAME = "helm-demo-gsa"              # GCP service account name

# ============================================================================
# STEP 2: Display Warning and Get Confirmation
# ============================================================================
Write-Host "========================================" -ForegroundColor Red
Write-Host "CLEANUP WARNING" -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Red
Write-Host ""
Write-Host "This will DELETE the following resources:" -ForegroundColor Yellow
Write-Host "  - GKE Cluster: $CLUSTER_NAME" -ForegroundColor White
Write-Host "  - Cloud SQL Instance: $INSTANCE_NAME" -ForegroundColor White
Write-Host "  - Artifact Registry: $REPO_NAME" -ForegroundColor White
Write-Host "  - Service Account: $GSA_NAME" -ForegroundColor White
Write-Host "  - All Helm releases in the cluster" -ForegroundColor White
Write-Host ""
Write-Host "This action CANNOT be undone!" -ForegroundColor Red
Write-Host ""

# Require explicit confirmation to prevent accidental deletion
$confirmation = Read-Host "Type 'DELETE' to confirm deletion"

if ($confirmation -ne "DELETE") {
    Write-Host ""
    Write-Host "Cleanup cancelled. No resources were deleted." -ForegroundColor Green
    exit 0
}

Write-Host ""
Write-Host "Starting cleanup process..." -ForegroundColor Yellow
Write-Host ""

# ============================================================================
# STEP 3: Uninstall All Helm Releases
# ============================================================================
Write-Host "Step 1: Uninstalling Helm releases..." -ForegroundColor Cyan

# Command: helm list --short
# Purpose: Lists all Helm releases in the current cluster (short format = names only)
# Result: Returns a list of release names, one per line
$releases = helm list --short 2>&1

# Check if we got any releases and the command succeeded
if ($LASTEXITCODE -eq 0 -and $releases) {
    foreach ($release in $releases) {
        Write-Host "  Uninstalling $release..." -ForegroundColor Yellow
        
        # Command: helm uninstall
        # Purpose: Removes a Helm release and all its Kubernetes resources
        # Parameters: $release - Name of the Helm release to uninstall
        # Result: Deletes all pods, services, deployments, etc. created by this release
        helm uninstall $release
        if ($LASTEXITCODE -eq 0) {
            Write-Host "    [OK] Uninstalled" -ForegroundColor Green
        } else {
            Write-Host "    [FAILED] Failed" -ForegroundColor Red
        }
    }
} else {
    Write-Host "  No Helm releases found or cluster not accessible" -ForegroundColor Yellow
}

# ============================================================================
# STEP 4: Delete Cloud SQL Instance
# ============================================================================
Write-Host ""
Write-Host "Step 2: Deleting Cloud SQL instance..." -ForegroundColor Cyan

# Command: gcloud sql instances delete
# Purpose: Permanently deletes a Cloud SQL instance and all its data
# Parameters:
#   $INSTANCE_NAME - Name of the Cloud SQL instance to delete
#   --project - GCP project ID
#   --quiet - Skip confirmation prompt (we already confirmed above)
# WARNING: This deletes all databases and data in the instance
$result = gcloud sql instances delete $INSTANCE_NAME `
    --project=$env:PROJECT_ID `
    --quiet 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "  [OK] Cloud SQL instance deleted" -ForegroundColor Green
} else {
    if ($result -like "*not found*") {
        Write-Host "  Instance not found, skipping..." -ForegroundColor Yellow
    } else {
        Write-Host "  [FAILED] Failed to delete instance" -ForegroundColor Red
        Write-Host "  Error: $result" -ForegroundColor Red
    }
}

# ============================================================================
# STEP 5: Delete GKE Cluster
# ============================================================================
Write-Host ""
Write-Host "Step 3: Deleting GKE cluster..." -ForegroundColor Cyan
Write-Host "  This will take 5-10 minutes..." -ForegroundColor Yellow

# Command: gcloud container clusters delete
# Purpose: Permanently deletes a GKE cluster and all its nodes
# Parameters:
#   $CLUSTER_NAME - Name of the cluster to delete
#   --region - Region where the cluster is located
#   --project - GCP project ID
#   --quiet - Skip confirmation prompt
# Result: Deletes all nodes, pods, services, and cluster infrastructure
# Note: This is the most time-consuming deletion (5-10 minutes)
$result = gcloud container clusters delete $CLUSTER_NAME `
    --region=$env:REGION `
    --project=$env:PROJECT_ID `
    --quiet 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "  [OK] GKE cluster deleted" -ForegroundColor Green
} else {
    if ($result -like "*not found*") {
        Write-Host "  Cluster not found, skipping..." -ForegroundColor Yellow
    } else {
        Write-Host "  [FAILED] Failed to delete cluster" -ForegroundColor Red
        Write-Host "  Error: $result" -ForegroundColor Red
    }
}

# ============================================================================
# STEP 6: Delete Artifact Registry Repository
# ============================================================================
Write-Host ""
Write-Host "Step 4: Deleting Artifact Registry..." -ForegroundColor Cyan

# Command: gcloud artifacts repositories delete
# Purpose: Permanently deletes an Artifact Registry repository and all images
# Parameters:
#   $REPO_NAME - Name of the repository to delete
#   --location - Region where the repository is located
#   --project - GCP project ID
#   --quiet - Skip confirmation prompt
# WARNING: This deletes all Docker images and Helm charts in the repository
$result = gcloud artifacts repositories delete $REPO_NAME `
    --location=$env:REGION `
    --project=$env:PROJECT_ID `
    --quiet 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "  [OK] Artifact Registry deleted" -ForegroundColor Green
} else {
    if ($result -like "*not found*") {
        Write-Host "  Repository not found, skipping..." -ForegroundColor Yellow
    } else {
        Write-Host "  [FAILED] Failed to delete repository" -ForegroundColor Red
        Write-Host "  Error: $result" -ForegroundColor Red
    }
}

# ============================================================================
# STEP 7: Delete Service Account
# ============================================================================
Write-Host ""
Write-Host "Step 5: Deleting service account..." -ForegroundColor Cyan

# Command: gcloud iam service-accounts delete
# Purpose: Permanently deletes a GCP service account
# Parameters:
#   "$GSA_NAME@..." - Full email address of the service account
#   --project - GCP project ID
#   --quiet - Skip confirmation prompt
# Result: Removes the service account and all its IAM bindings
# Note: Any pods using this service account will lose access to GCP services
$result = gcloud iam service-accounts delete "$GSA_NAME@$env:PROJECT_ID.iam.gserviceaccount.com" `
    --project=$env:PROJECT_ID `
    --quiet 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "  [OK] Service account deleted" -ForegroundColor Green
} else {
    if ($result -like "*not found*") {
        Write-Host "  Service account not found, skipping..." -ForegroundColor Yellow
    } else {
        Write-Host "  [FAILED] Failed to delete service account" -ForegroundColor Red
        Write-Host "  Error: $result" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Cleanup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "All resources have been deleted." -ForegroundColor White
Write-Host ""
Write-Host "Note: Some resources may take a few minutes to fully delete." -ForegroundColor Yellow
Write-Host "You can verify in the GCP Console: https://console.cloud.google.com" -ForegroundColor Yellow
Write-Host ""
