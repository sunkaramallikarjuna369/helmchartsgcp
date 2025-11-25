# Helm Charts for GCP - Enterprise Grade Guide

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
