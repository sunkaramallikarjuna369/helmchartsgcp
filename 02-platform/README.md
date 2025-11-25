# Platform Patterns - Production-Ready Kubernetes

## What

Essential platform patterns for running production-grade applications on GKE, covering resource management (namespaces, quotas, limits), high availability (probes, HPA, PDB, priority classes), scheduling and placement (affinity, topology spread), and deployment strategies (rolling updates, rollback).

**Resources Created:**
- Namespace (logical isolation)
- ResourceQuota (limit resource consumption)
- LimitRange (default and max/min limits)
- HorizontalPodAutoscaler (automatic scaling)
- PodDisruptionBudget (availability during disruptions)
- PriorityClass (scheduling priority)
- Affinity/anti-affinity rules (pod placement)
- Topology spread constraints (even distribution)

## Why

**Why Platform Patterns Matter:**
- **High Availability**: Ensure applications survive node failures and disruptions
- **Resource Efficiency**: Optimize cluster resource usage and costs
- **Scalability**: Handle variable load automatically with HPA
- **Reliability**: Prevent cascading failures with proper limits and quotas
- **Production Readiness**: Meet enterprise SLAs and uptime requirements
- **Operational Excellence**: Reduce manual intervention and toil

**Why Learn These Patterns:**
- **Foundation**: Required for production deployments
- **Cost Control**: Prevent resource waste and runaway costs
- **Stability**: Avoid outages from resource exhaustion
- **Career**: Essential knowledge for platform engineers
- **Best Practices**: Industry-standard patterns used by all major companies

**Trade-offs:**
- **Complexity**: More configuration than simple deployments
- **Learning Curve**: Understanding probes, HPA, PDB, affinity requires time
- **Overhead**: Additional resources for multiple replicas and autoscaling
- **Debugging**: More moving parts can make troubleshooting harder

**Alternatives:**
- **Simple Deployments**: Single replica, no probes (only for dev/test)
- **Manual Scaling**: Scale replicas manually instead of HPA
- **Cluster Autoscaler**: Scale nodes instead of pods (complementary)

## When

**Use Platform Patterns When:**
- Deploying to production environments
- Need high availability (99.9%+ uptime)
- Handling variable traffic loads
- Running business-critical applications
- Managing multi-tenant clusters
- Need to enforce resource limits per team/environment

**Prerequisites:**
- Completed 00-prereqs (GKE cluster setup)
- Completed 01-helm-basics (understand Helm charts)
- Basic Kubernetes knowledge (pods, deployments, services)
- Understanding of resource requests and limits

**When to Use Each Pattern:**
- **Namespaces**: Always (organize resources by team/environment)
- **Resource Quotas**: Multi-tenant clusters, cost control
- **Limit Ranges**: Prevent resource hogging, set defaults
- **Probes**: Always in production (liveness, readiness, startup)
- **HPA**: Variable load, traffic spikes
- **PDB**: Always in production (ensure availability)
- **Priority Classes**: Critical vs non-critical workloads
- **Affinity/Anti-Affinity**: HA, co-location, or separation requirements
- **Topology Spread**: Multi-zone deployments, even distribution
- **Rolling Updates**: Always (zero-downtime deployments)

