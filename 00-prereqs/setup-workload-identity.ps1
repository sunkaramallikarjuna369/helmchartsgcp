# Set up Workload Identity for GKE
# Run this script from PowerShell on Windows
#
# This script configures Workload Identity, which allows Kubernetes pods to securely
# access Google Cloud services without needing to manage service account keys.
# It creates both a GCP service account and a Kubernetes service account, then binds them.

# ============================================================================
# STEP 1: Validate Environment Variables
# ============================================================================
# Check if PROJECT_ID environment variable is set
if (-not $env:PROJECT_ID) {
    Write-Host "ERROR: PROJECT_ID environment variable is not set!" -ForegroundColor Red
    Write-Host "Please set it with: `$env:PROJECT_ID = 'your-project-id'" -ForegroundColor Yellow
    exit 1
}

# Define service account names and namespace
$GSA_NAME = "helm-demo-gsa"  # GCP Service Account name
$KSA_NAME = "helm-demo-ksa"  # Kubernetes Service Account name
$NAMESPACE = "default"       # Kubernetes namespace

# ============================================================================
# STEP 2: Display Configuration
# ============================================================================
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Workload Identity Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Project ID: $env:PROJECT_ID" -ForegroundColor Yellow
Write-Host "GCP Service Account: $GSA_NAME" -ForegroundColor Yellow
Write-Host "K8s Service Account: $KSA_NAME" -ForegroundColor Yellow
Write-Host "Namespace: $NAMESPACE" -ForegroundColor Yellow
Write-Host ""

# ============================================================================
# STEP 3: Create GCP Service Account
# ============================================================================
Write-Host "Step 1: Creating GCP service account..." -ForegroundColor Green

# Command: gcloud iam service-accounts create
# Purpose: Creates a new Google Cloud service account for your application
# Parameters:
#   $GSA_NAME - Name of the service account to create
#   --display-name - Human-readable name shown in GCP Console
#   --project - GCP project ID
# Note: Service accounts are used to grant permissions to applications
$result = gcloud iam service-accounts create $GSA_NAME `
    --display-name="Helm Demo Service Account" `
    --project=$env:PROJECT_ID 2>&1

