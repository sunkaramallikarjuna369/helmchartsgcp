# Set up Artifact Registry for Helm Charts and Container Images
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

$REPO_NAME = "helm-charts"
$REGION = $env:REGION

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Artifact Registry Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Project ID: $env:PROJECT_ID" -ForegroundColor Yellow
Write-Host "Repository Name: $REPO_NAME" -ForegroundColor Yellow
Write-Host "Region: $REGION" -ForegroundColor Yellow
Write-Host ""

Write-Host "Creating Artifact Registry repository..." -ForegroundColor Green

$result = gcloud artifacts repositories create $REPO_NAME `
    --repository-format=docker `
    --location=$REGION `
    --description="Helm charts and container images" `
    --project=$env:PROJECT_ID 2>&1

if ($LASTEXITCODE -ne 0) {
    if ($result -like "*already exists*") {
        Write-Host "Repository already exists, continuing..." -ForegroundColor Yellow
    } else {
        Write-Host ""
        Write-Host "ERROR: Failed to create repository!" -ForegroundColor Red
        Write-Host $result -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "✓ Repository created successfully!" -ForegroundColor Green
}

# Configure Docker authentication
Write-Host ""
Write-Host "Configuring Docker authentication..." -ForegroundColor Yellow

gcloud auth configure-docker "$REGION-docker.pkg.dev" --quiet

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to configure Docker authentication!" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Docker authentication configured" -ForegroundColor Green

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Artifact Registry Setup Complete! ✓" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Repository URL:" -ForegroundColor Yellow
Write-Host "  $REGION-docker.pkg.dev/$env:PROJECT_ID/$REPO_NAME" -ForegroundColor Cyan
Write-Host ""
Write-Host "You can now push Docker images and Helm charts to this repository." -ForegroundColor White
Write-Host ""
Write-Host "Example commands:" -ForegroundColor Yellow
Write-Host "  # Tag an image" -ForegroundColor White
Write-Host "  docker tag myapp:latest $REGION-docker.pkg.dev/$env:PROJECT_ID/$REPO_NAME/myapp:latest" -ForegroundColor Gray
Write-Host ""
Write-Host "  # Push the image" -ForegroundColor White
Write-Host "  docker push $REGION-docker.pkg.dev/$env:PROJECT_ID/$REPO_NAME/myapp:latest" -ForegroundColor Gray
Write-Host ""
