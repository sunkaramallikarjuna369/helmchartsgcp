# Helm Charts for GCP - Enterprise Grade Guide

## What

A comprehensive, production-ready guide to deploying enterprise-grade applications on Google Kubernetes Engine (GKE) using Helm charts. This repository provides complete examples, scripts, and Python code for all essential Kubernetes and GCP patterns, designed to work within GCP free tier credits.

**What You'll Get:**
- 10 comprehensive concept sections covering all enterprise patterns
- GCP setup scripts (GKE Autopilot, Workload Identity, Artifact Registry)
- Working Python examples for SQL and NoSQL databases
- Helm chart templates and best practices
- Cost management and cleanup procedures

## Why

**Why This Guide Matters:**
- **Enterprise-Ready**: Covers production patterns (HA, security, observability, CI/CD) not just basics
- **GCP-Optimized**: Uses GCP-native services (Cloud SQL, Secret Manager, Workload Identity)
- **Cost-Conscious**: All examples work with free tier; managed services use trial credits with clear warnings
- **Practical**: Working code and scripts, not just theory
- **Complete**: From cluster setup to production deployment in one repository

**Why Helm on GKE:**
- **Templating**: Reusable, parameterized Kubernetes manifests
- **Versioning**: Track and rollback application deployments
- **Packaging**: Share and distribute applications easily
- **Ecosystem**: Leverage thousands of community charts
- **Enterprise Adoption**: Industry standard for Kubernetes deployments

**Trade-offs:**
- **Learning Curve**: Helm templating and Go templates require learning
- **Complexity**: More moving parts than raw kubectl
- **GCP-Specific**: Some patterns (Workload Identity, GCE Ingress) are GCP-only
- **Cost**: Managed services (Cloud SQL, LoadBalancers) consume credits

## When

**Use This Guide When:**
- Learning Helm and Kubernetes on GCP
- Building enterprise-grade applications on GKE
- Migrating applications to cloud-native architecture
- Setting up production Kubernetes infrastructure
- Need working examples of SQL/NoSQL integration
- Want to understand GCP-specific Kubernetes patterns

**Prerequisites:**
- GCP account with free tier or trial credits ($300 for 90 days)
- Basic Kubernetes knowledge (pods, deployments, services)
- Basic command-line skills (bash, kubectl, gcloud)
- Domain name (optional, for SSL/Ingress examples)

**When NOT to Use:**
- Production deployments without understanding the code
- If you need multi-cloud portability (some patterns are GCP-specific)
- If you have zero Kubernetes knowledge (learn basics first)

**Learning Sequence:**
1. **Beginners**: 00-prereqs → 01-helm-basics → 03-config-and-secrets → 05-networking → 06-datastores (in-cluster)
2. **Intermediate**: 02-platform → 04-storage → 06-datastores (Cloud SQL) → 07-observability → python-examples
3. **Advanced**: 08-security → 09-cicd → 10-enterprise-app

## Where

**GCP Services Used:**
- **Google Kubernetes Engine (GKE)**: Managed Kubernetes with Autopilot mode
- **Artifact Registry**: Store Helm charts and container images
- **Cloud SQL**: Managed PostgreSQL and MySQL
- **Secret Manager**: Centralized secrets management
- **Cloud Monitoring & Logging**: Observability
- **Cloud Load Balancing**: Ingress and external access
- **Workload Identity**: Secure pod-to-GCP authentication
- **Firestore/Datastore**: NoSQL databases
- **Memorystore**: Managed Redis (optional)

**IAM Roles Needed:**
- `roles/container.admin`: Create and manage GKE clusters
- `roles/compute.admin`: Manage compute resources
- `roles/iam.serviceAccountAdmin`: Configure Workload Identity
- `roles/artifactregistry.admin`: Manage Artifact Registry
- Specific roles per section (documented in each README)

**Repository Structure:**
```
helmchartsgcp/
├── README.md (this file)
├── 00-prereqs/          # GCP setup scripts
├── 01-helm-basics/      # Helm fundamentals
├── 02-platform/         # Platform patterns (HPA, PDB, probes)
├── 03-config-and-secrets/  # ConfigMaps, Secrets, Secret Manager
├── 04-storage/          # Persistent storage
├── 05-networking/       # Services, Ingress, SSL
├── 06-datastores/       # SQL and NoSQL databases
├── 07-observability/    # Monitoring and logging
├── 08-security/         # RBAC, NetworkPolicy, Pod Security
├── 09-cicd/            # GitHub Actions workflows
├── 10-enterprise-app/   # Golden template
└── python-examples/     # SQL and NoSQL connection code
```

