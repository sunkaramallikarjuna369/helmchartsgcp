# Enterprise Application - Golden Template

## What

Production-ready Helm chart template combining all best practices and patterns from previous sections, including high availability (HPA, PDB, anti-affinity), security (RBAC, Network Policies, Pod Security), observability (metrics, logging, health checks), configuration management (ConfigMaps, Secrets, Secret Manager CSI), and multi-environment support (dev, staging, production).

**Resources Created:**
- Deployment with security best practices
- Service (ClusterIP or LoadBalancer)
- Ingress with TLS (optional)
- HorizontalPodAutoscaler (automatic scaling)
- PodDisruptionBudget (availability during disruptions)
- ConfigMap (non-sensitive configuration)
- Secret (sensitive data)
- ServiceAccount with Workload Identity
- RBAC (Role and RoleBinding)
- NetworkPolicy (network segmentation)
- ServiceMonitor (Prometheus metrics)

## Why

**Why Use an Enterprise Template:**
- **Best Practices**: Incorporates all production-ready patterns
- **Consistency**: Same structure across all applications
- **Time Savings**: Don't reinvent the wheel for each app
- **Reliability**: Proven patterns for high availability
- **Security**: Built-in security controls
- **Observability**: Metrics and logging configured
- **Maintainability**: Easy to understand and modify

**Why This Matters:**
- **Production Readiness**: Meet enterprise SLAs and uptime requirements
- **Operational Excellence**: Reduce manual intervention and toil
- **Security Compliance**: Meet regulatory requirements
- **Cost Efficiency**: Optimize resource usage with HPA
- **Developer Productivity**: Focus on application code, not infrastructure
- **Incident Response**: Quick troubleshooting with observability

**Trade-offs:**
- **Complexity**: More configuration than simple deployments
- **Learning Curve**: Understanding all the patterns and resources
- **Resource Usage**: More resources than minimal deployments
- **Maintenance**: More components to maintain and update

**Alternatives:**
- **Simple Deployment**: Minimal YAML (not production-ready)
- **Kustomize**: Alternative to Helm (less templating)
- **Operators**: Custom controllers (more complex)
- **Service Mesh**: Istio/Linkerd (additional layer)

## When

**Use This Template When:**
- Deploying to production (always!)
- Need high availability and reliability
- Handling production traffic
- Need security and compliance
- Want observability and monitoring
- Multiple environments (dev, staging, production)
- Team collaboration on deployments

**Prerequisites:**
- Completed all previous sections (00-09)
- Understanding of all patterns (HPA, PDB, RBAC, Network Policies, etc.)
- Application with health check endpoints (/healthz, /ready, /metrics)
- Docker image in container registry
- GKE cluster with Workload Identity

**When to Customize:**
- Application-specific configuration
- Different resource requirements
- Custom health check paths
- Additional environment variables
- Application-specific network policies
- Custom metrics and alerts

**When NOT to Use:**
- Development/testing only (use simpler template)
- Proof of concepts (can simplify)
- Stateful applications (need StatefulSet instead)
- Batch jobs (use Job or CronJob instead)

**Learning Sequence:**
1. **Review template structure**: Understand all resources (20 minutes)
2. **Customize for your app**: Modify values and templates (30 minutes)
3. **Deploy to dev**: Test in development environment (15 minutes)
4. **Deploy to production**: Production deployment (15 minutes)
**Total Time**: ~1.5 hours

## Where

**GCP Services:**
- **GKE**: Kubernetes cluster
- **Artifact Registry**: Container images and Helm charts
- **Workload Identity**: Secure pod-to-GCP authentication
- **Cloud Logging**: Application logs
- **Cloud Monitoring**: Optional metrics (or use Prometheus)

**IAM Roles Required:**
- `roles/container.developer`: Deploy workloads
- `roles/artifactregistry.reader`: Pull images
- Application-specific roles (e.g., `roles/cloudsql.client`)

**Kubernetes Resources:**
- **Namespace**: Any namespace (dev, staging, production)
- **Deployment**: Application pods with replicas
- **Service**: Expose application within cluster
- **Ingress**: Expose application externally (optional)
- **HorizontalPodAutoscaler**: Automatic scaling
- **PodDisruptionBudget**: Availability guarantees
- **ConfigMap**: Non-sensitive configuration
- **Secret**: Sensitive data
- **ServiceAccount**: Pod identity with Workload Identity
- **Role/RoleBinding**: RBAC permissions
- **NetworkPolicy**: Network segmentation
- **ServiceMonitor**: Prometheus scraping (optional)

