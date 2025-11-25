# Security - Best Practices for GKE

## What

Comprehensive guide to securing applications and clusters on GKE, covering RBAC (Role-Based Access Control), Network Policies, Pod Security Standards, image scanning and signing, Workload Identity, and security best practices for production deployments.

**Resources Created:**
- ServiceAccount (pod identity)
- Role/ClusterRole (permissions)
- RoleBinding/ClusterRoleBinding (permission assignments)
- NetworkPolicy (network segmentation)
- Pod SecurityContext (container security)
- Binary Authorization policies (image verification)
- Workload Identity bindings (GCP service account access)

## Why

**Why Security Matters:**
- **Protect Data**: Prevent unauthorized access to sensitive data
- **Compliance**: Meet regulatory requirements (GDPR, HIPAA, SOC 2)
- **Prevent Breaches**: Reduce attack surface and blast radius
- **Trust**: Build customer confidence in your platform
- **Cost Avoidance**: Security incidents are expensive
- **Reputation**: Security breaches damage brand reputation

**Why Use RBAC:**
- **Least Privilege**: Grant only necessary permissions
- **Audit Trail**: Track who can do what
- **Separation of Duties**: Different roles for different teams
- **Fine-Grained Control**: Control access at resource level
- **Kubernetes Native**: Built into Kubernetes

**Why Use Network Policies:**
- **Defense in Depth**: Additional security layer beyond RBAC
- **Microsegmentation**: Isolate workloads from each other
- **Zero Trust**: Deny all by default, allow explicitly
- **Compliance**: Required for many security frameworks
- **Limit Blast Radius**: Contain compromised workloads

**Why Use Workload Identity:**
- **No Service Account Keys**: Eliminates key management and rotation
- **Automatic Credential Rotation**: Google manages credentials
- **Fine-Grained IAM**: Use GCP IAM for access control
- **Audit Logging**: Track GCP resource access
- **Best Practice**: Google-recommended authentication method

**Trade-offs:**
- **Complexity**: Security adds configuration overhead
- **Learning Curve**: Understanding RBAC, Network Policies, Pod Security
- **Debugging**: Security restrictions can make troubleshooting harder
- **Performance**: Network Policies add slight overhead

**Alternatives:**
- **Service Mesh**: Istio/Linkerd for advanced security (more complex)
- **OPA/Gatekeeper**: Policy enforcement (additional tool)
- **Falco**: Runtime security monitoring (additional tool)

## When

**Implement Security When:**
- Deploying to production (always!)
- Handling sensitive data (PII, financial, health)
- Multi-tenant environments
- Need compliance certifications
- Public-facing applications
- High-value targets

**Prerequisites:**
- Completed 00-prereqs (GKE cluster with Workload Identity)
- Understanding of Kubernetes resources (pods, services, deployments)
- Basic understanding of networking concepts
- Familiarity with IAM concepts

**When to Use Each Security Control:**
- **RBAC**: Always (control who can access what)
- **Network Policies**: Always in production (network segmentation)
- **Pod Security Standards**: Always (secure pod configurations)
- **Workload Identity**: Always for GCP access (no service account keys)
- **Image Scanning**: Always before deploying (find vulnerabilities)
- **Binary Authorization**: Production (enforce only signed images)
- **Read-Only Root Filesystem**: Always when possible (prevent tampering)
- **Run as Non-Root**: Always (reduce privilege escalation risk)

**When NOT to Use:**
- Development environments (can relax some controls for convenience)
- Proof of concepts (security can be added later)
- Never skip: Workload Identity, basic RBAC, running as non-root

**Learning Sequence:**
1. **rbac**: Role-Based Access Control (25 minutes)
2. **network-policies**: Network segmentation (25 minutes)
3. **pod-security-standards**: Secure pod configurations (20 minutes)
4. **image-signing-scanning**: Image security (20 minutes)
**Total Time**: ~1.5 hours

## Where

**GCP Services:**
- **Workload Identity**: Secure pod-to-GCP authentication
- **Container Analysis API**: Image vulnerability scanning
- **Binary Authorization**: Image signing and verification
- **Cloud Logging**: Audit logs for security events
- **IAM**: Access control for GCP resources

**IAM Roles Required:**
- `roles/container.developer`: Deploy workloads
- `roles/iam.serviceAccountAdmin`: Create service accounts and bindings
- `roles/containeranalysis.admin`: Enable vulnerability scanning
- `roles/binaryauthorization.policyEditor`: Configure Binary Authorization

**Kubernetes Resources:**
- **Namespace**: Any namespace (default, production, etc.)
- **ServiceAccount**: Pod identity (namespace-scoped)
- **Role**: Permissions within namespace
- **ClusterRole**: Cluster-wide permissions
- **RoleBinding**: Bind Role to ServiceAccount
- **ClusterRoleBinding**: Bind ClusterRole to ServiceAccount
- **NetworkPolicy**: Network segmentation rules (namespace-scoped)
- **Pod**: With securityContext for security settings

