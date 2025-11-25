# Networking - Services and Ingress on GKE

## What

Kubernetes networking solutions for exposing applications on GKE, including Services (ClusterIP, NodePort, LoadBalancer), Ingress with Google Cloud Load Balancer, and Gateway API. This enables external access to your applications with SSL/TLS termination, load balancing, and traffic routing.

**Resources Created:**
- Service (ClusterIP, NodePort, LoadBalancer)
- Ingress (with GCE Load Balancer)
- BackendConfig (GCP-specific backend configuration)
- ManagedCertificate (automatic SSL/TLS certificates)
- FrontendConfig (GCP-specific frontend configuration)
- NetworkPolicy (traffic filtering)

## Why

**Why This Matters:**
- **External Access**: Expose applications to the internet or internal networks
- **Load Balancing**: Distribute traffic across multiple pods for high availability
- **SSL/TLS**: Secure connections with automatic certificate management
- **Traffic Routing**: Route requests based on hostname, path, headers
- **Cost Efficiency**: Share one load balancer across multiple services
- **Enterprise Features**: Cloud Armor (DDoS protection), Cloud CDN, IAP (Identity-Aware Proxy)

**Trade-offs:**
- **Cost**: Load Balancers cost money ($18-25/month each)
- **Complexity**: Ingress is more complex than simple LoadBalancer Services
- **Latency**: External load balancers add network hops
- **Vendor Lock-in**: GCE Ingress is GCP-specific

**Alternatives:**
- **ClusterIP + kubectl port-forward**: Free, for development only
- **NodePort**: Exposes on node IPs, limited port range (30000-32767)
- **LoadBalancer Service**: Simple but costs $18-25/month per service
- **Ingress**: Share one load balancer across multiple services (cost-efficient)
- **Gateway API**: Next-generation routing (more flexible than Ingress)
- **Service Mesh (Istio, Linkerd)**: Advanced traffic management

## When

**Use Services When:**
- **ClusterIP**: Internal communication between pods (default, free)
- **NodePort**: Testing external access without load balancer
- **LoadBalancer**: Need simple external access for one service (costs money)

**Use Ingress When:**
- Exposing multiple HTTP/HTTPS services
- Need SSL/TLS termination
- Need path-based or host-based routing
- Want to share one load balancer across services (cost savings)
- Need Cloud Armor, Cloud CDN, or IAP integration

**Prerequisites:**
- GKE cluster created (00-prereqs completed)
- Application deployed with Service (ClusterIP)
- Domain name (for SSL certificates)
- Understanding of DNS configuration

**When NOT to Use:**
- **Development**: Use `kubectl port-forward` (free)
- **Non-HTTP protocols**: Use LoadBalancer Service or NodePort
- **Internal-only apps**: Use ClusterIP
- **Cost-sensitive**: Ingress costs $18-25/month for load balancer

**Sequencing:**
1. Complete 00-prereqs (GKE cluster setup)
2. Deploy application with ClusterIP Service
3. (Optional) Create ManagedCertificate for SSL
4. Create Ingress resource
5. Configure DNS to point to load balancer IP
6. Verify traffic routing

## Where

**GCP Services:**
- **Cloud Load Balancing**: HTTP(S) Load Balancer for Ingress
- **Cloud DNS**: Domain name resolution (optional)
- **Certificate Manager**: Automatic SSL/TLS certificates
- **Cloud Armor**: DDoS protection and WAF (optional)
- **Cloud CDN**: Content delivery network (optional)
- **Identity-Aware Proxy (IAP)**: Authentication (optional)

**IAM Roles Required:**
- `roles/compute.loadBalancerAdmin`: Create and manage load balancers
- `roles/compute.securityAdmin`: Create firewall rules
- `roles/container.developer`: Deploy workloads
- Typically granted to GKE service account automatically

**Kubernetes Resources:**
- **Namespace**: Any namespace (default, production, etc.)
- **Resources Created**:
  - Service (namespace-scoped)
  - Ingress (namespace-scoped)
  - BackendConfig (namespace-scoped, GCP-specific)
  - ManagedCertificate (namespace-scoped, GCP-specific)
  - NetworkPolicy (namespace-scoped)

**Repository Locations:**
- `05-networking/services/`: Service examples (ClusterIP, NodePort, LoadBalancer)
- `05-networking/ingress-gce/`: GCE Ingress with SSL and routing
- `05-networking/network-policies/`: NetworkPolicy examples

