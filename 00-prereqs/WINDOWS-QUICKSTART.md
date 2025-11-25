# Windows Quick Start Guide (PowerShell)

Complete step-by-step guide to deploy Helm charts on GCP from Windows using PowerShell.

---

## Prerequisites

- Windows 10/11
- Administrator access (for some installations)
- GCP account with free trial credits ($300 for 90 days)

---

## Step-by-Step Instructions

### Step 1: Install Required Tools (15 minutes)

#### 1.1 Install Google Cloud SDK

1. Download from: https://cloud.google.com/sdk/docs/install#windows
2. Run `GoogleCloudSDKInstaller.exe`
3. Follow the installation wizard
4. Check "Start Cloud SDK Shell" at the end
5. Verify installation:
   ```powershell
   gcloud version
   ```

#### 1.2 Install kubectl

```powershell
gcloud components install kubectl
```

Verify:
```powershell
kubectl version --client
```

#### 1.3 Install Helm

**Option A: Using Chocolatey (Recommended)**

1. Install Chocolatey (run PowerShell as Administrator):
   ```powershell
   Set-ExecutionPolicy Bypass -Scope Process -Force
   [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
   iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
   ```

2. Install Helm:
   ```powershell
   choco install kubernetes-helm
   ```

**Option B: Manual Installation**

1. Download from: https://github.com/helm/helm/releases
2. Extract the zip file
3. Add `helm.exe` location to your PATH environment variable
4. Restart PowerShell

Verify:
```powershell
helm version
```

#### 1.4 Install Git (if not already installed)

1. Download from: https://git-scm.com/download/win
2. Run the installer
3. Use default settings

Verify:
```powershell
git --version
```

---

### Step 2: Prepare PowerShell (2 minutes)

Allow running local scripts:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

Initialize gcloud (login and select project):
```powershell
gcloud init
```

Follow the prompts to:
- Log in to your Google account
- Select or create a GCP project
- Set default region

---

### Step 3: Set Environment Variables (2 minutes)

```powershell
# Set your project ID (change this to your actual project ID)
$env:PROJECT_ID = "my-helm-gcp-project"
$env:REGION = "us-central1"
$env:ZONE = "us-central1-a"

# Configure gcloud
gcloud config set project $env:PROJECT_ID
gcloud config set compute/region $env:REGION
gcloud config set compute/zone $env:ZONE
```

**Link billing account (required for free trial):**
```powershell
# List billing accounts
gcloud billing accounts list

# Copy the ACCOUNT_ID from the output above and run:
gcloud billing projects link $env:PROJECT_ID --billing-account=ACCOUNT_ID
```

---

### Step 4: Clone Repository (2 minutes)

```powershell
# Clone the repository
git clone https://github.com/sunkaramallikarjuna369/helmchartsgcp.git
cd helmchartsgcp

# Switch to the correct branch
git checkout devin/1764046602-comprehensive-helm-charts

# Go to prerequisites folder
cd 00-prereqs
```

---

### Step 5: Enable Required APIs (2 minutes)

```powershell
.\enable-apis.ps1
```

This will enable:
- Google Kubernetes Engine (GKE)
- Artifact Registry
- Cloud SQL
- Secret Manager
- Cloud Monitoring & Logging
- And more...

---

### Step 6: Create GKE Autopilot Cluster (10-15 minutes)

```powershell
.\create-gke-autopilot.ps1
```

**This will take 10-15 minutes.** The script will:
- Create a regional GKE Autopilot cluster
- Configure kubectl credentials
- Verify cluster connection

Wait for the script to complete before proceeding.

---

### Step 7: Set Up Artifact Registry (2 minutes)

```powershell
.\setup-artifact-registry.ps1
```

This creates a repository for storing Helm charts and container images.

---

### Step 8: Configure Workload Identity (5 minutes)

```powershell
.\setup-workload-identity.ps1
```

This sets up secure authentication between Kubernetes pods and GCP services.

---

### Step 9: (Optional) Create Cloud SQL Instance (10 minutes)

If you want to use managed PostgreSQL:

```powershell
.\setup-cloudsql.ps1
```

**Note:** This will consume trial credits (~$7/month). You can skip this and use in-cluster databases instead.

---

### Step 10: Verify Setup (2 minutes)

```powershell
# Check cluster is running
kubectl get nodes

# Check Helm
helm version

# Check Workload Identity
kubectl get serviceaccount -n default
kubectl describe serviceaccount default -n default

# Check Artifact Registry
gcloud artifacts repositories list

# Check enabled APIs
gcloud services list --enabled | Select-String -Pattern "container|artifact|sql|secret"
```

All commands should return successful results.

---

### Step 11: Deploy Example Application (5 minutes)

Deploy the enterprise-grade application template:

```powershell
# Go to enterprise app folder
cd ..\10-enterprise-app

# Install the Helm chart
helm install enterprise-app .\enterprise-app `
    --set environment="production" `
    --set replicaCount=3 `
    --set autoscaling.enabled=true `
    --set autoscaling.minReplicas=3 `
    --set autoscaling.maxReplicas=10 `
    --set service.type="LoadBalancer"

# Check deployment
kubectl get pods
kubectl get services

# Get the external IP (wait for EXTERNAL-IP to appear)
kubectl get service enterprise-app --watch
```

**Note:** Press `Ctrl+C` to stop watching. The external IP may take 2-5 minutes to appear.

Once you have the external IP, you can access your application at `http://<EXTERNAL-IP>`

---

### Step 12: Save Environment Variables (Optional)