**Repository Locations:**
- `10-enterprise-app/`: Complete enterprise template
- `10-enterprise-app/templates/`: Kubernetes resource templates
- `10-enterprise-app/values.yaml`: Default values
- `10-enterprise-app/values-dev.yaml`: Development overrides
- `10-enterprise-app/values-staging.yaml`: Staging overrides
- `10-enterprise-app/values-production.yaml`: Production overrides

**Key Configuration:**
```yaml
# Production values
replicaCount: 5
resources:
  limits:
    cpu: 1000m
    memory: 1Gi
  requests:
    cpu: 500m
    memory: 512Mi
autoscaling:
  enabled: true
  minReplicas: 5
  maxReplicas: 20
podDisruptionBudget:
  enabled: true
  minAvailable: 3
```

**Where Costs Accrue:**
- **GKE Cluster**: Already running (shared cost)
- **Application Pods**: Based on resource requests
  - 5 replicas × 500m CPU × $0.031/vCPU/hour = ~$0.078/hour = ~$57/month
  - 5 replicas × 512Mi RAM × $0.0035/GB/hour = ~$0.009/hour = ~$7/month
  - **Total: ~$64/month per application**
- **Load Balancer**: $0.025/hour = ~$18/month (if using LoadBalancer service)
- **Ingress**: Included with GKE

**Cost Example (Production Setup):**
- Application pods (5 replicas): ~$64/month
- Load Balancer (optional): ~$18/month
- **Total: ~$82/month per application**

## How

### Quickstart: Deploy to Development

```bash
# 1. Clone the template
cp -r 10-enterprise-app my-app

# 2. Customize Chart.yaml
cat > my-app/Chart.yaml <<EOF
apiVersion: v2
name: my-app
description: My Application
type: application
version: 1.0.0
appVersion: "1.0.0"
EOF

# 3. Customize values-dev.yaml
cat > my-app/values-dev.yaml <<EOF
replicaCount: 1

image:
  repository: gcr.io/my-project/my-app
  tag: "latest"
  pullPolicy: Always

resources:
  limits:
    cpu: 200m
    memory: 256Mi
  requests:
    cpu: 100m
    memory: 128Mi

autoscaling:
  enabled: false

podDisruptionBudget:
  enabled: false

ingress:
  enabled: false

env:
  - name: APP_ENV
    value: "development"
  - name: LOG_LEVEL
    value: "debug"
EOF

# 4. Deploy to dev
helm install my-app ./my-app \
  -f ./my-app/values-dev.yaml \
  --namespace dev \
  --create-namespace \
  --wait

# 5. Verify deployment
kubectl get all -n dev
kubectl get pods -n dev
kubectl logs -n dev -l app=my-app --tail=50
```

### Quickstart: Deploy to Production

```bash
# 1. Customize values-production.yaml
cat > my-app/values-production.yaml <<EOF
replicaCount: 5

image:
  repository: gcr.io/my-project/my-app
  tag: "1.0.0"  # Specific version, not latest!
  pullPolicy: IfNotPresent

resources:
  limits:
    cpu: 1000m
    memory: 1Gi
  requests:
    cpu: 500m
    memory: 512Mi

autoscaling:
  enabled: true
  minReplicas: 5
  maxReplicas: 20
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80

podDisruptionBudget:
  enabled: true
  minAvailable: 3

ingress:
  enabled: true
  className: "gce"
  hosts:
    - host: my-app.example.com
      paths:
        - path: /
          pathType: Prefix

serviceAccount:
  create: true
  annotations:
    iam.gke.io/gcp-service-account: my-app@my-project.iam.gserviceaccount.com

networkPolicy:
  enabled: true

env:
  - name: APP_ENV
    value: "production"
  - name: LOG_LEVEL
    value: "info"
EOF

# 2. Deploy to production
helm install my-app ./my-app \
  -f ./my-app/values-production.yaml \
  --namespace production \
  --create-namespace \
  --wait \
  --timeout 10m

# 3. Verify deployment
kubectl get all -n production
kubectl get hpa -n production
kubectl get pdb -n production
kubectl get networkpolicy -n production

# 4. Check pod status
kubectl get pods -n production -l app=my-app
kubectl describe pods -n production -l app=my-app

# 5. Check logs
kubectl logs -n production -l app=my-app --tail=100
```

### Quickstart: Upgrade Application