**Repository Locations:**
- `08-security/rbac/`: RBAC examples and patterns
- `08-security/network-policies/`: Network Policy examples
- `08-security/pod-security-standards/`: Secure pod configurations
- `08-security/image-signing-scanning/`: Image security examples

**Key Security Settings:**
```yaml
# Pod SecurityContext (always use)
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 1000
  seccompProfile:
    type: RuntimeDefault

# Container SecurityContext (always use)
securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  runAsNonRoot: true
  runAsUser: 1000
  capabilities:
    drop:
    - ALL

# Network Policy (start with deny-all)
policyTypes:
- Ingress
- Egress
```

**Where Costs Accrue:**
- **RBAC**: Free (built into Kubernetes)
- **Network Policies**: Free (built into Kubernetes)
- **Pod Security**: Free (built into Kubernetes)
- **Workload Identity**: Free
- **Container Analysis**: Free for vulnerability scanning
- **Binary Authorization**: Free
- **Cloud Logging**: 50 GB/month free, $0.50/GB after

**Cost Example:**
- All security features: $0/month (within free tiers)
- Audit logging (within free tier): $0/month
- **Total: $0/month**

## How

### Quickstart: RBAC

```bash
# 1. Create ServiceAccount
kubectl create serviceaccount my-app-sa

# 2. Create Role (namespace-scoped permissions)
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: default
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["pods/log"]
  verbs: ["get"]
EOF

# 3. Create RoleBinding
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pods
  namespace: default
subjects:
- kind: ServiceAccount
  name: my-app-sa
  namespace: default
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
EOF

# 4. Test permissions
kubectl auth can-i list pods --as=system:serviceaccount:default:my-app-sa
# Should show: yes
kubectl auth can-i delete pods --as=system:serviceaccount:default:my-app-sa
# Should show: no
```

### Quickstart: Network Policies

```bash
# 1. Create default deny-all policy
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: default
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
EOF

# 2. Allow specific traffic (frontend to backend)
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: default
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 8080
EOF

# 3. Allow DNS (required for most apps)
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: default
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: UDP
      port: 53
EOF
```

### Quickstart: Secure Pod

```bash
# Deploy pod with security best practices
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: secure-app
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    fsGroup: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: nginx:1.21
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      runAsNonRoot: true
      runAsUser: 1000
      capabilities:
        drop:
        - ALL
    volumeMounts:
    - name: tmp
      mountPath: /tmp
    - name: cache
      mountPath: /var/cache/nginx
    - name: run
      mountPath: /var/run
  volumes:
  - name: tmp
    emptyDir: {}
  - name: cache
    emptyDir: {}
  - name: run
    emptyDir: {}
EOF
```

### Quickstart: Workload Identity

```bash
# 1. Create GCP service account
gcloud iam service-accounts create my-app-sa \
  --display-name="My App Service Account"

# 2. Grant GCP permissions
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:my-app-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/cloudsql.client"

# 3. Create Kubernetes service account
kubectl create serviceaccount my-app-ksa

# 4. Bind GCP SA to K8s SA
gcloud iam service-accounts add-iam-policy-binding \
  my-app-sa@${PROJECT_ID}.iam.gserviceaccount.com \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:${PROJECT_ID}.svc.id.goog[default/my-app-ksa]"

# 5. Annotate K8s SA
kubectl annotate serviceaccount my-app-ksa \
  iam.gke.io/gcp-service-account=my-app-sa@${PROJECT_ID}.iam.gserviceaccount.com

# 6. Use in pod
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: workload-identity-test
spec:
  serviceAccountName: my-app-ksa
  containers:
  - name: app
    image: google/cloud-sdk:slim
    command: ["sleep", "3600"]
EOF

# 7. Test Workload Identity
kubectl exec workload-identity-test -- gcloud auth list
# Should show: my-app-sa@PROJECT_ID.iam.gserviceaccount.com
```

### Verify

```bash
# Check RBAC
kubectl get serviceaccount my-app-sa
kubectl get role pod-reader
kubectl get rolebinding read-pods
kubectl auth can-i list pods --as=system:serviceaccount:default:my-app-sa

# Check Network Policies
kubectl get networkpolicy
kubectl describe networkpolicy default-deny-all

# Check Pod Security
kubectl get pod secure-app
kubectl describe pod secure-app | grep -A 10 "Security Context"

# Check Workload Identity
kubectl get sa my-app-ksa -o yaml | grep iam.gke.io
kubectl exec workload-identity-test -- gcloud auth list

# Check for security issues
kubectl get pods -o json | jq '.items[] | select(.spec.securityContext.runAsNonRoot != true) | .metadata.name'
```

