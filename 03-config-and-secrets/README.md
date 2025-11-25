# Configuration and Secrets Management

Learn how to manage application configuration and secrets securely on GKE.

## Overview

This section covers:
- ConfigMaps for non-sensitive configuration
- Kubernetes Secrets for sensitive data
- Secret Manager CSI driver for GCP-managed secrets
- Best practices for configuration management

## Configuration Options

### ConfigMaps
Store non-sensitive configuration data as key-value pairs.

**Use for:**
- Application settings
- Environment variables
- Configuration files
- Feature flags

**Don't use for:**
- Passwords
- API keys
- Certificates
- Any sensitive data

### Kubernetes Secrets
Store sensitive data in Kubernetes (base64 encoded).

**Use for:**
- Database passwords
- API keys
- TLS certificates
- OAuth tokens

**Limitations:**
- Base64 encoded (not encrypted at rest by default)
- Stored in etcd
- Visible to cluster admins

### Secret Manager CSI Driver
Mount GCP Secret Manager secrets as volumes.

**Use for:**
- Production secrets
- Secrets shared across clusters
- Secrets requiring audit logs
- Secrets with rotation policies

**Benefits:**
- Encrypted at rest
- Centralized management
- Audit logging
- Access control with IAM
- Automatic rotation support

## ConfigMaps

### Creating ConfigMaps

**From literals:**
```bash
kubectl create configmap app-config \
  --from-literal=db_host=postgresql.default.svc.cluster.local \
  --from-literal=db_port=5432 \
  --from-literal=log_level=info
```

**From file:**
```bash
kubectl create configmap app-config \
  --from-file=config.yaml
```

**From YAML:**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  db_host: "postgresql.default.svc.cluster.local"
  db_port: "5432"
  db_name: "mydb"
  log_level: "info"
  config.yaml: |
    server:
      port: 8080
      timeout: 30
    database:
      pool_size: 10
      max_connections: 100
```

### Using ConfigMaps

**As environment variables:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app
spec:
  containers:
  - name: app
    image: my-app:1.0
    env:
    - name: DB_HOST
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: db_host
    - name: DB_PORT
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: db_port
```

**As volume:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app
spec:
  containers:
  - name: app
    image: my-app:1.0
    volumeMounts:
    - name: config
      mountPath: /etc/config
      readOnly: true
  volumes:
  - name: config
    configMap:
      name: app-config
```

**All keys as env vars:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app
spec:
  containers:
  - name: app
    image: my-app:1.0
    envFrom:
    - configMapRef:
        name: app-config
```

## Kubernetes Secrets

### Creating Secrets

**From literals:**
```bash
kubectl create secret generic app-secret \
  --from-literal=db_password=mypassword \
  --from-literal=api_key=myapikey
```

**From file:**
```bash
kubectl create secret generic tls-secret \
  --from-file=tls.crt=server.crt \
  --from-file=tls.key=server.key
```

**From YAML:**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secret
type: Opaque
stringData:
  db_password: "mypassword"  # Will be base64 encoded
  api_key: "myapikey"
# Or use data with base64 encoded values:
# data:
#   db_password: bXlwYXNzd29yZA==
```

### Using Secrets

**As environment variables:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app
spec:
  containers:
  - name: app
    image: my-app:1.0
    env:
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: app-secret
          key: db_password
    - name: API_KEY
      valueFrom:
        secretKeyRef:
          name: app-secret
          key: api_key
```

**As volume:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app
spec:
  containers:
  - name: app
    image: my-app:1.0
    volumeMounts:
    - name: secrets
      mountPath: /etc/secrets
      readOnly: true
  volumes:
  - name: secrets
    secret:
      secretName: app-secret
```

## Secret Manager CSI Driver

### Prerequisites

1. **Enable Secret Manager API:**
```bash
gcloud services enable secretmanager.googleapis.com
```

2. **Create GCP secrets:**
```bash
echo -n "mypassword" | gcloud secrets create db-password --data-file=-
echo -n "myapikey" | gcloud secrets create api-key --data-file=-
```

3. **Grant access to service account:**
```bash
gcloud secrets add-iam-policy-binding db-password \
  --member="serviceAccount:my-app-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