```bash
# 1. Update image tag in values
# Edit values-production.yaml: image.tag: "1.1.0"

# 2. Upgrade with Helm
helm upgrade my-app ./my-app \
  -f ./my-app/values-production.yaml \
  --namespace production \
  --wait

# 3. Watch rollout
kubectl rollout status deployment/my-app -n production

# 4. Verify new version
kubectl get pods -n production -l app=my-app -o jsonpath='{.items[0].spec.containers[0].image}'
```

### Verify

```bash
# Check all resources
kubectl get all -n production

# Check Deployment
kubectl get deployment my-app -n production
kubectl describe deployment my-app -n production

# Check HPA
kubectl get hpa -n production
kubectl describe hpa my-app-hpa -n production

# Check PDB
kubectl get pdb -n production
kubectl describe pdb my-app-pdb -n production

# Check Network Policy
kubectl get networkpolicy -n production
kubectl describe networkpolicy my-app-netpol -n production

# Check Service Account
kubectl get sa my-app -n production -o yaml | grep iam.gke.io

# Test health endpoints
kubectl port-forward -n production svc/my-app 8080:80
curl http://localhost:8080/healthz
curl http://localhost:8080/ready
curl http://localhost:8080/metrics

# Check logs
kubectl logs -n production -l app=my-app --tail=100

# Check resource usage
kubectl top pods -n production -l app=my-app
```

### Cleanup

```bash
# Uninstall from dev
helm uninstall my-app -n dev
kubectl delete namespace dev

# Uninstall from production
helm uninstall my-app -n production
kubectl delete namespace production

# Verify cleanup
kubectl get all -n dev
kubectl get all -n production
```

## Overview

This is a production-ready Helm chart that combines:
- All platform patterns (probes, HPA, PDB, affinity)
- Configuration management (ConfigMaps, Secrets, Secret Manager CSI)
- Observability (metrics, logging, tracing)
- Security (RBAC, NetworkPolicy, Pod Security)
- Multi-environment support (dev, staging, production)

## Features

### High Availability
- Multiple replicas with anti-affinity
- Pod Disruption Budget
- Horizontal Pod Autoscaler
- Health probes (liveness, readiness, startup)

### Security
- Non-root containers
- Read-only root filesystem
- Drop all capabilities
- Network policies
- RBAC with least privilege
- Workload Identity for GCP access

### Observability
- Prometheus metrics endpoint
- Structured JSON logging
- Health check endpoints
- Resource monitoring

### Configuration
- Environment-specific values files
- ConfigMaps for configuration
- Secrets for sensitive data
- Secret Manager CSI for GCP secrets

### Deployment
- Rolling updates with zero downtime
- Automatic rollback on failure
- Blue-green deployment support
- Canary deployment support

## Chart Structure

```
enterprise-app/
├── Chart.yaml
├── values.yaml              # Default values
├── values-dev.yaml          # Development overrides
├── values-staging.yaml      # Staging overrides
├── values-production.yaml   # Production overrides
├── values.schema.json       # Values validation
├── charts/                  # Dependencies
├── templates/
│   ├── NOTES.txt
│   ├── _helpers.tpl
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   ├── hpa.yaml
│   ├── pdb.yaml
│   ├── configmap.yaml
│   ├── secret.yaml
│   ├── serviceaccount.yaml
│   ├── rbac.yaml
│   ├── networkpolicy.yaml
│   └── tests/
│       └── test-connection.yaml
└── README.md
```

## Quick Start

### Install for Development

```bash
helm install my-app ./enterprise-app \
  -f ./enterprise-app/values-dev.yaml \
  --namespace dev \
  --create-namespace
```

### Install for Production

```bash
helm install my-app ./enterprise-app \
  -f ./enterprise-app/values-production.yaml \
  --namespace production \
  --create-namespace
```

### Upgrade

```bash
helm upgrade my-app ./enterprise-app \
  -f ./enterprise-app/values-production.yaml \
  --namespace production
```

### Rollback

```bash
helm rollback my-app 1 --namespace production
```

## Configuration

### Common Values