### Cleanup

```bash
# Delete RBAC resources
kubectl delete serviceaccount my-app-sa
kubectl delete role pod-reader
kubectl delete rolebinding read-pods

# Delete Network Policies
kubectl delete networkpolicy default-deny-all allow-frontend-to-backend allow-dns

# Delete pods
kubectl delete pod secure-app workload-identity-test

# Delete GCP service account
gcloud iam service-accounts delete my-app-sa@${PROJECT_ID}.iam.gserviceaccount.com --quiet
```

## Overview

This section covers:
- RBAC (Role-Based Access Control)
- Network Policies
- Pod Security Standards
- Image scanning and signing
- Workload Identity
- Security best practices

## Security Layers

### 1. Cluster Security
- GKE security features
- Node security
- Control plane security

### 2. Network Security
- Network policies
- Service mesh
- Ingress security

### 3. Application Security
- Pod security
- Container security
- Secret management

### 4. Identity and Access
- RBAC
- Workload Identity
- Service accounts

## RBAC (Role-Based Access Control)

### Concepts

**ServiceAccount**: Identity for pods
**Role**: Permissions within a namespace
**ClusterRole**: Permissions cluster-wide
**RoleBinding**: Bind Role to ServiceAccount
**ClusterRoleBinding**: Bind ClusterRole to ServiceAccount

### Creating ServiceAccount

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-app-sa
  namespace: default
  annotations:
    iam.gke.io/gcp-service-account: my-app@project.iam.gserviceaccount.com
```

### Creating Role

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: default
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["pods/log"]
  verbs: ["get"]
```

### Creating RoleBinding

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pods
  namespace: default
subjects:
- kind: ServiceAccount
  name: my-app-sa
  namespace: default
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

### Common RBAC Patterns

**Read-only access:**
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: readonly
rules:
- apiGroups: [""]
  resources: ["*"]
  verbs: ["get", "list", "watch"]
```

**ConfigMap/Secret access:**
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: config-reader
rules:
- apiGroups: [""]
  resources: ["configmaps", "secrets"]
  resourceNames: ["my-app-config", "my-app-secret"]
  verbs: ["get"]
```

**Service account token access:**
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: token-creator
rules:
- apiGroups: [""]
  resources: ["serviceaccounts/token"]
  resourceNames: ["my-app-sa"]
  verbs: ["create"]
```

## Network Policies

### Default Deny All

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: default
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

### Allow Ingress from Specific Pods

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-frontend
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 8080
```

### Allow Egress to Database

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-to-database
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: postgresql
    ports:
    - protocol: TCP
      port: 5432
  - to:  # Allow DNS
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: UDP
      port: 53
```

### Allow External HTTPS

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-external-https
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 443
```

## Pod Security Standards

### Pod Security Context

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    fsGroup: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: my-app:1.0
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
        - ALL
      runAsNonRoot: true
      runAsUser: 1000
```

### Pod Security Admission

**Namespace labels:**
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

**Security levels:**
- **Privileged**: Unrestricted (default)
- **Baseline**: Minimally restrictive
- **Restricted**: Heavily restricted (recommended)

### Restricted Pod Example

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: restricted-pod
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    fsGroup: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: my-app:1.0
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      runAsNonRoot: true
      runAsUser: 1000
      capabilities:
        drop:
        - ALL
    volumeMounts:
    - name: tmp
      mountPath: /tmp
    - name: cache
      mountPath: /app/cache
  volumes:
  - name: tmp
    emptyDir: {}
  - name: cache
    emptyDir: {}
```

## Image Security

### Image Scanning

**Enable vulnerability scanning:**
```bash
# Enable Container Analysis API
gcloud services enable containeranalysis.googleapis.com

# Scan image
gcloud container images describe gcr.io/project/image:tag \
  --show-package-vulnerability
```

### Binary Authorization

**Enable Binary Authorization:**
```bash
gcloud services enable binaryauthorization.googleapis.com

# Create policy
cat <<EOF > policy.yaml
admissionWhitelistPatterns:
- namePattern: gcr.io/project/*
defaultAdmissionRule:
  requireAttestationsBy: []
  enforcementMode: ENFORCED_BLOCK_AND_AUDIT_LOG
  evaluationMode: REQUIRE_ATTESTATION
EOF

gcloud container binauthz policy import policy.yaml
```

### Image Signing

```bash
# Sign image with cosign
cosign sign --key cosign.key gcr.io/project/image:tag

# Verify signature
cosign verify --key cosign.pub gcr.io/project/image:tag
```

## Workload Identity

### Setup

