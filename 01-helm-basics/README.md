# Helm Basics

Learn the fundamentals of Helm charts and how to create, package, and deploy them on GKE.

## What is Helm?

Helm is the package manager for Kubernetes. It helps you:
- Define, install, and upgrade Kubernetes applications
- Manage complex deployments with templates
- Share applications as packages (charts)
- Version and rollback releases

## Helm Concepts

### Chart
A Helm chart is a collection of files that describe a related set of Kubernetes resources. A single chart might deploy:
- A simple pod
- A full web application stack
- A complete microservices architecture

### Release
A release is an instance of a chart running in a Kubernetes cluster. You can install the same chart multiple times with different release names.

### Repository
A repository is a place where charts can be stored and shared. Helm supports:
- HTTP/HTTPS repositories
- OCI registries (like Artifact Registry)

## Chart Structure

```
my-chart/
├── Chart.yaml              # Chart metadata
├── values.yaml             # Default configuration values
├── values.schema.json      # JSON schema for values validation
├── charts/                 # Dependency charts
├── templates/              # Kubernetes manifest templates
│   ├── NOTES.txt          # Post-install notes
│   ├── _helpers.tpl       # Template helpers
│   ├── deployment.yaml    # Deployment template
│   ├── service.yaml       # Service template
│   ├── ingress.yaml       # Ingress template
│   ├── configmap.yaml     # ConfigMap template
│   ├── secret.yaml        # Secret template
│   └── tests/             # Test files
│       └── test-connection.yaml
└── .helmignore            # Files to ignore when packaging
```

## Sections in This Guide

### [chart-skeleton](./chart-skeleton) - Chart Structure
- Basic chart structure
- Chart.yaml metadata
- values.yaml configuration
- _helpers.tpl template functions
- NOTES.txt for user guidance

### [templating-fundamentals](./templating-fundamentals) - Templating
- Go template syntax
- Built-in objects (`.Values`, `.Release`, `.Chart`)
- Template functions and pipelines
- Control structures (if/else, range, with)
- Named templates and includes

### [dependencies](./dependencies) - Chart Dependencies
- Declaring dependencies in Chart.yaml
- Managing subcharts
- Global values
- Parent-child value overrides

### [packaging-and-oci](./packaging-and-oci) - Packaging & Distribution
- Packaging charts
- Publishing to Artifact Registry (OCI)
- Versioning best practices
- Chart signing (optional)

### [testing-and-lint](./testing-and-lint) - Testing & Validation
- helm lint for syntax checking
- helm template for dry-run
- values.schema.json validation
- Chart testing with chart-testing tool

## Quick Start

### Create Your First Chart

```bash
# Create a new chart
helm create my-app

# View the structure
tree my-app/

# Lint the chart
helm lint my-app/

# Render templates locally (dry-run)
helm template my-app my-app/

# Install the chart
helm install my-release my-app/

# List releases
helm list

# Get release status
helm status my-release

# Upgrade release
helm upgrade my-release my-app/

# Rollback release
helm rollback my-release 1

# Uninstall release
helm uninstall my-release
```

### Common Helm Commands

```bash
# Chart management
helm create CHART_NAME              # Create new chart
helm lint CHART_PATH                # Validate chart
helm package CHART_PATH             # Package chart into .tgz
helm template RELEASE CHART_PATH    # Render templates locally

# Release management
helm install RELEASE CHART          # Install chart
helm upgrade RELEASE CHART          # Upgrade release
helm rollback RELEASE REVISION      # Rollback to previous version
helm uninstall RELEASE              # Uninstall release
helm list                           # List releases
helm status RELEASE                 # Show release status
helm history RELEASE                # Show release history

# Repository management
helm repo add NAME URL              # Add repository
helm repo update                    # Update repository index
helm repo list                      # List repositories
helm search repo KEYWORD            # Search charts

# OCI registry (Artifact Registry)
helm push CHART.tgz oci://REGISTRY  # Push chart to OCI registry
helm pull oci://REGISTRY/CHART      # Pull chart from OCI registry
helm install RELEASE oci://REGISTRY/CHART  # Install from OCI

# Values management
helm show values CHART              # Show default values
helm get values RELEASE             # Show values used in release
helm install RELEASE CHART --set key=value  # Override single value
helm install RELEASE CHART -f values.yaml   # Override with file
```