**Where Costs Accrue:**
- **GKE Autopilot**: ~$0.10/hour per vCPU, $0.011/hour per GB RAM (minimal for small workloads)
- **Load Balancers**: $18-25/month per Ingress
- **Cloud SQL**: $10-50/month depending on instance size
- **Persistent Disks**: $0.04-0.17/GB/month
- **Data Transfer**: $0.01-0.12/GB egress
- **Free Tier**: $300 trial credits for 90 days

## How

### Platform-Specific Guides

#### 🪟 Windows Users
**See [WINDOWS-DEPLOYMENT-GUIDE.md](./WINDOWS-DEPLOYMENT-GUIDE.md)** for complete Windows-specific instructions including:
- Tool installation (gcloud CLI, kubectl, Helm, Python)
- PowerShell scripts for all setup tasks
- Windows-specific troubleshooting
- Step-by-step deployment guide

All scripts in `00-prereqs/` are available in both Bash (`.sh`) and PowerShell (`.ps1`) formats.

#### 🐧 Linux/Mac Users
Follow the quickstart below using Bash scripts.

### Quickstart (15 minutes)

**Linux/Mac:**
```bash
# 1. Clone repository
git clone https://github.com/sunkaramallikarjuna369/helmchartsgcp.git
cd helmchartsgcp

# 2. Set up GCP environment
cd 00-prereqs
export PROJECT_ID=your-gcp-project-id
export REGION=us-central1
export CLUSTER_NAME=my-gke-cluster

# Enable APIs
./enable-apis.sh

# Create GKE Autopilot cluster (takes 5-10 minutes)
./create-gke-autopilot.sh

# Set up Artifact Registry for Helm charts
./artifact-registry-helm.sh

# Configure Workload Identity
./workload-identity.sh

# 3. Learn Helm basics
cd ../01-helm-basics
# Read README.md and explore examples

# 4. Deploy a simple application
cd ../10-enterprise-app
# Follow README.md for deployment

# 5. Explore Python examples
cd ../python-examples
# Read README.md for SQL/NoSQL connection examples

# 6. Clean up to avoid charges
cd ../00-prereqs
./cleanup.sh
```

**Windows (PowerShell):**
```powershell
# 1. Clone repository
git clone https://github.com/sunkaramallikarjuna369/helmchartsgcp.git
cd helmchartsgcp

# 2. Set up GCP environment
cd 00-prereqs
$env:PROJECT_ID = "your-gcp-project-id"
$env:REGION = "us-central1"

# Enable APIs
.\enable-apis.ps1

# Create GKE Autopilot cluster (takes 5-10 minutes)
.\create-gke-autopilot.ps1

# Set up Artifact Registry for Helm charts
.\setup-artifact-registry.ps1

# Configure Workload Identity
.\setup-workload-identity.ps1

# 3. Follow the detailed Windows guide
# See WINDOWS-DEPLOYMENT-GUIDE.md for complete instructions

# 4. Clean up to avoid charges
.\cleanup.ps1
```

### Verify Setup

```bash
# Check cluster is running
kubectl get nodes

# Check Helm is installed
helm version

# Check Workload Identity
kubectl get serviceaccount -n default
kubectl describe serviceaccount default -n default

# Check Artifact Registry
gcloud artifacts repositories list
```

### Cleanup (IMPORTANT)

```bash
# Always run cleanup to avoid charges
cd 00-prereqs
./cleanup.sh

# Verify all resources deleted
gcloud compute forwarding-rules list
gcloud sql instances list
gcloud compute disks list --filter="name~gke-"
```

Comprehensive guide to using Helm charts on Google Cloud Platform (GCP) for enterprise-grade applications. All examples are designed to work with GCP free tier credits.

## 📚 Table of Contents

### [00-prereqs](./00-prereqs) - GCP Setup & Prerequisites
- GCP project setup and API enablement
- GKE Autopilot cluster creation
- Artifact Registry for Helm charts
- Workload Identity configuration
- Cleanup scripts to avoid charges

