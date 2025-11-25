# Chart Skeleton - Basic Chart Structure

Learn how to create a basic Helm chart structure from scratch.

## Creating a Chart

```bash
# Create a new chart
helm create my-app

# This creates:
my-app/
├── Chart.yaml
├── values.yaml
├── charts/
└── templates/
    ├── NOTES.txt
    ├── _helpers.tpl
    ├── deployment.yaml
    ├── hpa.yaml
    ├── ingress.yaml
    ├── service.yaml
    ├── serviceaccount.yaml
    └── tests/
        └── test-connection.yaml
```

## Chart.yaml - Chart Metadata

```yaml
apiVersion: v2
name: my-app
description: A Helm chart for Kubernetes
type: application
version: 0.1.0
appVersion: "1.16.0"

keywords:
  - web
  - api
  - microservice

maintainers:
  - name: Your Name
    email: your.email@example.com
    url: https://github.com/yourusername

sources:
  - https://github.com/yourusername/my-app

home: https://my-app.example.com

# Optional: Icon for chart
icon: https://example.com/icon.png

# Optional: Dependencies
dependencies:
  - name: postgresql
    version: "12.x.x"
    repository: "https://charts.bitnami.com/bitnami"
    condition: postgresql.enabled
```

### Chart Types

- **application**: Default type for application charts
- **library**: Provides utilities/functions for other charts (no deployable resources)

### Versioning

- **version**: Chart version (SemVer) - increment when chart changes
- **appVersion**: Application version - the version of the app being deployed

## values.yaml - Default Configuration

```yaml
# Default values for my-app
# This is a YAML-formatted file
# Declare variables to be passed into your templates

replicaCount: 1

image:
  repository: nginx
  pullPolicy: IfNotPresent
  # Overrides the image tag whose default is the chart appVersion
  tag: ""

imagePullSecrets: []
nameOverride: ""
fullnameOverride: ""

serviceAccount:
  # Specifies whether a service account should be created
  create: true
  # Annotations to add to the service account
  annotations: {}
  # The name of the service account to use
  name: ""

podAnnotations: {}

podSecurityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 1000

securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop:
    - ALL
  readOnlyRootFilesystem: true

service:
  type: ClusterIP
  port: 80

ingress:
  enabled: false
  className: ""
  annotations: {}
    # kubernetes.io/ingress.class: nginx
    # cert-manager.io/cluster-issuer: letsencrypt-prod
  hosts:
    - host: chart-example.local
      paths:
        - path: /
          pathType: ImplementationSpecific
  tls: []
  #  - secretName: chart-example-tls
  #    hosts:
  #      - chart-example.local

resources:
  limits:
    cpu: 100m
    memory: 128Mi
  requests:
    cpu: 100m
    memory: 128Mi

autoscaling:
  enabled: false
  minReplicas: 1
  maxReplicas: 100
  targetCPUUtilizationPercentage: 80
  # targetMemoryUtilizationPercentage: 80

nodeSelector: {}

tolerations: []

affinity: {}
```

## Example: Simple Web Application Chart

Let's create a minimal chart for a web application:

### Chart.yaml

```yaml
apiVersion: v2
name: simple-web
description: Simple web application
type: application
version: 0.1.0
appVersion: "1.0.0"
```

### values.yaml

```yaml
replicaCount: 2

image:
  repository: nginx
  tag: "1.21"
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 80

resources:
  limits:
    cpu: 100m
    memory: 128Mi
  requests:
    cpu: 50m
    memory: 64Mi
```

### templates/deployment.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "simple-web.fullname" . }}
  labels:
    {{- include "simple-web.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      {{- include "simple-web.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "simple-web.selectorLabels" . | nindent 8 }}
    spec:
      containers:
      - name: {{ .Chart.Name }}
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
        imagePullPolicy: {{ .Values.image.pullPolicy }}
        ports:
        - name: http
          containerPort: 80
          protocol: TCP
        livenessProbe:
          httpGet:
            path: /
            port: http
        readinessProbe:
          httpGet:
            path: /
            port: http
        resources:
          {{- toYaml .Values.resources | nindent 10 }}
```

### templates/service.yaml

```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "simple-web.fullname" . }}
  labels:
    {{- include "simple-web.labels" . | nindent 4 }}
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: http
      protocol: TCP
      name: http
  selector:
    {{- include "simple-web.selectorLabels" . | nindent 4 }}
```

### templates/_helpers.tpl

```yaml
{{/*
Expand the name of the chart.
*/}}
{{- define "simple-web.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "simple-web.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "simple-web.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "simple-web.labels" -}}
helm.sh/chart: {{ include "simple-web.chart" . }}
{{ include "simple-web.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "simple-web.selectorLabels" -}}
app.kubernetes.io/name: {{ include "simple-web.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
```

### templates/NOTES.txt

```
Thank you for installing {{ .Chart.Name }}!

Your release is named {{ .Release.Name }}.

To get the application URL:
  export POD_NAME=$(kubectl get pods --namespace {{ .Release.Namespace }} -l "app.kubernetes.io/name={{ include "simple-web.name" . }},app.kubernetes.io/instance={{ .Release.Name }}" -o jsonpath="{.items[0].metadata.name}")
  kubectl --namespace {{ .Release.Namespace }} port-forward $POD_NAME 8080:80
  echo "Visit http://127.0.0.1:8080"
```

## Testing the Chart

```bash
# Lint the chart
helm lint simple-web/

# Render templates (dry-run)
helm template my-release simple-web/

# Install the chart
helm install my-release simple-web/

# Check the release
helm list
kubectl get all -l app.kubernetes.io/instance=my-release

# Upgrade with new values
helm upgrade my-release simple-web/ --set replicaCount=3

# Uninstall
helm uninstall my-release
```

## Best Practices

1. **Use meaningful names**: Chart names should be lowercase with hyphens
2. **Version properly**: Follow SemVer for chart versions
3. **Document values**: Add comments in values.yaml
4. **Use helpers**: Define reusable templates in _helpers.tpl
5. **Add NOTES.txt**: Provide post-install instructions
6. **Set resource limits**: Always define resource requests and limits
7. **Use labels**: Apply consistent labels using helpers
8. **Security**: Set securityContext and run as non-root

## Common Files

### .helmignore

```
# Patterns to ignore when packaging
.git/
.gitignore
.DS_Store
*.swp
*.bak
*.tmp
*.orig
*~
.project
.idea/
*.tmproj
.vscode/
```

### values.schema.json (Optional but recommended)

```json
{
  "$schema": "https://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["replicaCount", "image"],
  "properties": {
    "replicaCount": {
      "type": "integer",
      "minimum": 1,
      "maximum": 10
    },
    "image": {
      "type": "object",
      "required": ["repository", "tag"],
      "properties": {
        "repository": {
          "type": "string"
        },
        "tag": {
          "type": "string"
        },
        "pullPolicy": {
          "type": "string",
          "enum": ["Always", "IfNotPresent", "Never"]
        }
      }
    }
  }
}
```

## Next Steps

- Learn [templating-fundamentals](../templating-fundamentals) for dynamic configurations
- Add [dependencies](../dependencies) to compose applications
- Explore [testing-and-lint](../testing-and-lint) for validation