# Check if service account creation succeeded
if ($LASTEXITCODE -ne 0) {
    if ($result -like "*already exists*") {
        Write-Host "  Service account already exists, continuing..." -ForegroundColor Yellow
    } else {
        Write-Host ""
        Write-Host "ERROR: Failed to create service account!" -ForegroundColor Red
        Write-Host $result -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "  [SUCCESS] Service account created" -ForegroundColor Green
}

# ============================================================================
# STEP 4: Grant IAM Permissions to Service Account
# ============================================================================
Write-Host ""
Write-Host "Step 2: Granting IAM permissions..." -ForegroundColor Green

# Define the IAM roles to grant to the service account
# Each role provides specific permissions:
$roles = @(
    "roles/cloudsql.client",              # Access Cloud SQL databases
    "roles/secretmanager.secretAccessor", # Read secrets from Secret Manager
    "roles/monitoring.metricWriter",      # Write metrics to Cloud Monitoring
    "roles/logging.logWriter",            # Write logs to Cloud Logging
    "roles/cloudtrace.agent"              # Send traces to Cloud Trace
)

$successCount = 0
$failCount = 0

foreach ($role in $roles) {
    Write-Host "  Granting $role..." -ForegroundColor Cyan
    
    # Command: gcloud projects add-iam-policy-binding
    # Purpose: Grants an IAM role to a service account at the project level
    # Parameters:
    #   $env:PROJECT_ID - The GCP project to grant permissions in
    #   --member - The service account to grant permissions to
    #   --role - The IAM role to grant (defines what actions are allowed)
    #   --condition=None - No conditional access (always granted)
    $result = gcloud projects add-iam-policy-binding $env:PROJECT_ID `
        --member="serviceAccount:$GSA_NAME@$env:PROJECT_ID.iam.gserviceaccount.com" `
        --role=$role `
        --condition=None 2>&1
    
    # Check if permission grant succeeded
    if ($LASTEXITCODE -eq 0) {
        Write-Host "    [OK] Granted" -ForegroundColor Green
        $successCount++
    } else {
        Write-Host "    [FAILED] Failed" -ForegroundColor Red
        $failCount++
    }
}

if ($failCount -gt 0) {
    Write-Host ""
    Write-Host "WARNING: Some IAM bindings failed. Continuing anyway..." -ForegroundColor Yellow
}

# ============================================================================
# STEP 5: Create Kubernetes Service Account
# ============================================================================
Write-Host ""
Write-Host "Step 3: Creating Kubernetes service account..." -ForegroundColor Green

# Command: kubectl create serviceaccount
# Purpose: Creates a new service account in Kubernetes
# Parameters:
#   $KSA_NAME - Name of the Kubernetes service account
#   --namespace - Kubernetes namespace where the service account will be created
# Note: Pods use this service account to authenticate with GCP services
$result = kubectl create serviceaccount $KSA_NAME --namespace=$NAMESPACE 2>&1

if ($LASTEXITCODE -ne 0) {
    if ($result -like "*already exists*") {
        Write-Host "  Service account already exists, continuing..." -ForegroundColor Yellow
    } else {
        Write-Host ""
        Write-Host "ERROR: Failed to create Kubernetes service account!" -ForegroundColor Red
        Write-Host $result -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "  [SUCCESS] Kubernetes service account created" -ForegroundColor Green
}

# ============================================================================
# STEP 6: Bind GCP Service Account to Kubernetes Service Account
# ============================================================================
Write-Host ""
Write-Host "Step 4: Binding service accounts..." -ForegroundColor Green

# Command: gcloud iam service-accounts add-iam-policy-binding
# Purpose: Allows the Kubernetes service account to impersonate the GCP service account
# Parameters:
#   "$GSA_NAME@..." - The GCP service account to bind
#   --role - workloadIdentityUser role allows impersonation
#   --member - The Kubernetes service account that can impersonate
# Result: Pods using the K8s SA can now act as the GCP SA
$result = gcloud iam service-accounts add-iam-policy-binding `
    "$GSA_NAME@$env:PROJECT_ID.iam.gserviceaccount.com" `
    --role="roles/iam.workloadIdentityUser" `
    --member="serviceAccount:$env:PROJECT_ID.svc.id.goog[$NAMESPACE/$KSA_NAME]" 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "ERROR: Failed to bind service accounts!" -ForegroundColor Red
    Write-Host $result -ForegroundColor Red
    exit 1
}

Write-Host "  [SUCCESS] Service accounts bound" -ForegroundColor Green

# ============================================================================
# STEP 7: Annotate Kubernetes Service Account
# ============================================================================
Write-Host ""
Write-Host "Step 5: Annotating Kubernetes service account..." -ForegroundColor Green

# Command: kubectl annotate serviceaccount
# Purpose: Adds an annotation to the K8s service account linking it to the GCP SA
# Parameters:
#   $KSA_NAME - The Kubernetes service account to annotate
#   --namespace - Namespace where the service account exists
#   "iam.gke.io/gcp-service-account=..." - Annotation that links to GCP SA
#   --overwrite - Replace annotation if it already exists
# Result: GKE knows which GCP SA to use when pods use this K8s SA
$result = kubectl annotate serviceaccount $KSA_NAME `
    --namespace=$NAMESPACE `
    "iam.gke.io/gcp-service-account=$GSA_NAME@$env:PROJECT_ID.iam.gserviceaccount.com" `
    --overwrite 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "ERROR: Failed to annotate service account!" -ForegroundColor Red
    Write-Host $result -ForegroundColor Red
    exit 1
}

Write-Host "  [SUCCESS] Service account annotated" -ForegroundColor Green

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Workload Identity Setup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Your pods can now access GCP services securely!" -ForegroundColor White
Write-Host ""
Write-Host "To use Workload Identity in your pods:" -ForegroundColor Yellow
Write-Host "  1. Set serviceAccountName: $KSA_NAME in your pod spec" -ForegroundColor White
Write-Host "  2. Your pod will automatically have access to:" -ForegroundColor White
Write-Host "     - Cloud SQL" -ForegroundColor Gray
Write-Host "     - Secret Manager" -ForegroundColor Gray
Write-Host "     - Cloud Monitoring" -ForegroundColor Gray
Write-Host "     - Cloud Logging" -ForegroundColor Gray
Write-Host "     - Cloud Trace" -ForegroundColor Gray
Write-Host ""