```yaml
# values.yaml
replicaCount: 3

image:
  repository: gcr.io/my-project/my-app
  tag: "1.0.0"
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 80
  targetPort: 8080

ingress:
  enabled: false
  className: "gce"
  annotations:
    kubernetes.io/ingress.class: "gce"
    networking.gke.io/managed-certificates: "my-app-cert"
  hosts:
    - host: my-app.example.com
      paths:
        - path: /
          pathType: Prefix

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80

podDisruptionBudget:
  enabled: true
  minAvailable: 2

serviceAccount:
  create: true
  annotations:
    iam.gke.io/gcp-service-account: my-app@my-project.iam.gserviceaccount.com

securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 1000
  seccompProfile:
    type: RuntimeDefault

containerSecurityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop:
    - ALL

probes:
  liveness:
    enabled: true
    path: /healthz
    initialDelaySeconds: 30
    periodSeconds: 10
  readiness:
    enabled: true
    path: /ready
    initialDelaySeconds: 5
    periodSeconds: 5
  startup:
    enabled: true
    path: /startup
    failureThreshold: 30
    periodSeconds: 10

affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        labelSelector:
          matchLabels:
            app: my-app
        topologyKey: kubernetes.io/hostname

networkPolicy:
  enabled: true
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 5432  # PostgreSQL
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 443  # HTTPS

env:
  - name: APP_ENV
    value: "production"
  - name: LOG_LEVEL
    value: "info"
  - name: DB_HOST
    valueFrom:
      configMapKeyRef:
        name: my-app-config
        key: db_host
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: my-app-secret
        key: db_password

configMap:
  data:
    db_host: "postgresql.default.svc.cluster.local"
    db_port: "5432"
    db_name: "mydb"
    redis_host: "redis.default.svc.cluster.local"
    redis_port: "6379"

secret:
  data:
    db_password: "changeme"  # Base64 encoded in actual deployment
    api_key: "changeme"

monitoring:
  enabled: true
  port: 9090
  path: /metrics

logging:
  format: json
  level: info
```

### Environment-Specific Values

**Development (values-dev.yaml)**
```yaml
replicaCount: 1

image:
  tag: "latest"

resources:
  limits:
    cpu: 200m
    memory: 256Mi
  requests:
    cpu: 100m
    memory: 128Mi

autoscaling:
  enabled: false

podDisruptionBudget:
  enabled: false

ingress:
  enabled: false

env:
  - name: APP_ENV
    value: "development"
  - name: LOG_LEVEL
    value: "debug"
```

**Production (values-production.yaml)**
```yaml
replicaCount: 5

image:
  tag: "1.0.0"  # Specific version

resources:
  limits:
    cpu: 1000m
    memory: 1Gi
  requests:
    cpu: 500m
    memory: 512Mi

autoscaling:
  enabled: true
  minReplicas: 5
  maxReplicas: 20

podDisruptionBudget:
  enabled: true
  minAvailable: 3

ingress:
  enabled: true
  hosts:
    - host: my-app.example.com
      paths:
        - path: /
          pathType: Prefix

env:
  - name: APP_ENV
    value: "production"
  - name: LOG_LEVEL
    value: "info"
```

## Application Requirements

Your application should implement:

### Health Check Endpoints

```python
# Flask example
from flask import Flask, jsonify

app = Flask(__name__)

@app.route('/healthz')
def health():
    """Liveness probe - is the app alive?"""
    return jsonify({'status': 'healthy'}), 200

@app.route('/ready')
def ready():
    """Readiness probe - is the app ready to serve traffic?"""
    # Check database connection, dependencies, etc.
    try:
        # Check DB connection
        db.ping()
        return jsonify({'status': 'ready'}), 200
    except Exception as e:
        return jsonify({'status': 'not ready', 'error': str(e)}), 503

@app.route('/startup')
def startup():
    """Startup probe - has the app finished starting?"""
    # Check if initialization is complete
    if app_initialized:
        return jsonify({'status': 'started'}), 200
    else:
        return jsonify({'status': 'starting'}), 503
```

### Metrics Endpoint

```python
from prometheus_client import Counter, Histogram, generate_latest

# Define metrics
request_count = Counter('http_requests_total', 'Total HTTP requests')
request_duration = Histogram('http_request_duration_seconds', 'HTTP request duration')

@app.route('/metrics')
def metrics():
    """Prometheus metrics endpoint"""
    return generate_latest()
```

### Structured Logging

```python
import logging
import json
from datetime import datetime

def log_structured(message, severity='INFO', **kwargs):
    """Log in structured format for GCP Cloud Logging"""
    log_entry = {
        'severity': severity,
        'message': message,
        'timestamp': datetime.utcnow().isoformat(),
        **kwargs
    }
    print(json.dumps(log_entry))

log_structured('Application started', version='1.0.0')
```

### Graceful Shutdown

```python
import signal
import sys

def signal_handler(sig, frame):
    """Handle shutdown signals gracefully"""
    log_structured('Shutting down gracefully', severity='INFO')
    # Close database connections
    db.close()
    # Stop accepting new requests
    server.stop()
    sys.exit(0)

signal.signal(signal.SIGTERM, signal_handler)
signal.signal(signal.SIGINT, signal_handler)
```

