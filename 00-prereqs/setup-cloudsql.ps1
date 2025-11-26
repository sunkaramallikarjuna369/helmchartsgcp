# Set up Cloud SQL (Managed PostgreSQL)
# Run this script from PowerShell on Windows
#
# This script creates a Cloud SQL instance with PostgreSQL database.
# Cloud SQL is Google's fully managed relational database service.
# OPTIONAL: This script is optional - only run if you need a managed database.

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

# Define Cloud SQL configuration
$INSTANCE_NAME = "helm-demo-postgres"     # Name of the Cloud SQL instance
$DB_NAME = "mydb"                         # Name of the database to create
$DB_USER = "myuser"                       # Database user name
$DB_PASSWORD = "MySecurePassword123!"     # Database password (change this!)

# ============================================================================
# STEP 2: Display Configuration and Get Confirmation
# ============================================================================
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

# Ask for user confirmation before proceeding
$confirmation = Read-Host "Do you want to proceed? (yes/no)"
if ($confirmation -ne "yes") {
    Write-Host "Cloud SQL setup cancelled." -ForegroundColor Yellow
    exit 0
}

# ============================================================================
# STEP 3: Create Cloud SQL Instance
# ============================================================================
Write-Host ""
Write-Host "Creating Cloud SQL instance..." -ForegroundColor Green
Write-Host "This will take 5-10 minutes..." -ForegroundColor Yellow

# Command: gcloud sql instances create
# Purpose: Creates a new Cloud SQL instance (managed PostgreSQL database)
# Parameters:
#   $INSTANCE_NAME - Name of the Cloud SQL instance
#   --database-version - PostgreSQL version (15 is latest stable)
#   --tier - Machine type (db-f1-micro is smallest, free tier eligible)
#   --region - GCP region where instance will be created
#   --root-password - Password for the postgres superuser
#   --storage-type - SSD for better performance
#   --storage-size - 10GB is minimum for Cloud SQL
#   --project - GCP project ID
# Note: This takes 5-10 minutes to provision
$result = gcloud sql instances create $INSTANCE_NAME `
    --database-version=POSTGRES_15 `
    --tier=db-f1-micro `
    --region=$env:REGION `
    --root-password=$DB_PASSWORD `
    --storage-type=SSD `
    --storage-size=10GB `
    --project=$env:PROJECT_ID 2>&1

# Check if instance creation succeeded
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

# ============================================================================
# STEP 4: Create Database
# ============================================================================
Write-Host ""
Write-Host "Creating database..." -ForegroundColor Yellow

# Command: gcloud sql databases create
# Purpose: Creates a new database within the Cloud SQL instance
# Parameters:
#   $DB_NAME - Name of the database to create
#   --instance - Cloud SQL instance name where database will be created
#   --project - GCP project ID
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

# ============================================================================
# STEP 5: Create Database User
# ============================================================================
Write-Host ""
Write-Host "Creating database user..." -ForegroundColor Yellow

# Command: gcloud sql users create
# Purpose: Creates a new user account for accessing the database
# Parameters:
#   $DB_USER - Username for the new database user
#   --instance - Cloud SQL instance name
#   --password - Password for the user
#   --project - GCP project ID
# Note: This user can be used by applications to connect to the database
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

# ============================================================================
# STEP 6: Get Connection Information
# ============================================================================
Write-Host ""
Write-Host "Getting connection details..." -ForegroundColor Yellow

# Command: gcloud sql instances describe
# Purpose: Retrieves detailed information about the Cloud SQL instance
# Parameters:
#   $INSTANCE_NAME - Name of the instance to describe
#   --format - Output format (value(connectionName) extracts just the connection name)
#   --project - GCP project ID
# Result: Returns the connection name in format: project:region:instance
#         This is used by Cloud SQL Proxy to connect to the database
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