**Key Values to Set:**
```yaml
# Service
type: ClusterIP  # or NodePort, LoadBalancer
port: 80
targetPort: 8080

# Ingress
ingressClassName: gce  # GKE default
rules:
  - host: example.com
    http:
      paths:
        - path: /
          pathType: Prefix
          backend:
            service:
              name: my-app
              port:
                number: 80

# ManagedCertificate
domains:
  - example.com
  - www.example.com

# BackendConfig
healthCheck:
  checkIntervalSec: 10
  timeoutSec: 5
connectionDraining:
  drainingTimeoutSec: 60
```

**Where Costs Accrue:**
- **Load Balancer**: $18-25/month per Ingress (includes 5 forwarding rules)
- **Additional Forwarding Rules**: $0.025/hour each (~$18/month)
- **Data Processing**: $0.008-0.016/GB (first 10 TB)
- **Cloud Armor**: $0.75/policy/month + $0.50/million requests
- **Cloud CDN**: $0.02-0.20/GB egress
- **Static IP**: $0.01/hour if reserved but unused (~$7/month)

**Free Tier:**
- ClusterIP Services: Free
- NodePort Services: Free
- Load Balancers: NOT free ($18-25/month)

**Cost Example:**
- 1 Ingress with SSL: ~$18-25/month
- 100 GB data transfer: ~$0.80-1.60
- Cloud Armor: ~$0.75/month + usage

## How

### Quickstart: ClusterIP Service (Internal)

```bash
# Set environment variables
export NAMESPACE=default

# Create Deployment
kubectl create deployment my-app --image=nginx:1.21 -n $NAMESPACE

# Create ClusterIP Service (internal only)
kubectl expose deployment my-app --port=80 --target-port=80 -n $NAMESPACE

# Verify
kubectl get svc my-app -n $NAMESPACE

# Test from within cluster
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -n $NAMESPACE -- curl http://my-app
```

### Quickstart: LoadBalancer Service (External)

```bash
# Create LoadBalancer Service (costs $18-25/month)
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: my-app-lb
  namespace: $NAMESPACE
spec:
  type: LoadBalancer
  selector:
    app: my-app
  ports:
    - port: 80
      targetPort: 80
EOF

# Get external IP (takes 1-2 minutes)
kubectl get svc my-app-lb -n $NAMESPACE -w

# Test
curl http://EXTERNAL_IP
```

### Quickstart: Ingress with SSL

```bash
# Prerequisites: Domain name pointing to load balancer IP

# 1. Create ClusterIP Service
kubectl expose deployment my-app --port=80 --target-port=80 -n $NAMESPACE

# 2. Create ManagedCertificate
cat <<EOF | kubectl apply -f -
apiVersion: networking.gke.io/v1
kind: ManagedCertificate
metadata:
  name: my-app-cert
  namespace: $NAMESPACE
spec:
  domains:
    - example.com
    - www.example.com
EOF

# 3. Create Ingress
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app-ingress
  namespace: $NAMESPACE
  annotations:
    kubernetes.io/ingress.class: "gce"
    networking.gke.io/managed-certificates: "my-app-cert"
    kubernetes.io/ingress.global-static-ip-name: "my-app-ip"  # Optional: reserve static IP first
spec:
  rules:
    - host: example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-app
                port:
                  number: 80
    - host: www.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-app
                port:
                  number: 80
EOF

# 4. Get load balancer IP
kubectl get ingress my-app-ingress -n $NAMESPACE
# Note the ADDRESS

# 5. Configure DNS
# Create A records:
# example.com -> LOAD_BALANCER_IP
# www.example.com -> LOAD_BALANCER_IP

# 6. Wait for certificate provisioning (10-20 minutes)
kubectl describe managedcertificate my-app-cert -n $NAMESPACE
# Wait for Status: Active
```

### Verify

```bash
# Check Service
kubectl get svc -n $NAMESPACE
kubectl describe svc my-app -n $NAMESPACE

# Check Ingress
kubectl get ingress -n $NAMESPACE
kubectl describe ingress my-app-ingress -n $NAMESPACE

# Check ManagedCertificate
kubectl get managedcertificate -n $NAMESPACE
kubectl describe managedcertificate my-app-cert -n $NAMESPACE
# Status should be "Active"

# Check backend health
kubectl get backendconfig -n $NAMESPACE
kubectl describe backendconfig -n $NAMESPACE

# Test HTTP
curl http://example.com

# Test HTTPS (after certificate is active)
curl https://example.com

# Check load balancer in GCP Console
gcloud compute forwarding-rules list
gcloud compute backend-services list
gcloud compute health-checks list
```

### Cleanup