**When NOT to Use:**
- Development/test environments (can use simpler patterns)
- Single-replica applications (some patterns don't apply)
- Stateless batch jobs (different patterns needed)

**Learning Sequence:**
1. **namespaces-quotas-limits**: Resource management (20 minutes)
2. **probes-hpa-pdb-priority**: High availability (30 minutes)
3. **scheduling-affinity-spread**: Pod placement (25 minutes)
4. **rollout-strategies**: Safe deployments (15 minutes)
**Total Time**: ~1.5 hours

## Where

**GCP Services:**
- **GKE**: All patterns run on Kubernetes
- **Cloud Monitoring**: Metrics for HPA (CPU, memory)
- No additional GCP services required

**IAM Roles Required:**
- `roles/container.developer`: Deploy workloads
- No additional IAM roles needed

**Kubernetes Resources:**
- **Namespace**: Cluster-scoped (organize resources)
- **ResourceQuota**: Namespace-scoped (limit resources)
- **LimitRange**: Namespace-scoped (default limits)
- **HorizontalPodAutoscaler**: Namespace-scoped (autoscaling)
- **PodDisruptionBudget**: Namespace-scoped (availability)
- **PriorityClass**: Cluster-scoped (scheduling priority)
- **Deployment**: Namespace-scoped (with affinity, probes, strategy)

**Repository Locations:**
- `02-platform/namespaces-quotas-limits/`: Resource management examples
- `02-platform/probes-hpa-pdb-priority/`: HA patterns
- `02-platform/scheduling-affinity-spread/`: Pod placement examples
- `02-platform/rollout-strategies/`: Deployment strategy examples

**Key Values to Set:**
```yaml
# Resource requests and limits (REQUIRED in Autopilot)
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 200m
    memory: 256Mi

# Probes
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
readinessProbe:
  httpGet:
    path: /ready
    port: 8080

# HPA
minReplicas: 2
maxReplicas: 10
targetCPUUtilizationPercentage: 70

# PDB
minAvailable: 1  # or maxUnavailable: 1

# Anti-affinity
podAntiAffinity:
  preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        topologyKey: kubernetes.io/hostname
```

**Where Costs Accrue:**
- **Multiple Replicas**: More pods = more CPU/memory costs
- **HPA**: Scales up pods during high load
- **Resource Requests**: Autopilot charges based on requests
- **Over-provisioning**: Setting limits too high wastes money

**Cost Example:**
- 1 pod (250m CPU, 512Mi RAM): ~$0.03/hour = ~$22/month
- 3 pods (HA): ~$0.09/hour = ~$66/month
- HPA scaling to 10 pods: ~$0.30/hour = ~$220/month (during peak)

## How

### Quickstart: Production-Ready Deployment

```bash
# 1. Create namespace with quotas
kubectl create namespace production

kubectl apply -f - <<EOF
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-quota
  namespace: production
spec:
  hard:
    requests.cpu: "10"
    requests.memory: 20Gi
    limits.cpu: "20"
    limits.memory: 40Gi
    pods: "50"
EOF

# 2. Create deployment with all patterns
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  namespace: production
spec:
  replicas: 3
  selector:
    matchLabels:
      app: my-app
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: my-app
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchLabels:
                  app: my-app
              topologyKey: kubernetes.io/hostname
      containers:
      - name: app
        image: nginx:1.21
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
EOF

# 3. Create HPA
kubectl apply -f - <<EOF
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: my-app-hpa
  namespace: production
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-app
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
EOF

# 4. Create PDB
kubectl apply -f - <<EOF
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: my-app-pdb
  namespace: production
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: my-app
EOF
```

### Verify

```bash
# Check namespace and quotas
kubectl get namespace production
kubectl describe resourcequota compute-quota -n production

# Check deployment
kubectl get deployment my-app -n production
kubectl get pods -n production -l app=my-app

# Check pod distribution (should be on different nodes)
kubectl get pods -n production -l app=my-app -o wide

# Check HPA
kubectl get hpa my-app-hpa -n production
kubectl describe hpa my-app-hpa -n production

# Check PDB
kubectl get pdb my-app-pdb -n production
kubectl describe pdb my-app-pdb -n production

# Check probes
kubectl describe pod -n production -l app=my-app | grep -A 10 "Liveness\|Readiness"

# Test rolling update
kubectl set image deployment/my-app app=nginx:1.22 -n production
kubectl rollout status deployment/my-app -n production
```

### Cleanup

```bash
# Delete all resources
kubectl delete deployment my-app -n production
kubectl delete hpa my-app-hpa -n production
kubectl delete pdb my-app-pdb -n production

# Delete namespace (deletes everything in it)
kubectl delete namespace production

# Verify cleanup
kubectl get all -n production
# Should show: No resources found
```

## Overview

This section covers critical patterns for:
- Resource management (namespaces, quotas, limits)
- High availability (probes, HPA, PDB)
- Scheduling and placement (affinity, topology spread)
- Deployment strategies (rolling updates, blue-green)

## Sections

### [namespaces-quotas-limits](./namespaces-quotas-limits)
Organize resources with namespaces and enforce resource quotas and limits.

### [probes-hpa-pdb-priority](./probes-hpa-pdb-priority)
Configure health checks, autoscaling, disruption budgets, and priority classes.

### [scheduling-affinity-spread](./scheduling-affinity-spread)
Control pod placement with node affinity, pod affinity/anti-affinity, and topology spread.

### [rollout-strategies](./rollout-strategies)
Implement safe deployment strategies with rolling updates and rollback capabilities.

## Key Concepts

### Resource Management

**Namespaces**: Logical isolation for teams, environments, or applications
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    environment: production
```

**Resource Quotas**: Limit resource consumption per namespace
```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-quota
  namespace: production
spec:
  hard:
    requests.cpu: "10"
    requests.memory: 20Gi
    limits.cpu: "20"
    limits.memory: 40Gi
    pods: "50"
```

**Limit Ranges**: Set default and max/min limits for containers
```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: production
spec:
  limits:
  - default:
      cpu: 200m
      memory: 256Mi
    defaultRequest:
      cpu: 100m
      memory: 128Mi
    max:
      cpu: 2
      memory: 4Gi
    min:
      cpu: 50m
      memory: 64Mi
    type: Container
```

### High Availability

**Liveness Probe**: Restart unhealthy containers
```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3
```

**Readiness Probe**: Remove unhealthy pods from service
```yaml
readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 2
```

**Startup Probe**: Handle slow-starting containers
```yaml
startupProbe:
  httpGet:
    path: /startup
    port: 8080
  initialDelaySeconds: 0
  periodSeconds: 10
  timeoutSeconds: 3
  failureThreshold: 30  # 5 minutes max
```

**Horizontal Pod Autoscaler (HPA)**: Scale based on metrics
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: my-app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-app
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

**Pod Disruption Budget (PDB)**: Ensure availability during disruptions
```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: my-app-pdb
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: my-app
```

**Priority Class**: Control pod scheduling priority
```yaml
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: high-priority
value: 1000
globalDefault: false
description: "High priority for critical applications"
```

### Scheduling

**Node Affinity**: Schedule pods on specific nodes
```yaml
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
      - matchExpressions:
        - key: node.kubernetes.io/instance-type
          operator: In
          values:
          - n1-standard-2
          - n1-standard-4
```

**Pod Anti-Affinity**: Spread pods across nodes
```yaml
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        labelSelector:
          matchLabels:
            app: my-app
        topologyKey: kubernetes.io/hostname
```

**Topology Spread Constraints**: Even distribution
```yaml
topologySpreadConstraints:
- maxSkew: 1
  topologyKey: topology.kubernetes.io/zone
  whenUnsatisfiable: DoNotSchedule
  labelSelector:
    matchLabels:
      app: my-app
```

### Deployment Strategies

**Rolling Update**: Gradual replacement (default)
```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1        # Max pods above desired count
    maxUnavailable: 0  # Max pods unavailable during update
```

**Recreate**: Stop all, then start new
```yaml
strategy:
  type: Recreate
```

## Best Practices

### 1. Always Set Resource Requests and Limits

```yaml
resources:
  requests:
    cpu: 100m      # Guaranteed CPU
    memory: 128Mi  # Guaranteed memory
  limits:
    cpu: 200m      # Max CPU (throttled if exceeded)
    memory: 256Mi  # Max memory (OOMKilled if exceeded)
```

**Why?**
- Requests: Scheduler uses this for placement
- Limits: Prevents resource exhaustion
- GKE Autopilot requires both

### 2. Use Multiple Replicas

```yaml
replicas: 3  # Minimum for HA
```

**Why?**
- Survives node failures
- Enables rolling updates
- Better load distribution

### 3. Configure All Three Probes

```yaml
livenessProbe:   # Restart if unhealthy
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10

readinessProbe:  # Remove from service if not ready
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5

startupProbe:    # Allow slow startup
  httpGet:
    path: /startup
    port: 8080
  failureThreshold: 30
  periodSeconds: 10
```

### 4. Set Pod Disruption Budgets

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: my-app-pdb
spec:
  minAvailable: 2  # Or use maxUnavailable: 1
  selector:
    matchLabels:
      app: my-app
```

**Why?**
- Protects during node upgrades
- Ensures availability during maintenance
- Required for zero-downtime deployments

### 5. Use Anti-Affinity for HA

```yaml
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        labelSelector:
          matchLabels:
            app: my-app
        topologyKey: kubernetes.io/hostname
```

**Why?**
- Spreads pods across nodes
- Survives node failures
- Better fault tolerance

### 6. Configure HPA for Variable Load

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: my-app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-app
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

**Why?**
- Handles traffic spikes
- Reduces costs during low traffic
- Automatic scaling

### 7. Use Rolling Updates Safely

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1
    maxUnavailable: 0
```

**Why?**
- Zero downtime deployments
- Gradual rollout
- Easy rollback

## GKE Autopilot Considerations

### Resource Requirements

Autopilot enforces minimum resources:
```yaml
resources:
  requests:
    cpu: 250m      # Minimum
    memory: 512Mi  # Minimum
```

### Restrictions

- No privileged pods
- No hostPath volumes
- No hostNetwork/hostPID
- No DaemonSets (managed by Google)

### Benefits

- Automatic node management
- Built-in security
- Optimized resource allocation
- Pay only for pods

## Cost Optimization

### 1. Right-Size Resources

```yaml
# Start small
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 200m
    memory: 256Mi
```

Monitor and adjust based on actual usage.

### 2. Use HPA for Variable Workloads

```yaml
minReplicas: 1  # Scale down during low traffic
maxReplicas: 10
```

### 3. Set Appropriate Limits

```yaml
# Don't over-provision
limits:
  cpu: 200m      # Not 2000m if you only need 200m
  memory: 256Mi  # Not 2Gi if you only need 256Mi
```

### 4. Use Pod Disruption Budgets Wisely

```yaml
# Allow some disruption for cost savings
maxUnavailable: 1  # Instead of minAvailable: 10
```

## Troubleshooting

### Pods Not Scheduling

```bash
# Check pod status
kubectl get pods
kubectl describe pod POD_NAME

# Common issues:
# - Insufficient resources
# - Node affinity not satisfied
# - Taints not tolerated
```

### HPA Not Scaling

```bash
# Check HPA status
kubectl get hpa
kubectl describe hpa HPA_NAME

# Common issues:
# - Metrics server not installed (GKE has it by default)
# - No resource requests set
# - Target already at min/max
```

### Probes Failing

```bash
# Check pod events
kubectl describe pod POD_NAME

# Common issues:
# - initialDelaySeconds too short
# - Application not ready
# - Wrong port or path
```

## Next Steps

1. Explore [namespaces-quotas-limits](./namespaces-quotas-limits) for resource management
2. Configure [probes-hpa-pdb-priority](./probes-hpa-pdb-priority) for high availability
3. Learn [scheduling-affinity-spread](./scheduling-affinity-spread) for pod placement
4. Implement [rollout-strategies](./rollout-strategies) for safe deployments

## Resources

- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)
- [GKE Autopilot](https://cloud.google.com/kubernetes-engine/docs/concepts/autopilot-overview)
- [Resource Management](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
- [Pod Disruption Budgets](https://kubernetes.io/docs/concepts/workloads/pods/disruptions/)