4. **Install CSI driver (if not already installed):**
```bash
kubectl apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/secrets-store-csi-driver-provider-gcp/main/deploy/provider-gcp-plugin.yaml
```

### Using Secret Manager CSI

**SecretProviderClass:**
```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: app-secrets
spec:
  provider: gcp
  parameters:
    secrets: |
      - resourceName: "projects/PROJECT_ID/secrets/db-password/versions/latest"
        path: "db_password"
      - resourceName: "projects/PROJECT_ID/secrets/api-key/versions/latest"
        path: "api_key"
```

**Pod using CSI:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app
spec:
  serviceAccountName: my-app-ksa  # With Workload Identity
  containers:
  - name: app
    image: my-app:1.0
    volumeMounts:
    - name: secrets
      mountPath: /var/secrets
      readOnly: true
    env:
    - name: DB_PASSWORD
      value: /var/secrets/db_password
  volumes:
  - name: secrets
    csi:
      driver: secrets-store.csi.k8s.io
      readOnly: true
      volumeAttributes:
        secretProviderClass: app-secrets
```

### Sync to Kubernetes Secret

```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: app-secrets
spec:
  provider: gcp
  parameters:
    secrets: |
      - resourceName: "projects/PROJECT_ID/secrets/db-password/versions/latest"
        path: "db_password"
  secretObjects:
  - secretName: app-secret-k8s
    type: Opaque
    data:
    - objectName: db_password
      key: password
```

Now you can use it as a regular Kubernetes secret:
```yaml
env:
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: app-secret-k8s
      key: password
```

## Helm Chart Integration

### ConfigMap in Helm

**values.yaml:**
```yaml
config:
  db_host: postgresql.default.svc.cluster.local
  db_port: "5432"
  db_name: mydb
  log_level: info
```

**templates/configmap.yaml:**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "app.fullname" . }}-config
  labels:
    {{- include "app.labels" . | nindent 4 }}
data:
  {{- range $key, $value := .Values.config }}
  {{ $key }}: {{ $value | quote }}
  {{- end }}
```

### Secret in Helm

**values.yaml:**
```yaml
secret:
  db_password: ""  # Set via --set or separate values file
  api_key: ""
```

**templates/secret.yaml:**
```yaml
{{- if or .Values.secret.db_password .Values.secret.api_key }}
apiVersion: v1
kind: Secret
metadata:
  name: {{ include "app.fullname" . }}-secret
  labels:
    {{- include "app.labels" . | nindent 4 }}
type: Opaque
stringData:
  {{- if .Values.secret.db_password }}
  db_password: {{ .Values.secret.db_password | quote }}
  {{- end }}
  {{- if .Values.secret.api_key }}
  api_key: {{ .Values.secret.api_key | quote }}
  {{- end }}
{{- end }}
```

**Install with secrets:**
```bash
helm install my-app ./chart \
  --set secret.db_password=mypassword \
  --set secret.api_key=myapikey
```

### Secret Manager CSI in Helm

**values.yaml:**
```yaml
secretManager:
  enabled: true
  projectId: my-project-id
  secrets:
    - name: db-password
      path: db_password
    - name: api-key
      path: api_key
```

**templates/secretproviderclass.yaml:**
```yaml
{{- if .Values.secretManager.enabled }}
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: {{ include "app.fullname" . }}-secrets
  labels:
    {{- include "app.labels" . | nindent 4 }}
spec:
  provider: gcp
  parameters:
    secrets: |
      {{- range .Values.secretManager.secrets }}
      - resourceName: "projects/{{ $.Values.secretManager.projectId }}/secrets/{{ .name }}/versions/latest"
        path: "{{ .path }}"
      {{- end }}
{{- end }}
```

## Best Practices

