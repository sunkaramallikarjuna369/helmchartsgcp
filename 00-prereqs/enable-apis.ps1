# Enable required GCP APIs for Helm Charts deployment
# Run this script from PowerShell on Windows

# Check if PROJECT_ID is set
if (-not $env:PROJECT_ID) {
    Write-Host "ERROR: PROJECT_ID environment variable is not set!" -ForegroundColor Red
    Write-Host "Please set it with: `$env:PROJECT_ID = 'your-project-id'" -ForegroundColor Yellow
    exit 1
}

$apis = @(
    "container.googleapis.com",           # GKE
    "compute.googleapis.com",             # Compute Engine
    "artifactregistry.googleapis.com",    # Artifact Registry
    "cloudresourcemanager.googleapis.com", # Resource Manager
    "iam.googleapis.com",                 # IAM
    "sqladmin.googleapis.com",            # Cloud SQL
    "firestore.googleapis.com",           # Firestore
    "redis.googleapis.com",               # Memorystore Redis
    "secretmanager.googleapis.com",       # Secret Manager
    "monitoring.googleapis.com",          # Cloud Monitoring
    "logging.googleapis.com",             # Cloud Logging
    "cloudtrace.googleapis.com",          # Cloud Trace
    "iamcredentials.googleapis.com",      # Workload Identity
    "sts.googleapis.com"                  # Security Token Service
)

Write-Host "Enabling GCP APIs for project: $env:PROJECT_ID" -ForegroundColor Green
Write-Host "This may take a few minutes..." -ForegroundColor Yellow
Write-Host ""

$successCount = 0
$failCount = 0

foreach ($api in $apis) {
    Write-Host "Enabling $api..." -ForegroundColor Cyan
    
    $result = gcloud services enable $api --project=$env:PROJECT_ID 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ Enabled successfully" -ForegroundColor Green
        $successCount++
    } else {
        Write-Host "  ✗ Failed to enable" -ForegroundColor Red
        Write-Host "  Error: $result" -ForegroundColor Red
        $failCount++
    }
}

Write-Host ""
Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "  Successfully enabled: $successCount APIs" -ForegroundColor Green
Write-Host "  Failed: $failCount APIs" -ForegroundColor $(if ($failCount -gt 0) { "Red" } else { "Green" })

if ($failCount -eq 0) {
    Write-Host ""
    Write-Host "All APIs enabled successfully! ✓" -ForegroundColor Green
    Write-Host "You can now proceed to create your GKE cluster." -ForegroundColor Yellow
} else {
    Write-Host ""
    Write-Host "Some APIs failed to enable. Please check the errors above." -ForegroundColor Red
    exit 1
}
