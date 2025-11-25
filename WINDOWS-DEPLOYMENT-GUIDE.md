# Windows Deployment Guide for Helm Charts on GCP

Complete guide for deploying all Helm charts to Google Kubernetes Engine (GKE) from a Windows machine.

## Table of Contents
1. [Prerequisites and Tool Installation](#prerequisites-and-tool-installation)
2. [GCP Project Setup](#gcp-project-setup)
3. [GKE Cluster Setup](#gke-cluster-setup)
4. [Deploying Helm Charts](#deploying-helm-charts)
5. [Database Setup and Connections](#database-setup-and-connections)
6. [Troubleshooting](#troubleshooting)

---

## Prerequisites and Tool Installation

### Step 1: Install Required Tools

#### 1.1 Install Google Cloud SDK (gcloud CLI)

**Download and Install:**
1. Download the Google Cloud SDK installer from: https://cloud.google.com/sdk/docs/install#windows
2. Run the installer (`GoogleCloudSDKInstaller.exe`)
3. Follow the installation wizard
4. Check "Start Cloud SDK Shell" at the end

**Verify Installation:**
```powershell
gcloud --version
```

**Initialize gcloud:**
```powershell
gcloud init
```

Follow the prompts to:
- Log in to your Google account
- Select or create a GCP project
- Set default region (recommend: `us-central1`)

#### 1.2 Install kubectl (Kubernetes CLI)

**Using gcloud:**
```powershell
gcloud components install kubectl
```

**Verify Installation:**
```powershell
kubectl version --client
```

#### 1.3 Install Helm

**Using Chocolatey (Recommended):**

First, install Chocolatey if you don't have it:
1. Open PowerShell as Administrator
2. Run:
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
```

Then install Helm:
```powershell
choco install kubernetes-helm
```

**Manual Installation:**
1. Download Helm from: https://github.com/helm/helm/releases
2. Extract the zip file
3. Add the `helm.exe` location to your PATH environment variable
4. Restart your terminal

**Verify Installation:**
```powershell
helm version
```

#### 1.4 Install Git (if not already installed)

**Download and Install:**
1. Download Git from: https://git-scm.com/download/win
2. Run the installer
3. Use default settings (Git Bash + Git from command line)

**Verify Installation:**
```powershell
git --version
```

#### 1.5 Install Python (for database connection examples)

**Download and Install:**
1. Download Python 3.11+ from: https://www.python.org/downloads/
2. Run the installer
3. **IMPORTANT:** Check "Add Python to PATH" during installation

**Verify Installation:**
```powershell
python --version
pip --version
```

---

## GCP Project Setup

### Step 2: Set Up Your GCP Project

#### 2.1 Set Environment Variables

Open PowerShell and set your project variables:

```powershell
# Set your GCP project ID
$env:PROJECT_ID = "your-project-id"
$env:REGION = "us-central1"
$env:ZONE = "us-central1-a"

# Set the project
gcloud config set project $env:PROJECT_ID
gcloud config set compute/region $env:REGION
gcloud config set compute/zone $env:ZONE
```

**To make these permanent, add them to your PowerShell profile:**
```powershell
# Open your PowerShell profile
notepad $PROFILE

# Add these lines:
$env:PROJECT_ID = "your-project-id"
$env:REGION = "us-central1"
$env:ZONE = "us-central1-a"
```

#### 2.2 Enable Required GCP APIs

Create a PowerShell script to enable all required APIs:

**Create file: `enable-apis.ps1`**
```powershell
# Enable required GCP APIs
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

Write-Host "Enabling GCP APIs..." -ForegroundColor Green

foreach ($api in $apis) {
    Write-Host "Enabling $api..." -ForegroundColor Yellow
    gcloud services enable $api --project=$env:PROJECT_ID
}

Write-Host "All APIs enabled successfully!" -ForegroundColor Green
```

**Run the script:**
```powershell
# Set execution policy (if needed)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Run the script
.\enable-apis.ps1
```

---

## GKE Cluster Setup

### Step 3: Create GKE Autopilot Cluster

#### 3.1 Create the Cluster

**Create file: `create-gke-cluster.ps1`**
```powershell
# GKE Autopilot Cluster Creation Script for Windows

$CLUSTER_NAME = "helm-demo-cluster"
$REGION = $env:REGION

Write-Host "Creating GKE Autopilot cluster: $CLUSTER_NAME" -ForegroundColor Green

gcloud container clusters create-auto $CLUSTER_NAME `
    --region=$REGION `
    --project=$env:PROJECT_ID `
    --release-channel=regular `
    --enable-autoscaling `
    --enable-autorepair `
    --enable-autoupgrade `
    --workload-pool="$env:PROJECT_ID.svc.id.goog"

Write-Host "Cluster created successfully!" -ForegroundColor Green

# Get cluster credentials
Write-Host "Getting cluster credentials..." -ForegroundColor Yellow
gcloud container clusters get-credentials $CLUSTER_NAME `
    --region=$REGION `
    --project=$env:PROJECT_ID

# Verify connection
Write-Host "Verifying cluster connection..." -ForegroundColor Yellow
kubectl cluster-info
kubectl get nodes

Write-Host "GKE cluster setup complete!" -ForegroundColor Green
```

**Run the script:**
```powershell
.\create-gke-cluster.ps1
```

**This will take 5-10 minutes.** The Autopilot cluster will be created with:
- Automatic node provisioning
- Automatic scaling
- Workload Identity enabled
- Regional high availability

#### 3.2 Set Up Artifact Registry for Helm Charts

**Create file: `setup-artifact-registry.ps1`**
```powershell
# Artifact Registry Setup for Helm Charts

$REPO_NAME = "helm-charts"
$REGION = $env:REGION

Write-Host "Creating Artifact Registry repository for Helm charts..." -ForegroundColor Green

gcloud artifacts repositories create $REPO_NAME `
    --repository-format=docker `
    --location=$REGION `
    --description="Helm charts and container images" `
    --project=$env:PROJECT_ID

Write-Host "Artifact Registry repository created!" -ForegroundColor Green

# Configure Docker authentication
Write-Host "Configuring Docker authentication..." -ForegroundColor Yellow
gcloud auth configure-docker "$REGION-docker.pkg.dev"

Write-Host "Artifact Registry setup complete!" -ForegroundColor Green
Write-Host "Repository URL: $REGION-docker.pkg.dev/$env:PROJECT_ID/$REPO_NAME" -ForegroundColor Cyan
```

**Run the script:**
```powershell
.\setup-artifact-registry.ps1
```

#### 3.3 Set Up Workload Identity

**Create file: `setup-workload-identity.ps1`**
```powershell
# Workload Identity Setup

$GSA_NAME = "helm-demo-gsa"
$KSA_NAME = "helm-demo-ksa"
$NAMESPACE = "default"

Write-Host "Setting up Workload Identity..." -ForegroundColor Green

# Create GCP service account
Write-Host "Creating GCP service account: $GSA_NAME" -ForegroundColor Yellow
gcloud iam service-accounts create $GSA_NAME `
    --display-name="Helm Demo Service Account" `
    --project=$env:PROJECT_ID

# Grant necessary permissions
Write-Host "Granting IAM permissions..." -ForegroundColor Yellow
$roles = @(
    "roles/cloudsql.client",
    "roles/secretmanager.secretAccessor",
    "roles/monitoring.metricWriter",
    "roles/logging.logWriter",
    "roles/cloudtrace.agent"
)

foreach ($role in $roles) {
    gcloud projects add-iam-policy-binding $env:PROJECT_ID `
        --member="serviceAccount:$GSA_NAME@$env:PROJECT_ID.iam.gserviceaccount.com" `
        --role=$role
}

# Create Kubernetes service account
Write-Host "Creating Kubernetes service account: $KSA_NAME" -ForegroundColor Yellow
kubectl create serviceaccount $KSA_NAME --namespace=$NAMESPACE

# Bind GCP SA to K8s SA
Write-Host "Binding service accounts..." -ForegroundColor Yellow
gcloud iam service-accounts add-iam-policy-binding `
    "$GSA_NAME@$env:PROJECT_ID.iam.gserviceaccount.com" `
    --role="roles/iam.workloadIdentityUser" `
    --member="serviceAccount:$env:PROJECT_ID.svc.id.goog[$NAMESPACE/$KSA_NAME]"

# Annotate K8s service account
kubectl annotate serviceaccount $KSA_NAME `
    --namespace=$NAMESPACE `
    "iam.gke.io/gcp-service-account=$GSA_NAME@$env:PROJECT_ID.iam.gserviceaccount.com"

Write-Host "Workload Identity setup complete!" -ForegroundColor Green
```

**Run the script:**
```powershell
.\setup-workload-identity.ps1
```

---

## Deploying Helm Charts

### Step 4: Clone the Repository

```powershell
# Clone the repository
git clone https://github.com/sunkaramallikarjuna369/helmchartsgcp.git
cd helmchartsgcp

# Switch to the branch with all content
git checkout devin/1764046602-comprehensive-helm-charts
```

### Step 5: Deploy Helm Charts Step by Step

#### 5.1 Deploy Basic Application (01-helm-basics)

```powershell
cd 01-helm-basics

# Install the chart
helm install my-app ./chart-skeleton `
    --set image.repository="nginx" `
    --set image.tag="latest" `
    --set service.type="LoadBalancer"

# Check deployment
kubectl get pods
kubectl get services

# Get the external IP (wait for EXTERNAL-IP to appear)
kubectl get service my-app-chart-skeleton --watch

# Test the application
# Once you have the EXTERNAL-IP, open it in your browser
```

#### 5.2 Deploy with ConfigMaps and Secrets (03-config-and-secrets)

```powershell
cd ..\03-config-and-secrets

# Create a Secret Manager secret first
gcloud secrets create app-secret `
    --data-file=- `
    --replication-policy="automatic" `
    --project=$env:PROJECT_ID

# Add secret data
echo "my-secret-password" | gcloud secrets versions add app-secret --data-file=-

# Install the chart
helm install config-app ./config-app `
    --set config.environment="production" `
    --set config.logLevel="info" `
    --set secrets.enabled=true `
    --set secrets.projectId=$env:PROJECT_ID

# Verify
kubectl get pods
kubectl get configmaps
kubectl get secrets
```

#### 5.3 Deploy with Persistent Storage (04-storage)

```powershell
cd ..\04-storage

# Install the chart with persistent volume
helm install storage-app ./storage-app `
    --set persistence.enabled=true `
    --set persistence.size="10Gi" `
    --set persistence.storageClass="standard-rwo"

# Verify PVC
kubectl get pvc
kubectl get pv

# Check pod
kubectl get pods
```

#### 5.4 Deploy with Autoscaling (02-platform)

```powershell
cd ..\02-platform

# Install with HPA and PDB
helm install platform-app ./platform-app `
    --set autoscaling.enabled=true `
    --set autoscaling.minReplicas=2 `
    --set autoscaling.maxReplicas=10 `
    --set autoscaling.targetCPUUtilizationPercentage=70 `
    --set podDisruptionBudget.enabled=true `
    --set podDisruptionBudget.minAvailable=1

# Verify HPA
kubectl get hpa

# Verify PDB
kubectl get pdb

# Check pods
kubectl get pods
```

#### 5.5 Deploy with Observability (07-observability)

```powershell
cd ..\07-observability

# Install Prometheus (for metrics collection)
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install prometheus prometheus-community/kube-prometheus-stack `
    --namespace monitoring `
    --create-namespace `
    --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false

# Install your app with observability
helm install observable-app ./observable-app `
    --set metrics.enabled=true `
    --set metrics.port=9090 `
    --set healthChecks.enabled=true

# Verify ServiceMonitor
kubectl get servicemonitor

# Access Prometheus UI
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

# Open http://localhost:9090 in your browser
```

#### 5.6 Deploy with Security (08-security)

```powershell
cd ..\08-security

# Install with RBAC and Network Policies
helm install secure-app ./secure-app `
    --set rbac.enabled=true `
    --set networkPolicy.enabled=true `
    --set podSecurityContext.runAsNonRoot=true `
    --set podSecurityContext.runAsUser=1000 `
    --set serviceAccount.create=true `
    --set serviceAccount.name="secure-app-sa"

# Verify RBAC
kubectl get serviceaccount
kubectl get role
kubectl get rolebinding

# Verify Network Policy
kubectl get networkpolicy

# Check pod security
kubectl get pods -o yaml | Select-String -Pattern "securityContext"
```

#### 5.7 Deploy Enterprise Application (10-enterprise-app)

```powershell
cd ..\10-enterprise-app

# Install the complete enterprise-grade application
helm install enterprise-app ./enterprise-app `
    --set environment="production" `
    --set replicaCount=3 `
    --set autoscaling.enabled=true `
    --set autoscaling.minReplicas=3 `
    --set autoscaling.maxReplicas=10 `
    --set podDisruptionBudget.enabled=true `
    --set rbac.enabled=true `
    --set networkPolicy.enabled=true `
    --set metrics.enabled=true `
    --set ingress.enabled=false `
    --set service.type="LoadBalancer"

# Verify all resources
kubectl get all
kubectl get hpa
kubectl get pdb
kubectl get networkpolicy
kubectl get servicemonitor

# Get the service URL
kubectl get service enterprise-app --watch
```

---

## Database Setup and Connections

### Step 6: Set Up Databases

#### 6.1 Deploy PostgreSQL (In-Cluster)

```powershell
cd ..\06-datastores

# Add Bitnami Helm repository
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Install PostgreSQL
helm install postgresql bitnami/postgresql `
    --set auth.username=myuser `
    --set auth.password=mypassword `
    --set auth.database=mydb `
    --set primary.persistence.size=10Gi

# Get the password
$POSTGRES_PASSWORD = kubectl get secret postgresql -o jsonpath="{.data.postgres-password}" | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
Write-Host "PostgreSQL password: $POSTGRES_PASSWORD"

# Connect to PostgreSQL
kubectl run postgresql-client --rm --tty -i --restart='Never' --image=postgres:15 --env="PGPASSWORD=$POSTGRES_PASSWORD" -- psql -h postgresql -U myuser -d mydb
```

#### 6.2 Set Up Cloud SQL (Managed PostgreSQL)

**Create file: `setup-cloudsql.ps1`**
```powershell
# Cloud SQL Setup

$INSTANCE_NAME = "helm-demo-postgres"
$DB_NAME = "mydb"
$DB_USER = "myuser"
$DB_PASSWORD = "MySecurePassword123!"

Write-Host "Creating Cloud SQL instance..." -ForegroundColor Green

gcloud sql instances create $INSTANCE_NAME `
    --database-version=POSTGRES_15 `
    --tier=db-f1-micro `
    --region=$env:REGION `
    --root-password=$DB_PASSWORD `
    --storage-type=SSD `
    --storage-size=10GB `
    --project=$env:PROJECT_ID

Write-Host "Creating database..." -ForegroundColor Yellow
gcloud sql databases create $DB_NAME `
    --instance=$INSTANCE_NAME `
    --project=$env:PROJECT_ID

Write-Host "Creating database user..." -ForegroundColor Yellow
gcloud sql users create $DB_USER `
    --instance=$INSTANCE_NAME `
    --password=$DB_PASSWORD `
    --project=$env:PROJECT_ID

# Get connection name
$CONNECTION_NAME = gcloud sql instances describe $INSTANCE_NAME `
    --format="value(connectionName)" `
    --project=$env:PROJECT_ID

Write-Host "Cloud SQL setup complete!" -ForegroundColor Green
Write-Host "Connection name: $CONNECTION_NAME" -ForegroundColor Cyan
Write-Host "Database: $DB_NAME" -ForegroundColor Cyan
Write-Host "User: $DB_USER" -ForegroundColor Cyan
```

**Run the script:**
```powershell
.\setup-cloudsql.ps1
```

#### 6.3 Deploy Redis (In-Cluster)

```powershell
# Install Redis
helm install redis bitnami/redis `
    --set auth.enabled=true `
    --set auth.password=myredispassword `
    --set master.persistence.size=8Gi

# Get Redis password
$REDIS_PASSWORD = kubectl get secret redis -o jsonpath="{.data.redis-password}" | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
Write-Host "Redis password: $REDIS_PASSWORD"

# Test Redis connection
kubectl run redis-client --rm --tty -i --restart='Never' --image=redis:7 -- redis-cli -h redis-master -a $REDIS_PASSWORD
```

#### 6.4 Set Up Firestore

```powershell
# Enable Firestore
gcloud firestore databases create `
    --location=$env:REGION `
    --project=$env:PROJECT_ID

Write-Host "Firestore enabled!" -ForegroundColor Green
```

### Step 7: Test Python Database Connections

#### 7.1 Set Up Python Environment

```powershell
cd ..\python-examples

# Create virtual environment
python -m venv venv

# Activate virtual environment
.\venv\Scripts\Activate.ps1

# Install dependencies for SQL
cd sql
pip install -r requirements.txt

# Install dependencies for NoSQL
cd ..\nosql
pip install -r requirements.txt
```

#### 7.2 Test PostgreSQL Connection (In-Cluster)

**Create file: `test-postgres.ps1`**
```powershell
# Port forward to PostgreSQL
Start-Job -ScriptBlock {
    kubectl port-forward svc/postgresql 5432:5432
}

# Wait for port forward
Start-Sleep -Seconds 3

# Set environment variables
$env:DB_HOST = "localhost"
$env:DB_PORT = "5432"
$env:DB_NAME = "mydb"
$env:DB_USER = "myuser"
$env:DB_PASSWORD = "mypassword"

# Run the Python script
cd ..\python-examples\sql
python postgresql_direct.py

# Stop port forward
Get-Job | Stop-Job
Get-Job | Remove-Job
```

**Run the script:**
```powershell
.\test-postgres.ps1
```

#### 7.3 Test Cloud SQL Connection

```powershell
# Set environment variables
$env:INSTANCE_CONNECTION_NAME = "your-project:us-central1:helm-demo-postgres"
$env:DB_NAME = "mydb"
$env:DB_USER = "myuser"
$env:DB_PASSWORD = "MySecurePassword123!"

# Run the Python script
cd ..\python-examples\sql
python postgresql_cloudsql.py
```

#### 7.4 Test Firestore Connection

```powershell
# Set environment variable
$env:GCP_PROJECT = $env:PROJECT_ID

# Run the Python script
cd ..\python-examples\nosql
python firestore_example.py
```

#### 7.5 Test Redis Connection

```powershell
# Port forward to Redis
Start-Job -ScriptBlock {
    kubectl port-forward svc/redis-master 6379:6379
}

# Wait for port forward
Start-Sleep -Seconds 3

# Set environment variables
$env:REDIS_HOST = "localhost"
$env:REDIS_PORT = "6379"
$env:REDIS_PASSWORD = "myredispassword"

# Run the Python script
cd ..\python-examples\nosql
python redis_example.py

# Stop port forward
Get-Job | Stop-Job
Get-Job | Remove-Job
```

---

## Troubleshooting

### Common Issues and Solutions

#### Issue 1: PowerShell Execution Policy Error

**Error:**
```
cannot be loaded because running scripts is disabled on this system
```

**Solution:**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

#### Issue 2: kubectl Not Found

**Error:**
```
kubectl : The term 'kubectl' is not recognized
```

**Solution:**
```powershell
# Install kubectl via gcloud
gcloud components install kubectl

# Or add kubectl to PATH manually
$env:PATH += ";C:\Program Files (x86)\Google\Cloud SDK\google-cloud-sdk\bin"
```

#### Issue 3: Cluster Connection Issues

**Error:**
```
Unable to connect to the server
```

**Solution:**
```powershell
# Get fresh credentials
gcloud container clusters get-credentials helm-demo-cluster `
    --region=$env:REGION `
    --project=$env:PROJECT_ID

# Verify connection
kubectl cluster-info
```

#### Issue 4: Helm Chart Installation Fails

**Error:**
```
Error: INSTALLATION FAILED
```

**Solution:**
```powershell
# Check Helm version
helm version

# Update Helm repositories
helm repo update

# Check for existing releases
helm list

# Uninstall if needed
helm uninstall <release-name>

# Try installation again with --debug flag
helm install <release-name> <chart-path> --debug
```

#### Issue 5: LoadBalancer External IP Pending

**Error:**
```
EXTERNAL-IP shows <pending> for a long time
```

**Solution:**
```powershell
# This is normal for GKE - wait 2-5 minutes

# Check service status
kubectl describe service <service-name>

# Check events
kubectl get events --sort-by='.lastTimestamp'

# If still pending after 10 minutes, check quotas
gcloud compute project-info describe --project=$env:PROJECT_ID
```

#### Issue 6: Python Module Not Found

**Error:**
```
ModuleNotFoundError: No module named 'psycopg2'
```

**Solution:**
```powershell
# Activate virtual environment
.\venv\Scripts\Activate.ps1

# Install requirements
pip install -r requirements.txt

# If psycopg2 fails, try binary version
pip install psycopg2-binary
```

#### Issue 7: Port Forward Connection Refused

**Error:**
```
Unable to listen on port 5432: Listeners failed to create with the following errors
```

**Solution:**
```powershell
# Check if port is already in use
netstat -ano | findstr :5432

# Kill the process using the port (replace PID)
taskkill /PID <PID> /F

# Or use a different port
kubectl port-forward svc/postgresql 5433:5432
```

#### Issue 8: GCP API Not Enabled

**Error:**
```
API [xxx.googleapis.com] not enabled on project
```

**Solution:**
```powershell
# Enable the specific API
gcloud services enable <api-name> --project=$env:PROJECT_ID

# Or run the enable-apis.ps1 script again
.\enable-apis.ps1
```

---

## Cleanup

### Remove All Resources

**Create file: `cleanup-all.ps1`**
```powershell
# Cleanup Script - Remove all resources

Write-Host "WARNING: This will delete all resources!" -ForegroundColor Red
$confirmation = Read-Host "Type 'yes' to continue"

if ($confirmation -ne "yes") {
    Write-Host "Cleanup cancelled." -ForegroundColor Yellow
    exit
}

# Uninstall all Helm releases
Write-Host "Uninstalling Helm releases..." -ForegroundColor Yellow
helm list --short | ForEach-Object { helm uninstall $_ }

# Delete Cloud SQL instance
Write-Host "Deleting Cloud SQL instance..." -ForegroundColor Yellow
gcloud sql instances delete helm-demo-postgres --project=$env:PROJECT_ID --quiet

# Delete GKE cluster
Write-Host "Deleting GKE cluster..." -ForegroundColor Yellow
gcloud container clusters delete helm-demo-cluster `
    --region=$env:REGION `
    --project=$env:PROJECT_ID `
    --quiet

# Delete Artifact Registry repository
Write-Host "Deleting Artifact Registry..." -ForegroundColor Yellow
gcloud artifacts repositories delete helm-charts `
    --location=$env:REGION `
    --project=$env:PROJECT_ID `
    --quiet

# Delete service account
Write-Host "Deleting service account..." -ForegroundColor Yellow
gcloud iam service-accounts delete helm-demo-gsa@$env:PROJECT_ID.iam.gserviceaccount.com `
    --project=$env:PROJECT_ID `
    --quiet

Write-Host "Cleanup complete!" -ForegroundColor Green
```

**Run the script:**
```powershell
.\cleanup-all.ps1
```

---

## Cost Management

### Free Tier Resources Used

All resources in this guide can be run within GCP's free tier or with minimal costs:

1. **GKE Autopilot**: $0.10/hour for cluster management (~$73/month)
   - **Free tier**: $74.40/month credit for GKE Autopilot
   - **Net cost**: ~$0 for first cluster

2. **Cloud SQL (db-f1-micro)**: ~$7/month
   - **Tip**: Stop instance when not in use to save costs

3. **Persistent Disks**: ~$0.40/month for 10GB
   - **Free tier**: 30GB standard persistent disk included

4. **Artifact Registry**: First 0.5GB free, then $0.10/GB/month

5. **Firestore**: 1GB storage free, 50K reads/day free

6. **Secret Manager**: First 6 secret versions free

### Cost Optimization Tips

```powershell
# Stop Cloud SQL when not in use
gcloud sql instances patch helm-demo-postgres --activation-policy=NEVER

# Start Cloud SQL when needed
gcloud sql instances patch helm-demo-postgres --activation-policy=ALWAYS

# Scale down deployments when not in use
kubectl scale deployment <deployment-name> --replicas=0

# Scale up when needed
kubectl scale deployment <deployment-name> --replicas=3

# Delete unused persistent volumes
kubectl delete pvc <pvc-name>
```

---

## Next Steps

1. **Explore the README files** in each folder for detailed explanations of concepts
2. **Customize the Helm charts** for your specific applications
3. **Set up CI/CD** using the examples in `09-cicd/`
4. **Implement monitoring** using the observability patterns in `07-observability/`
5. **Secure your applications** using the security best practices in `08-security/`

---

## Additional Resources

- **GCP Documentation**: https://cloud.google.com/docs
- **Kubernetes Documentation**: https://kubernetes.io/docs/
- **Helm Documentation**: https://helm.sh/docs/
- **GKE Best Practices**: https://cloud.google.com/kubernetes-engine/docs/best-practices
- **PowerShell Documentation**: https://docs.microsoft.com/en-us/powershell/

---

## Support

If you encounter any issues:

1. Check the [Troubleshooting](#troubleshooting) section above
2. Review the detailed README files in each folder
3. Check GCP Console for resource status and logs
4. Use `kubectl describe` and `kubectl logs` for debugging

**Example debugging commands:**
```powershell
# Check pod status
kubectl get pods
kubectl describe pod <pod-name>
kubectl logs <pod-name>

# Check service status
kubectl get services
kubectl describe service <service-name>

# Check events
kubectl get events --sort-by='.lastTimestamp'

# Check Helm release status
helm status <release-name>
helm get values <release-name>
```

---

**Happy deploying! 🚀**