```bash
# Create GCP service account
gcloud iam service-accounts create my-app-sa

# Grant permissions
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:my-app-sa@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/cloudsql.client"

# Create K8s service account
kubectl create serviceaccount my-app-ksa

# Bind them
gcloud iam service-accounts add-iam-policy-binding \
  my-app-sa@PROJECT_ID.iam.gserviceaccount.com \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:PROJECT_ID.svc.id.goog[default/my-app-ksa]"

# Annotate K8s SA
kubectl annotate serviceaccount my-app-ksa \
  iam.gke.io/gcp-service-account=my-app-sa@PROJECT_ID.iam.gserviceaccount.com
```

### Using Workload Identity

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  template:
    spec:
      serviceAccountName: my-app-ksa
      containers:
      - name: app
        image: my-app:1.0
        # No credentials needed!
        # Workload Identity provides them automatically
```

## Security Best Practices

### 1. Run as Non-Root

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
```

### 2. Read-Only Root Filesystem

```yaml
securityContext:
  readOnlyRootFilesystem: true

# Mount writable volumes where needed
volumeMounts:
- name: tmp
  mountPath: /tmp
volumes:
- name: tmp
  emptyDir: {}
```

### 3. Drop All Capabilities

```yaml
securityContext:
  capabilities:
    drop:
    - ALL
```

### 4. Use Network Policies

```yaml
# Start with deny-all, then allow specific traffic
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

### 5. Scan Images

```bash
# Scan before deploying
gcloud container images describe IMAGE --show-package-vulnerability
```

### 6. Use Secrets Properly

```yaml
# Never hardcode secrets
env:
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: db-secret
      key: password
```

### 7. Limit Resource Access

```yaml
# Use RBAC to limit what pods can do
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: limited-access
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  resourceNames: ["my-config"]
  verbs: ["get"]
```

### 8. Enable Audit Logging

```bash
# GKE enables audit logging by default
# View logs in Cloud Logging
```

### 9. Use Pod Security Standards

```yaml
# Enforce restricted policy
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    pod-security.kubernetes.io/enforce: restricted
```

### 10. Rotate Credentials

```bash
# Rotate secrets regularly
kubectl create secret generic new-secret --from-literal=password=newpass
kubectl set env deployment/my-app --from=secret/new-secret
kubectl delete secret old-secret
```

## GKE Security Features

### Shielded GKE Nodes

```bash
# Enable shielded nodes (default in Autopilot)
gcloud container clusters create CLUSTER \
  --enable-shielded-nodes
```

### Workload Identity

```bash
# Enable Workload Identity (default in Autopilot)
gcloud container clusters create CLUSTER \
  --workload-pool=PROJECT_ID.svc.id.goog
```

### Private Clusters

```bash
# Create private cluster
gcloud container clusters create CLUSTER \
  --enable-private-nodes \
  --enable-private-endpoint \
  --master-ipv4-cidr 172.16.0.0/28
```

## Security Checklist

- [ ] Run containers as non-root
- [ ] Use read-only root filesystem
- [ ] Drop all capabilities
- [ ] Set resource limits
- [ ] Use network policies
- [ ] Enable Pod Security Standards
- [ ] Scan images for vulnerabilities
- [ ] Use Workload Identity (no service account keys)
- [ ] Store secrets in Secret Manager
- [ ] Enable audit logging
- [ ] Use RBAC with least privilege
- [ ] Rotate credentials regularly
- [ ] Keep images updated
- [ ] Use private container registry
- [ ] Enable Binary Authorization (optional)

## Troubleshooting

### RBAC Permission Denied

```bash
# Check current permissions
kubectl auth can-i list pods --as=system:serviceaccount:default:my-app-sa

# Check role bindings
kubectl get rolebindings -o wide
kubectl describe rolebinding BINDING_NAME
```

### Network Policy Blocking Traffic

```bash
# Check network policies
kubectl get networkpolicies
kubectl describe networkpolicy POLICY_NAME

# Test connectivity
kubectl run -it --rm debug --image=busybox --restart=Never -- sh
# Inside pod: wget -O- http://service:port
```

### Workload Identity Not Working

```bash
# Check service account annotation
kubectl get sa my-app-ksa -o yaml

# Check IAM binding
gcloud iam service-accounts get-iam-policy \
  my-app-sa@PROJECT_ID.iam.gserviceaccount.com

# Test from pod
kubectl run -it --rm test --image=google/cloud-sdk \
  --serviceaccount=my-app-ksa --restart=Never -- \
  gcloud auth list
```

## Next Steps

1. Implement [rbac](./rbac) for access control
2. Configure [network-policies](./network-policies) for network security
3. Apply [pod-security-standards](./pod-security-standards) for pod security
4. Set up [image-signing-scanning](./image-signing-scanning) for image security

## Resources

- [GKE Security Best Practices](https://cloud.google.com/kubernetes-engine/docs/how-to/hardening-your-cluster)
- [Kubernetes Security](https://kubernetes.io/docs/concepts/security/)
- [RBAC Documentation](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
