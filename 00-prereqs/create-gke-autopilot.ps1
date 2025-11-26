# Create GKE Autopilot Cluster
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
$REGION = $env:REGION

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

$confirmation = Read-Host "Do you want to proceed? (yes/no)"
if ($confirmation -ne "yes") {
    Write-Host "Cluster creation cancelled." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "Creating GKE Autopilot cluster..." -ForegroundColor Green

$result = gcloud container clusters create-auto $CLUSTER_NAME `
    --region=$REGION `
    --project=$env:PROJECT_ID `
    --release-channel=regular `
    --enable-autoscaling `
    --enable-autorepair `
    --enable-autoupgrade `
    --workload-pool="$env:PROJECT_ID.svc.id.goog" 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "ERROR: Failed to create cluster!" -ForegroundColor Red
    Write-Host $result -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "[SUCCESS] Cluster created successfully!" -ForegroundColor Green

# Get cluster credentials
Write-Host ""
Write-Host "Getting cluster credentials..." -ForegroundColor Yellow

gcloud container clusters get-credentials $CLUSTER_NAME `
    --region=$REGION `
    --project=$env:PROJECT_ID

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to get cluster credentials!" -ForegroundColor Red
    exit 1
}

Write-Host "[SUCCESS] Credentials configured" -ForegroundColor Green

# Verify connection
Write-Host ""
Write-Host "Verifying cluster connection..." -ForegroundColor Yellow
Write-Host ""

kubectl cluster-info

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "ERROR: Failed to connect to cluster!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Checking nodes..." -ForegroundColor Yellow
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