```bash
# Delete Ingress (this deletes the load balancer)
kubectl delete ingress my-app-ingress -n $NAMESPACE

# Delete ManagedCertificate
kubectl delete managedcertificate my-app-cert -n $NAMESPACE

# Delete Service
kubectl delete svc my-app -n $NAMESPACE

# Delete static IP (if created)
gcloud compute addresses delete my-app-ip --global

# Verify load balancer is deleted
gcloud compute forwarding-rules list
gcloud compute backend-services list

# Note: It may take a few minutes for all resources to be deleted
```

## Service Types

### ClusterIP (Default)

**Use Case**: Internal communication between pods

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-app
spec:
  type: ClusterIP
  selector:
    app: my-app
  ports:
    - port: 80
      targetPort: 8080
```

**Access**: Only from within cluster
**Cost**: Free
**DNS**: `my-app.default.svc.cluster.local`

### NodePort

**Use Case**: Testing external access without load balancer

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-app-nodeport
spec:
  type: NodePort
  selector:
    app: my-app
  ports:
    - port: 80
      targetPort: 8080
      nodePort: 30080  # Optional: 30000-32767
```

**Access**: `http://NODE_IP:30080`
**Cost**: Free
**Limitations**: Limited port range, not production-ready

### LoadBalancer

**Use Case**: Simple external access for one service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-app-lb
spec:
  type: LoadBalancer
  selector:
    app: my-app
  ports:
    - port: 80
      targetPort: 8080
```

**Access**: External IP assigned automatically
**Cost**: $18-25/month per service
**Use When**: Single service needs external access

## Ingress

### Basic Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app-ingress
  annotations:
    kubernetes.io/ingress.class: "gce"
spec:
  rules:
    - host: example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-app
                port:
                  number: 80
```

### Path-Based Routing

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: multi-path-ingress
spec:
  rules:
    - host: example.com
      http:
        paths:
          - path: /api
            pathType: Prefix
            backend:
              service:
                name: api-service
                port:
                  number: 80
          - path: /web
            pathType: Prefix
            backend:
              service:
                name: web-service
                port:
                  number: 80
```

### Host-Based Routing

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: multi-host-ingress
spec:
  rules:
    - host: api.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: api-service
                port:
                  number: 80
    - host: web.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: web-service
                port:
                  number: 80
```

## SSL/TLS Certificates

### Google-Managed Certificates

```yaml
apiVersion: networking.gke.io/v1
kind: ManagedCertificate
metadata:
  name: my-cert
spec:
  domains:
    - example.com
    - www.example.com
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-ingress
  annotations:
    networking.gke.io/managed-certificates: "my-cert"
spec:
  rules:
    - host: example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-app
                port:
                  number: 80
```

**Provisioning Time**: 10-20 minutes
**Renewal**: Automatic
**Cost**: Free

### Self-Managed Certificates (cert-manager)

```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Create ClusterIssuer (Let's Encrypt)
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
      - http01:
          ingress:
            class: gce
EOF

# Create Ingress with cert-manager
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-ingress
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  tls:
    - hosts:
        - example.com
      secretName: my-app-tls
  rules:
    - host: example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-app
                port:
                  number: 80
```

## BackendConfig (GCP-Specific)

Configure backend behavior:

```yaml
apiVersion: cloud.google.com/v1
kind: BackendConfig
metadata:
  name: my-backend-config
spec:
  # Health check configuration
  healthCheck:
    checkIntervalSec: 10
    timeoutSec: 5
    healthyThreshold: 2
    unhealthyThreshold: 3
    type: HTTP
    requestPath: /healthz
    port: 8080
  
  # Connection draining
  connectionDraining:
    drainingTimeoutSec: 60
  
  # Session affinity
  sessionAffinity:
    affinityType: "CLIENT_IP"
    affinityCookieTtlSec: 3600
  
  # Timeout
  timeoutSec: 30
  
  # Cloud CDN
  cdn:
    enabled: true
    cachePolicy:
      includeHost: true
      includeProtocol: true
      includeQueryString: false
  
  # Cloud Armor
  securityPolicy:
    name: "my-security-policy"
  
  # IAP
  iap:
    enabled: true
    oauthclientCredentials:
      secretName: oauth-client-secret
---
apiVersion: v1
kind: Service
metadata:
  name: my-app
  annotations:
    cloud.google.com/backend-config: '{"default": "my-backend-config"}'
spec:
  type: ClusterIP
  selector:
    app: my-app
  ports:
    - port: 80
      targetPort: 8080
```

## Network Policies

Control traffic between pods:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-ingress
spec:
  podSelector:
    matchLabels:
      app: my-app
  policyTypes:
    - Ingress
  ingress:
    # Allow from Ingress controller
    - from:
        - namespaceSelector:
            matchLabels:
              name: kube-system
    # Allow from specific pods
    - from:
        - podSelector:
            matchLabels:
              app: frontend
      ports:
        - protocol: TCP
          port: 8080
