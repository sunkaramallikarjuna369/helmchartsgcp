# Enable required GCP APIs for Helm Charts deployment
# Run this script from PowerShell on Windows
#
# This script enables all the Google Cloud APIs needed for deploying Helm charts on GKE.
# Each API provides specific functionality required for the deployment.

# ============================================================================
# STEP 1: Validate Environment Variables
# ============================================================================
# Check if PROJECT_ID environment variable is set
# This variable should contain your GCP project ID (e.g., "my-helm-project")
if (-not $env:PROJECT_ID) {
    Write-Host "ERROR: PROJECT_ID environment variable is not set!" -ForegroundColor Red
    Write-Host "Please set it with: `$env:PROJECT_ID = 'your-project-id'" -ForegroundColor Yellow
    exit 1
}

# ============================================================================
# STEP 2: Define Required APIs
# ============================================================================
# Array of all GCP APIs that need to be enabled
# Each API provides specific services:
$apis = @(
    "container.googleapis.com",           # GKE - Google Kubernetes Engine for running containers
    "compute.googleapis.com",             # Compute Engine - Virtual machines and networking
    "artifactregistry.googleapis.com",    # Artifact Registry - Store Docker images and Helm charts
    "cloudresourcemanager.googleapis.com", # Resource Manager - Manage GCP projects and resources
    "iam.googleapis.com",                 # IAM - Identity and Access Management for permissions
    "sqladmin.googleapis.com",            # Cloud SQL - Managed PostgreSQL/MySQL databases
    "firestore.googleapis.com",           # Firestore - NoSQL document database
    "redis.googleapis.com",               # Memorystore Redis - In-memory cache
    "secretmanager.googleapis.com",       # Secret Manager - Store API keys and passwords securely
    "monitoring.googleapis.com",          # Cloud Monitoring - Collect metrics and create dashboards
    "logging.googleapis.com",             # Cloud Logging - Centralized log management
    "cloudtrace.googleapis.com",          # Cloud Trace - Distributed tracing for debugging
    "iamcredentials.googleapis.com",      # Workload Identity - Allow pods to access GCP services
    "sts.googleapis.com"                  # Security Token Service - Token exchange for Workload Identity
)

Write-Host "Enabling GCP APIs for project: $env:PROJECT_ID" -ForegroundColor Green
Write-Host "This may take a few minutes..." -ForegroundColor Yellow
Write-Host ""

# Initialize counters to track success/failure
$successCount = 0
$failCount = 0

# ============================================================================
# STEP 3: Enable Each API
# ============================================================================
foreach ($api in $apis) {
    Write-Host "Enabling $api..." -ForegroundColor Cyan
    
    # Command: gcloud services enable
    # Purpose: Activates a specific GCP API for your project
    # Parameters:
    #   $api - The API service name (e.g., "container.googleapis.com")
    #   --project - Specifies which GCP project to enable the API for
    # Output: Redirects both stdout and stderr to $result variable (2>&1)
    $result = gcloud services enable $api --project=$env:PROJECT_ID 2>&1
    
    # Check if the command succeeded
    # $LASTEXITCODE contains the exit code of the last command (0 = success)
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] Enabled successfully" -ForegroundColor Green
        $successCount++
    } else {
        Write-Host "  [FAILED] Failed to enable" -ForegroundColor Red
        Write-Host "  Error: $result" -ForegroundColor Red
        $failCount++
    }
}

# ============================================================================
# STEP 4: Display Summary and Exit
# ============================================================================
Write-Host ""
Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "  Successfully enabled: $successCount APIs" -ForegroundColor Green
Write-Host "  Failed: $failCount APIs" -ForegroundColor $(if ($failCount -gt 0) { "Red" } else { "Green" })

# Exit with appropriate status
if ($failCount -eq 0) {
    Write-Host ""
    Write-Host "All APIs enabled successfully!" -ForegroundColor Green
    Write-Host "You can now proceed to create your GKE cluster." -ForegroundColor Yellow
    # Exit code 0 indicates success
} else {
    Write-Host ""
    Write-Host "Some APIs failed to enable. Please check the errors above." -ForegroundColor Red
    # Exit code 1 indicates failure
    exit 1
}