### 1. Never Commit Secrets to Git

```bash
# .gitignore
secrets.yaml
*-secret.yaml
*.key
*.pem
.env
```

### 2. Use Separate Values Files for Secrets

```bash
# values-secrets.yaml (not in git)
secret:
  db_password: mypassword
  api_key: myapikey

# Install
helm install my-app ./chart \
  -f values.yaml \
  -f values-secrets.yaml
```

### 3. Use Secret Manager for Production

```yaml
# Development: Kubernetes Secrets
secretManager:
  enabled: false

# Production: Secret Manager CSI
secretManager:
  enabled: true
```

### 4. Limit Secret Access

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-sa
  annotations:
    iam.gke.io/gcp-service-account: app-sa@project.iam.gserviceaccount.com
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: secret-reader
rules:
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["app-secret"]
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-secret-reader
subjects:
- kind: ServiceAccount
  name: app-sa
roleRef:
  kind: Role
  name: secret-reader
  apiGroup: rbac.authorization.k8s.io
```

### 5. Rotate Secrets Regularly

```bash
# Update secret in Secret Manager
echo -n "newpassword" | gcloud secrets versions add db-password --data-file=-

# Restart pods to pick up new secret
kubectl rollout restart deployment/my-app
```

### 6. Use Immutable ConfigMaps/Secrets

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config-v1
immutable: true
data:
  config: value
```

Benefits:
- Prevents accidental updates
- Better performance
- Forces versioning

### 7. Validate Configuration

```yaml
# values.schema.json
{
  "$schema": "https://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["config"],
  "properties": {
    "config": {
      "type": "object",
      "required": ["db_host", "db_port"],
      "properties": {
        "db_host": {
          "type": "string",
          "minLength": 1
        },
        "db_port": {
          "type": "string",
          "pattern": "^[0-9]+$"
        }
      }
    }
  }
}
```

## Security Considerations

### 1. Encryption at Rest

GKE encrypts secrets at rest by default using Google-managed keys.

For additional security, use Secret Manager.

### 2. RBAC

Limit who can read secrets:
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: secret-reader
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list"]
```

### 3. Audit Logging

Enable audit logging for secret access:
```bash
# GKE audit logging is enabled by default
# View logs in Cloud Logging
```

### 4. Network Policies

Restrict which pods can access secrets:
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-secret-access
spec:
  podSelector:
    matchLabels:
      app: my-app
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: secret-manager
```

## Troubleshooting

### ConfigMap Not Updating

```bash
# ConfigMaps are cached by kubelet
# Restart pods to pick up changes
kubectl rollout restart deployment/my-app

# Or use immutable ConfigMaps with versioning
```

### Secret Manager CSI Not Working

```bash
# Check CSI driver
kubectl get pods -n kube-system | grep csi

# Check SecretProviderClass
kubectl describe secretproviderclass app-secrets

# Check Workload Identity
kubectl describe sa my-app-ksa

# Check GCP IAM permissions
gcloud secrets get-iam-policy db-password
```

### Permission Denied

```bash
# Check service account annotation
kubectl get sa my-app-ksa -o yaml

# Check IAM binding
gcloud iam service-accounts get-iam-policy \
  my-app-sa@project.iam.gserviceaccount.com

# Grant access
gcloud secrets add-iam-policy-binding db-password \
  --member="serviceAccount:my-app-sa@project.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

## Next Steps

1. Explore [configmaps](./configmaps) for configuration examples
2. Learn [kubernetes-secrets](./kubernetes-secrets) for basic secret management
3. Set up [secretmanager-csi](./secretmanager-csi) for production secrets

## Resources

- [ConfigMaps Documentation](https://kubernetes.io/docs/concepts/configuration/configmap/)
- [Secrets Documentation](https://kubernetes.io/docs/concepts/configuration/secret/)
- [Secret Manager CSI Driver](https://github.com/GoogleCloudPlatform/secrets-store-csi-driver-provider-gcp)
- [Workload Identity](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity)