## Deployment Workflow

### 1. Build and Push Image

```bash
# Build image
docker build -t gcr.io/my-project/my-app:1.0.0 .

# Push to registry
docker push gcr.io/my-project/my-app:1.0.0
```

### 2. Test Locally

```bash
# Render templates
helm template my-app ./enterprise-app \
  -f ./enterprise-app/values-dev.yaml

# Lint chart
helm lint ./enterprise-app

# Validate values
helm lint ./enterprise-app -f ./enterprise-app/values-production.yaml
```

### 3. Deploy to Development

```bash
helm upgrade --install my-app ./enterprise-app \
  -f ./enterprise-app/values-dev.yaml \
  --namespace dev \
  --create-namespace \
  --wait
```

### 4. Deploy to Staging

```bash
helm upgrade --install my-app ./enterprise-app \
  -f ./enterprise-app/values-staging.yaml \
  --namespace staging \
  --create-namespace \
  --wait
```

### 5. Deploy to Production

```bash
# Deploy with specific version
helm upgrade --install my-app ./enterprise-app \
  -f ./enterprise-app/values-production.yaml \
  --namespace production \
  --create-namespace \
  --wait \
  --timeout 10m

# Verify deployment
kubectl get pods -n production
kubectl get hpa -n production
kubectl get pdb -n production
```

### 6. Monitor Deployment

```bash
# Watch rollout
kubectl rollout status deployment/my-app -n production

# Check pod status
kubectl get pods -n production -l app=my-app

# Check logs
kubectl logs -n production -l app=my-app --tail=100 -f

# Check metrics
kubectl top pods -n production -l app=my-app
```

### 7. Rollback if Needed

```bash
# Check history
helm history my-app -n production

# Rollback to previous version
helm rollback my-app -n production

# Rollback to specific revision
helm rollback my-app 3 -n production
```

## Testing

### Helm Tests

```bash
# Run tests
helm test my-app -n production

# View test logs
kubectl logs -n production my-app-test-connection
```

### Manual Testing

```bash
# Port forward to service
kubectl port-forward -n production svc/my-app 8080:80

# Test health endpoints
curl http://localhost:8080/healthz
curl http://localhost:8080/ready
curl http://localhost:8080/metrics

# Test application
curl http://localhost:8080/api/v1/users
```

## Monitoring

### Check HPA

```bash
kubectl get hpa -n production
kubectl describe hpa my-app-hpa -n production
```

### Check PDB

```bash
kubectl get pdb -n production
kubectl describe pdb my-app-pdb -n production
```

### Check Resource Usage

```bash
kubectl top pods -n production -l app=my-app
kubectl top nodes
```

### Check Logs

```bash
# Recent logs
kubectl logs -n production -l app=my-app --tail=100

# Follow logs
kubectl logs -n production -l app=my-app -f

# Logs from specific pod
kubectl logs -n production POD_NAME
```

## Troubleshooting

### Pods Not Starting

```bash
# Check pod status
kubectl get pods -n production
kubectl describe pod POD_NAME -n production

# Common issues:
# - Image pull errors
# - Resource constraints
# - Failed probes
```

### HPA Not Scaling

```bash
# Check HPA status
kubectl get hpa -n production
kubectl describe hpa my-app-hpa -n production

# Check metrics
kubectl top pods -n production
```

### Network Issues

```bash
# Check network policy
kubectl get networkpolicy -n production
kubectl describe networkpolicy my-app-netpol -n production

# Test connectivity
kubectl run -it --rm debug --image=busybox --restart=Never -n production -- sh
```

## Best Practices

1. **Always use specific image tags** (not `latest`)
2. **Set resource requests and limits**
3. **Enable HPA for variable workloads**
4. **Use PDB for high availability**
5. **Configure all three probes**
6. **Use anti-affinity for pod spreading**
7. **Enable network policies**
8. **Use RBAC with least privilege**
9. **Implement structured logging**
10. **Monitor metrics and logs**

## Next Steps

- Customize for your application
- Add application-specific configuration
- Set up CI/CD pipeline (see [09-cicd](../09-cicd))
- Configure monitoring and alerting (see [07-observability](../07-observability))
- Implement security policies (see [08-security](../08-security))

## Resources

- [Helm Best Practices](https://helm.sh/docs/chart_best_practices/)
- [Kubernetes Production Best Practices](https://kubernetes.io/docs/setup/best-practices/)
- [GKE Best Practices](https://cloud.google.com/kubernetes-engine/docs/best-practices)