### [01-helm-basics](./01-helm-basics) - Helm Fundamentals
- Chart skeleton and structure
- Templating fundamentals
- Dependencies and subcharts
- Packaging and OCI registry
- Testing and linting

### [02-platform](./02-platform) - Platform Patterns
- Namespaces, quotas, and limits
- Probes, HPA, PDB, and priority classes
- Scheduling, affinity, and spread constraints
- Rollout strategies

### [03-config-and-secrets](./03-config-and-secrets) - Configuration Management
- ConfigMaps
- Kubernetes Secrets
- Secret Manager CSI driver with Workload Identity

### [04-storage](./04-storage) - Storage Solutions
- StorageClass with GCE Persistent Disks
- PersistentVolumes and PersistentVolumeClaims
- StatefulSets

### [05-networking](./05-networking) - Networking
- Services (ClusterIP, NodePort, LoadBalancer)
- GKE Ingress with managed certificates
- Gateway API (optional)

### [06-datastores](./06-datastores) - Databases & Data Stores
- In-cluster PostgreSQL (Bitnami)
- Cloud SQL with proxy sidecar
- Firestore Native mode
- Cloud Datastore
- Redis (in-cluster and Memorystore)

### [07-observability](./07-observability) - Monitoring & Logging
- Kube-prometheus-stack
- Cloud Monitoring integration
- Structured logging
- Alerts and SLOs

### [08-security](./08-security) - Security Best Practices
- RBAC and least privilege
- Network policies
- Pod Security Standards
- Image signing and scanning
- Binary Authorization (optional)

### [09-cicd](./09-cicd) - CI/CD Pipelines
- GitHub Actions for chart testing
- Publishing to Artifact Registry
- Deployment to GKE

### [10-enterprise-app](./10-enterprise-app) - Golden Template
- Complete enterprise application example
- Combines all patterns and best practices
- Multi-environment configurations

### [python-examples](./python-examples) - Python Integration
- SQL database connections (PostgreSQL, Cloud SQL)
- NoSQL connections (Firestore, Datastore, Redis)
- Sample applications demonstrating data operations

## 🚀 Quick Start

1. **Prerequisites**: Follow [00-prereqs](./00-prereqs/README.md) to set up your GCP environment
2. **Learn Basics**: Start with [01-helm-basics](./01-helm-basics/README.md) to understand Helm fundamentals
3. **Explore Patterns**: Browse through sections 02-09 for specific patterns
4. **Deploy Example**: Use [10-enterprise-app](./10-enterprise-app/README.md) as a complete reference

## 💰 Cost Management

All examples are designed to work within GCP free tier:
- Uses GKE Autopilot with minimal resources
- Provides in-cluster alternatives to managed services
- Includes cleanup scripts in each section
- Flags cost-incurring features (LoadBalancers, Cloud SQL)

**Important**: Always run cleanup scripts after testing to avoid unexpected charges.

## 🎯 Target Audience

- DevOps engineers learning Helm on GCP
- Platform engineers building enterprise Kubernetes infrastructure
- Developers deploying applications to GKE
- Teams migrating to cloud-native architectures

## 📖 Learning Path

**Beginner**: 00 → 01 → 03 → 05 → 06 (in-cluster databases)

**Intermediate**: 02 → 04 → 06 (Cloud SQL) → 07 → python-examples

**Advanced**: 08 → 09 → 10 (enterprise patterns)

## 🤝 Contributing

Each folder contains:
- `README.md` - Concept explanation and usage guide
- Helm chart files or configuration examples
- Scripts for setup and cleanup
- Cost warnings and free tier notes

## 📝 License

This repository is for educational purposes. Use at your own risk in production environments.

## ⚠️ Important Notes

1. **Free Tier**: Most examples use GCP free tier, but some managed services (Cloud SQL, LoadBalancers) will consume trial credits
2. **Cleanup**: Always run cleanup scripts to delete resources
3. **Security**: Never commit real secrets or credentials
4. **Testing**: Test in a non-production project first

## 🔗 Resources

- [Helm Documentation](https://helm.sh/docs/)
- [GKE Documentation](https://cloud.google.com/kubernetes-engine/docs)
- [GCP Free Tier](https://cloud.google.com/free)
- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)
