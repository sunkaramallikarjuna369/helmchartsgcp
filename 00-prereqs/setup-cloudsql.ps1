# Set up Cloud SQL (Managed PostgreSQL)
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

$INSTANCE_NAME = "helm-demo-postgres"
$DB_NAME = "mydb"
$DB_USER = "myuser"
$DB_PASSWORD = "MySecurePassword123!"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Cloud SQL Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Project ID: $env:PROJECT_ID" -ForegroundColor Yellow
Write-Host "Instance Name: $INSTANCE_NAME" -ForegroundColor Yellow
Write-Host "Region: $env:REGION" -ForegroundColor Yellow
Write-Host "Database: $DB_NAME" -ForegroundColor Yellow
Write-Host "User: $DB_USER" -ForegroundColor Yellow
Write-Host ""
Write-Host "This will create a Cloud SQL instance with:" -ForegroundColor Green
Write-Host "  - PostgreSQL 15" -ForegroundColor White
Write-Host "  - db-f1-micro tier (free tier eligible)" -ForegroundColor White
Write-Host "  - 10GB SSD storage" -ForegroundColor White
Write-Host ""
Write-Host "Estimated cost: ~`$7/month (stop when not in use to save)" -ForegroundColor Yellow
Write-Host "Estimated time: 5-10 minutes" -ForegroundColor Yellow
Write-Host ""

$confirmation = Read-Host "Do you want to proceed? (yes/no)"
if ($confirmation -ne "yes") {
    Write-Host "Cloud SQL setup cancelled." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "Creating Cloud SQL instance..." -ForegroundColor Green
Write-Host "This will take 5-10 minutes..." -ForegroundColor Yellow

$result = gcloud sql instances create $INSTANCE_NAME `
    --database-version=POSTGRES_15 `
    --tier=db-f1-micro `
    --region=$env:REGION `
    --root-password=$DB_PASSWORD `
    --storage-type=SSD `
    --storage-size=10GB `
    --project=$env:PROJECT_ID 2>&1

if ($LASTEXITCODE -ne 0) {
    if ($result -like "*already exists*") {
        Write-Host "Instance already exists, continuing..." -ForegroundColor Yellow
    } else {
        Write-Host ""
        Write-Host "ERROR: Failed to create Cloud SQL instance!" -ForegroundColor Red
        Write-Host $result -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "[SUCCESS] Instance created successfully!" -ForegroundColor Green
}

# Create database
Write-Host ""
Write-Host "Creating database..." -ForegroundColor Yellow

$result = gcloud sql databases create $DB_NAME `
    --instance=$INSTANCE_NAME `
    --project=$env:PROJECT_ID 2>&1

if ($LASTEXITCODE -ne 0) {
    if ($result -like "*already exists*") {
        Write-Host "Database already exists, continuing..." -ForegroundColor Yellow
    } else {
        Write-Host "WARNING: Failed to create database" -ForegroundColor Yellow
        Write-Host $result -ForegroundColor Yellow
    }
} else {
    Write-Host "[SUCCESS] Database created" -ForegroundColor Green
}

# Create database user
Write-Host ""
Write-Host "Creating database user..." -ForegroundColor Yellow

$result = gcloud sql users create $DB_USER `
    --instance=$INSTANCE_NAME `
    --password=$DB_PASSWORD `
    --project=$env:PROJECT_ID 2>&1

if ($LASTEXITCODE -ne 0) {
    if ($result -like "*already exists*") {
        Write-Host "User already exists, continuing..." -ForegroundColor Yellow
    } else {
        Write-Host "WARNING: Failed to create user" -ForegroundColor Yellow
        Write-Host $result -ForegroundColor Yellow
    }
} else {
    Write-Host "[SUCCESS] User created" -ForegroundColor Green
}

# Get connection name
Write-Host ""
Write-Host "Getting connection details..." -ForegroundColor Yellow

$CONNECTION_NAME = gcloud sql instances describe $INSTANCE_NAME `
    --format="value(connectionName)" `
    --project=$env:PROJECT_ID

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to get connection name!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Cloud SQL Setup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Connection Details:" -ForegroundColor Yellow
Write-Host "  Connection Name: $CONNECTION_NAME" -ForegroundColor Cyan
Write-Host "  Database: $DB_NAME" -ForegroundColor Cyan
Write-Host "  User: $DB_USER" -ForegroundColor Cyan
Write-Host "  Password: $DB_PASSWORD" -ForegroundColor Cyan
Write-Host ""
Write-Host "To connect from your application:" -ForegroundColor Yellow
Write-Host "  1. Use Cloud SQL Proxy sidecar in your pod" -ForegroundColor White
Write-Host "  2. Set INSTANCE_CONNECTION_NAME=$CONNECTION_NAME" -ForegroundColor White
Write-Host "  3. Connect to localhost:5432" -ForegroundColor White
Write-Host ""
Write-Host "Cost saving tip:" -ForegroundColor Yellow
Write-Host "  Stop instance when not in use:" -ForegroundColor White
Write-Host "  gcloud sql instances patch $INSTANCE_NAME --activation-policy=NEVER" -ForegroundColor Gray
Write-Host ""
Write-Host "  Start instance when needed:" -ForegroundColor White
Write-Host "  gcloud sql instances patch $INSTANCE_NAME --activation-policy=ALWAYS" -ForegroundColor Gray
Write-Host ""
