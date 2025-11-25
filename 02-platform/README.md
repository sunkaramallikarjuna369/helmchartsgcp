# Platform Patterns - Production-Ready Kubernetes

Learn essential platform patterns for running production-grade applications on GKE.

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
