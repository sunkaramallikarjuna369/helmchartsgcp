# Set up Workload Identity for GKE
# Run this script from PowerShell on Windows

# Check if required environment variables are set
if (-not $env:PROJECT_ID) {
    Write-Host "ERROR: PROJECT_ID environment variable is not set!" -ForegroundColor Red
    Write-Host "Please set it with: `$env:PROJECT_ID = 'your-project-id'" -ForegroundColor Yellow
    exit 1
}

$GSA_NAME = "helm-demo-gsa"
$KSA_NAME = "helm-demo-ksa"
$NAMESPACE = "default"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Workload Identity Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Project ID: $env:PROJECT_ID" -ForegroundColor Yellow
Write-Host "GCP Service Account: $GSA_NAME" -ForegroundColor Yellow
Write-Host "K8s Service Account: $KSA_NAME" -ForegroundColor Yellow
Write-Host "Namespace: $NAMESPACE" -ForegroundColor Yellow
Write-Host ""

# Create GCP service account
Write-Host "Step 1: Creating GCP service account..." -ForegroundColor Green

$result = gcloud iam service-accounts create $GSA_NAME `
    --display-name="Helm Demo Service Account" `
    --project=$env:PROJECT_ID 2>&1

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

# Grant necessary permissions
Write-Host ""
Write-Host "Step 2: Granting IAM permissions..." -ForegroundColor Green

$roles = @(
    "roles/cloudsql.client",
    "roles/secretmanager.secretAccessor",
    "roles/monitoring.metricWriter",
    "roles/logging.logWriter",
    "roles/cloudtrace.agent"
)

$successCount = 0
$failCount = 0

foreach ($role in $roles) {
    Write-Host "  Granting $role..." -ForegroundColor Cyan
    
    $result = gcloud projects add-iam-policy-binding $env:PROJECT_ID `
        --member="serviceAccount:$GSA_NAME@$env:PROJECT_ID.iam.gserviceaccount.com" `
        --role=$role `
        --condition=None 2>&1
    
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

# Create Kubernetes service account
Write-Host ""
Write-Host "Step 3: Creating Kubernetes service account..." -ForegroundColor Green

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

# Bind GCP SA to K8s SA
Write-Host ""
Write-Host "Step 4: Binding service accounts..." -ForegroundColor Green

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

# Annotate K8s service account
Write-Host ""
Write-Host "Step 5: Annotating Kubernetes service account..." -ForegroundColor Green

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