## Best Practices

### 1. Chart Metadata (Chart.yaml)

```yaml
apiVersion: v2
name: my-app
description: A Helm chart for my application
type: application
version: 0.1.0        # Chart version (SemVer)
appVersion: "1.0.0"   # Application version
keywords:
  - web
  - api
maintainers:
  - name: Your Name
    email: your.email@example.com
```

### 2. Values Organization

```yaml
# values.yaml - Organize by resource type
replicaCount: 1

image:
  repository: nginx
  pullPolicy: IfNotPresent
  tag: ""  # Defaults to .Chart.AppVersion

service:
  type: ClusterIP
  port: 80

ingress:
  enabled: false
  className: ""
  annotations: {}
  hosts: []
  tls: []

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
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80
```

### 3. Template Helpers (_helpers.tpl)

```yaml
{{/*
Expand the name of the chart.
*/}}
{{- define "my-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "my-app.fullname" -}}
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
Common labels
*/}}
{{- define "my-app.labels" -}}
helm.sh/chart: {{ include "my-app.chart" . }}
{{ include "my-app.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "my-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "my-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
```

### 4. NOTES.txt Template

```
Thank you for installing {{ .Chart.Name }}!

Your release is named {{ .Release.Name }}.

To learn more about the release, try:

  $ helm status {{ .Release.Name }}
  $ helm get all {{ .Release.Name }}

{{- if .Values.ingress.enabled }}

Your application is available at:
{{- range .Values.ingress.hosts }}
  http{{ if $.Values.ingress.tls }}s{{ end }}://{{ .host }}
{{- end }}
{{- else }}

Get the application URL by running:
  export POD_NAME=$(kubectl get pods --namespace {{ .Release.Namespace }} -l "app.kubernetes.io/name={{ include "my-app.name" . }},app.kubernetes.io/instance={{ .Release.Name }}" -o jsonpath="{.items[0].metadata.name}")
  kubectl --namespace {{ .Release.Namespace }} port-forward $POD_NAME 8080:80
  echo "Visit http://127.0.0.1:8080"
{{- end }}
```

## Template Syntax Quick Reference

### Variables and Values

```yaml
# Access values
{{ .Values.image.repository }}
{{ .Values.replicaCount }}

# Access chart metadata
{{ .Chart.Name }}
{{ .Chart.Version }}
{{ .Chart.AppVersion }}

# Access release info
{{ .Release.Name }}
{{ .Release.Namespace }}
{{ .Release.Service }}

# Define variables
{{- $relname := .Release.Name -}}
{{- $chartname := .Chart.Name -}}
```

### Control Structures

```yaml
# If/Else
{{- if .Values.ingress.enabled }}
# ingress config
{{- else }}
# no ingress
{{- end }}

# Range (loop)
{{- range .Values.hosts }}
- host: {{ . }}
{{- end }}

# With (scope)
{{- with .Values.service }}
type: {{ .type }}
port: {{ .port }}
{{- end }}
```

### Functions

```yaml
# String functions
{{ .Values.name | upper }}
{{ .Values.name | lower }}
{{ .Values.name | quote }}
{{ .Values.name | trunc 63 }}
{{ .Values.name | trimSuffix "-" }}

# Default values
{{ .Values.tag | default .Chart.AppVersion }}

# Type conversion
{{ .Values.port | int }}
{{ .Values.enabled | toString }}

# Encoding
{{ .Values.data | b64enc }}
{{ .Values.data | b64dec }}
```

## Next Steps

1. Explore [chart-skeleton](./chart-skeleton) to create your first chart
2. Learn [templating-fundamentals](./templating-fundamentals) for dynamic configurations
3. Add [dependencies](./dependencies) to compose complex applications
4. Package and publish with [packaging-and-oci](./packaging-and-oci)
5. Validate with [testing-and-lint](./testing-and-lint)

## Resources

- [Helm Documentation](https://helm.sh/docs/)
- [Helm Chart Best Practices](https://helm.sh/docs/chart_best_practices/)
- [Go Template Documentation](https://pkg.go.dev/text/template)
- [Sprig Function Documentation](http://masterminds.github.io/sprig/)