To make environment variables persistent across PowerShell sessions:

```powershell
# Open your PowerShell profile
notepad $PROFILE

# Add these lines to the file:
$env:PROJECT_ID = "my-helm-gcp-project"
$env:REGION = "us-central1"
$env:ZONE = "us-central1-a"
$env:CLUSTER_NAME = "helm-demo-cluster"

# Save and close the file
```

---

## Cleanup (IMPORTANT - Run when done)

**To avoid charges, always run cleanup when you're done:**

```powershell
# Go back to prerequisites folder
cd ..\00-prereqs

# Run cleanup script
.\cleanup.ps1
```

This will prompt you to confirm deletion and then remove:
- GKE cluster
- Cloud SQL instance (if created)
- Artifact Registry repository
- Service accounts
- All Helm releases

**Verify all resources are deleted:**
```powershell
gcloud container clusters list
gcloud artifacts repositories list
gcloud compute forwarding-rules list
gcloud sql instances list
```

All commands should return empty or "Listed 0 items".

---

## Troubleshooting

### Issue: PowerShell Execution Policy Error

**Error:** `cannot be loaded because running scripts is disabled on this system`

**Solution:**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Issue: kubectl Not Found

**Error:** `kubectl : The term 'kubectl' is not recognized`

**Solution:**
```powershell
# Install kubectl via gcloud
gcloud components install kubectl

# Restart PowerShell
```

### Issue: Cluster Connection Issues

**Error:** `Unable to connect to the server`

**Solution:**
```powershell
# Get fresh credentials
gcloud container clusters get-credentials helm-demo-cluster `
    --region=$env:REGION `
    --project=$env:PROJECT_ID

# Verify connection
kubectl cluster-info
```

### Issue: LoadBalancer External IP Pending

**Error:** `EXTERNAL-IP shows <pending> for a long time`

**Solution:**
- This is normal for GKE - wait 2-5 minutes
- Check service status: `kubectl describe service <service-name>`
- If still pending after 10 minutes, check quotas: `gcloud compute project-info describe --project=$env:PROJECT_ID`

### Issue: Port Already in Use

**Error:** `Unable to listen on port 5432`

**Solution:**
```powershell
# Check if port is already in use
netstat -ano | findstr :5432

# Kill the process using the port (replace PID)
taskkill /PID <PID> /F

# Or use a different port
kubectl port-forward svc/postgresql 5433:5432
```

---

## Next Steps

1. **Explore Helm Basics:** Go to `01-helm-basics/` to learn Helm fundamentals
2. **Deploy More Applications:** Try other sections (02-platform, 03-config-and-secrets, etc.)
3. **Connect to Databases:** See `python-examples/` for SQL and NoSQL connection examples
4. **Set Up CI/CD:** Check `09-cicd/` for GitHub Actions workflows
5. **Security Best Practices:** Review `08-security/` for RBAC and Network Policies

---

## Cost Management

**Free Tier Coverage:**
- GKE Autopilot: $74.40/month free cluster management fee
- $300 free trial credits for 90 days
- Always Free tier for many services

**What Consumes Credits:**
- GKE Autopilot compute resources (minimal with small workloads)
- Cloud SQL instances (~$7/month for db-f1-micro)
- Load Balancers (~$18-25/month)
- Persistent Disks (~$0.40/month for 10GB)

**Cost Savings Tips:**
```powershell
# Stop Cloud SQL when not in use
gcloud sql instances patch helm-demo-postgres --activation-policy=NEVER

# Start Cloud SQL when needed
gcloud sql instances patch helm-demo-postgres --activation-policy=ALWAYS

# Scale down deployments when not in use
kubectl scale deployment <deployment-name> --replicas=0

# Scale up when needed
kubectl scale deployment <deployment-name> --replicas=3
```

---

## Additional Resources

- **Full Windows Guide:** See `WINDOWS-DEPLOYMENT-GUIDE.md` in the repository root for more detailed instructions
- **GCP Documentation:** https://cloud.google.com/docs
- **Kubernetes Documentation:** https://kubernetes.io/docs/
- **Helm Documentation:** https://helm.sh/docs/
- **PowerShell Documentation:** https://docs.microsoft.com/en-us/powershell/

---

## Summary of Commands

**Quick copy-paste sequence for experienced users:**

```powershell
# Setup
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
gcloud init
$env:PROJECT_ID = "my-helm-gcp-project"
$env:REGION = "us-central1"
gcloud config set project $env:PROJECT_ID
gcloud config set compute/region $env:REGION

# Clone and deploy
git clone https://github.com/sunkaramallikarjuna369/helmchartsgcp.git
cd helmchartsgcp
git checkout devin/1764046602-comprehensive-helm-charts
cd 00-prereqs

# Run setup scripts
.\enable-apis.ps1
.\create-gke-autopilot.ps1
.\setup-artifact-registry.ps1
.\setup-workload-identity.ps1

# Verify
kubectl get nodes
helm version

# Deploy app
cd ..\10-enterprise-app
helm install enterprise-app .\enterprise-app --set service.type="LoadBalancer"
kubectl get svc enterprise-app --watch

# Cleanup when done
cd ..\00-prereqs
.\cleanup.ps1
```

---

**Total Time:** ~35-45 minutes (including cluster creation)

**Questions?** Check the detailed guides:
- `00-prereqs/README.md` - Full prerequisites documentation
- `WINDOWS-DEPLOYMENT-GUIDE.md` - Comprehensive Windows guide with troubleshooting
