# Cleanup Script - Remove all GCP resources
# Run this script from PowerShell on Windows

# Check if required environment variables are set
if (-not $env:PROJECT_ID) {
    Write-Host "ERROR: PROJECT_ID environment variable is not set!" -ForegroundColor Red
    Write-Host "Please set it with: `$env:PROJECT_ID = 'your-project-id'" -ForegroundColor Yellow
    exit 1
}

if (-not $env:REGION) {
    Write-Host "WARNING: REGION not set, using default: us-central1" -ForegroundColor Yellow
    $env:REGION = "us-central1"
}

$CLUSTER_NAME = "helm-demo-cluster"
$INSTANCE_NAME = "helm-demo-postgres"
$REPO_NAME = "helm-charts"
$GSA_NAME = "helm-demo-gsa"

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

$confirmation = Read-Host "Type 'DELETE' to confirm deletion"

if ($confirmation -ne "DELETE") {
    Write-Host ""
    Write-Host "Cleanup cancelled. No resources were deleted." -ForegroundColor Green
    exit 0
}

Write-Host ""
Write-Host "Starting cleanup process..." -ForegroundColor Yellow
Write-Host ""

# Uninstall all Helm releases
Write-Host "Step 1: Uninstalling Helm releases..." -ForegroundColor Cyan

$releases = helm list --short 2>&1

if ($LASTEXITCODE -eq 0 -and $releases) {
    foreach ($release in $releases) {
        Write-Host "  Uninstalling $release..." -ForegroundColor Yellow
        helm uninstall $release
        if ($LASTEXITCODE -eq 0) {
            Write-Host "    ✓ Uninstalled" -ForegroundColor Green
        } else {
            Write-Host "    ✗ Failed" -ForegroundColor Red
        }
    }
} else {
    Write-Host "  No Helm releases found or cluster not accessible" -ForegroundColor Yellow
}

# Delete Cloud SQL instance
Write-Host ""
Write-Host "Step 2: Deleting Cloud SQL instance..." -ForegroundColor Cyan

$result = gcloud sql instances delete $INSTANCE_NAME `
    --project=$env:PROJECT_ID `
    --quiet 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ Cloud SQL instance deleted" -ForegroundColor Green
} else {
    if ($result -like "*not found*") {
        Write-Host "  Instance not found, skipping..." -ForegroundColor Yellow
    } else {
        Write-Host "  ✗ Failed to delete instance" -ForegroundColor Red
        Write-Host "  Error: $result" -ForegroundColor Red
    }
}

# Delete GKE cluster
Write-Host ""
Write-Host "Step 3: Deleting GKE cluster..." -ForegroundColor Cyan
Write-Host "  This will take 5-10 minutes..." -ForegroundColor Yellow

$result = gcloud container clusters delete $CLUSTER_NAME `
    --region=$env:REGION `
    --project=$env:PROJECT_ID `
    --quiet 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ GKE cluster deleted" -ForegroundColor Green
} else {
    if ($result -like "*not found*") {
        Write-Host "  Cluster not found, skipping..." -ForegroundColor Yellow
    } else {
        Write-Host "  ✗ Failed to delete cluster" -ForegroundColor Red
        Write-Host "  Error: $result" -ForegroundColor Red
    }
}

# Delete Artifact Registry repository
Write-Host ""
Write-Host "Step 4: Deleting Artifact Registry..." -ForegroundColor Cyan

$result = gcloud artifacts repositories delete $REPO_NAME `
    --location=$env:REGION `
    --project=$env:PROJECT_ID `
    --quiet 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ Artifact Registry deleted" -ForegroundColor Green
} else {
    if ($result -like "*not found*") {
        Write-Host "  Repository not found, skipping..." -ForegroundColor Yellow
    } else {
        Write-Host "  ✗ Failed to delete repository" -ForegroundColor Red
        Write-Host "  Error: $result" -ForegroundColor Red
    }
}

# Delete service account
Write-Host ""
Write-Host "Step 5: Deleting service account..." -ForegroundColor Cyan

$result = gcloud iam service-accounts delete "$GSA_NAME@$env:PROJECT_ID.iam.gserviceaccount.com" `
    --project=$env:PROJECT_ID `
    --quiet 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ Service account deleted" -ForegroundColor Green
} else {
    if ($result -like "*not found*") {
        Write-Host "  Service account not found, skipping..." -ForegroundColor Yellow
    } else {
        Write-Host "  ✗ Failed to delete service account" -ForegroundColor Red
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