```

## Best Practices

### 1. Use ClusterIP for Internal Services

```yaml
# Internal services don't need external access
type: ClusterIP  # Free, secure
```

### 2. Share One Ingress Across Services

```yaml
# Not this (multiple LoadBalancers)
# Service 1: type: LoadBalancer  # $18/month
# Service 2: type: LoadBalancer  # $18/month
# Total: $36/month

# This (one Ingress)
# Ingress with multiple backends  # $18/month
# Total: $18/month
```

### 3. Use ManagedCertificate for SSL

```yaml
# Free, automatic renewal
kind: ManagedCertificate
```

### 4. Configure Health Checks

```yaml
apiVersion: cloud.google.com/v1
kind: BackendConfig
metadata:
  name: health-check-config
spec:
  healthCheck:
    checkIntervalSec: 10
    timeoutSec: 5
    healthyThreshold: 2
    unhealthyThreshold: 3
    requestPath: /healthz
```

### 5. Enable Connection Draining

```yaml
spec:
  connectionDraining:
    drainingTimeoutSec: 60  # Graceful shutdown
```

### 6. Use Static IP for Production

```bash
# Reserve static IP
gcloud compute addresses create my-app-ip --global

# Use in Ingress
annotations:
  kubernetes.io/ingress.global-static-ip-name: "my-app-ip"
```

### 7. Implement Network Policies

```yaml
# Deny all by default, allow specific traffic
kind: NetworkPolicy
policyTypes:
  - Ingress
  - Egress
```

## Cost Optimization

### 1. Use Ingress Instead of Multiple LoadBalancers

```yaml
# One Ingress for multiple services
# Saves $18/month per additional service
```

### 2. Disable Ingress in Development

```yaml
# values.yaml
ingress:
  enabled: false  # Use kubectl port-forward instead
```

### 3. Delete Unused Load Balancers

```bash
# Check for orphaned load balancers
gcloud compute forwarding-rules list
gcloud compute backend-services list

# Delete Ingress to remove load balancer
kubectl delete ingress INGRESS_NAME
```

### 4. Use Cloud CDN for Static Content

```yaml
# Reduce egress costs
cdn:
  enabled: true
```

### 5. Monitor Data Transfer

```bash
# Check data transfer costs in GCP Console
# Billing > Reports > Filter by "Network"
```

## GKE Autopilot Considerations

### Supported

- All Service types (ClusterIP, NodePort, LoadBalancer)
- GCE Ingress
- ManagedCertificate
- BackendConfig
- Network Policies

### Restrictions

- No custom Ingress controllers (nginx, traefik)
- No hostNetwork pods
- No hostPort

## Troubleshooting

### Ingress Not Getting IP

```bash
# Check Ingress events
kubectl describe ingress INGRESS_NAME

# Common issues:
# - Service not found
# - Backend unhealthy
# - Certificate provisioning failed
```

### Certificate Not Provisioning

```bash
# Check ManagedCertificate status
kubectl describe managedcertificate CERT_NAME

# Common issues:
# - DNS not pointing to load balancer IP
# - Domain validation failed
# - Wait 10-20 minutes for provisioning
```

### Backend Unhealthy

```bash
# Check backend health
kubectl describe ingress INGRESS_NAME

# Common issues:
# - Health check path returns non-200
# - Pod not ready
# - Service selector mismatch
```

### 502/503 Errors

```bash
# Check pod logs
kubectl logs -l app=my-app

# Check Service endpoints
kubectl get endpoints my-app

# Check BackendConfig
kubectl describe backendconfig BACKEND_CONFIG_NAME

# Common issues:
# - No healthy backends
# - Timeout too short
# - Connection refused
```

## Sections

### [services](./services)
Service examples for ClusterIP, NodePort, and LoadBalancer.

### [ingress-gce](./ingress-gce)
GCE Ingress with SSL, routing, and BackendConfig examples.

### [network-policies](./network-policies)
NetworkPolicy examples for traffic control.

## Next Steps

1. Explore [services](./services) for basic networking
2. Learn [ingress-gce](./ingress-gce) for external access with SSL
3. Implement [network-policies](./network-policies) for security
4. Check [08-security](../08-security) for additional security patterns

## Resources

- [Kubernetes Services](https://kubernetes.io/docs/concepts/services-networking/service/)
- [Kubernetes Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- [GKE Ingress](https://cloud.google.com/kubernetes-engine/docs/concepts/ingress)
- [GKE ManagedCertificate](https://cloud.google.com/kubernetes-engine/docs/how-to/managed-certs)
- [BackendConfig](https://cloud.google.com/kubernetes-engine/docs/how-to/ingress-features)
- [Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
