# Helm Basics

## What

Comprehensive guide to Helm fundamentals covering chart structure, templating with Go templates, dependencies, packaging for OCI registries (Artifact Registry), and testing/validation. This section teaches you how to create, customize, package, and deploy Helm charts on GKE.

**What You'll Learn:**
- Chart structure (Chart.yaml, values.yaml, templates/, _helpers.tpl, NOTES.txt)
- Go template syntax and built-in objects (.Values, .Release, .Chart)
- Template functions, pipelines, and control structures
- Chart dependencies and subcharts
- Packaging and publishing to Artifact Registry (OCI format)
- Testing with helm lint, helm template, and values.schema.json

## Why

**Why Helm Matters:**
- **Templating**: Parameterize Kubernetes manifests for reusability across environments
- **Versioning**: Track application versions and rollback easily
- **Packaging**: Bundle related Kubernetes resources into a single deployable unit
- **Ecosystem**: Leverage thousands of community charts (Bitnami, stable, etc.)
- **Enterprise Adoption**: Industry standard for Kubernetes application deployment
- **Consistency**: Ensure deployments are reproducible and consistent

**Why Learn Helm Basics:**
- **Foundation**: All other sections use Helm charts
- **Customization**: Understand how to modify charts for your needs
- **Troubleshooting**: Debug template rendering issues
- **Best Practices**: Learn patterns used in production charts
- **Career**: Helm is a required skill for Kubernetes roles

**Trade-offs:**
- **Learning Curve**: Go template syntax and Helm concepts require learning
- **Complexity**: More complex than raw kubectl for simple deployments
- **Debugging**: Template errors can be cryptic
- **Overhead**: Additional abstraction layer over Kubernetes

**Alternatives:**
- **kubectl + kustomize**: Simpler, no templating, but less flexible
- **Raw YAML**: Direct control, but no parameterization
- **Operators**: More complex, but better for stateful applications
- **CI/CD templating**: Use CI/CD variables instead of Helm

## When

**Learn Helm Basics When:**
- Starting with Helm for the first time
- Need to customize existing Helm charts
- Want to create reusable Kubernetes deployments
- Working with multi-environment deployments (dev/staging/prod)
- Need to package and share applications

**Prerequisites:**
- Completed 00-prereqs (GKE cluster setup)
- Basic Kubernetes knowledge (pods, deployments, services)
- Basic YAML syntax
- Basic command-line skills

**When to Use Helm:**
- Deploying applications with multiple Kubernetes resources
- Need to parameterize configurations for different environments
- Want to version and rollback deployments
- Sharing applications with others
- Managing complex dependencies

**When NOT to Use Helm:**
- Very simple single-resource deployments (use kubectl)
- Learning Kubernetes basics (learn kubectl first)
- Need advanced lifecycle management (consider Operators)
- Team unfamiliar with Go templates (consider kustomize)

**Learning Sequence:**
1. **chart-skeleton**: Understand chart structure (15 minutes)
2. **templating-fundamentals**: Learn Go template syntax (30 minutes)
3. **dependencies**: Manage subcharts (20 minutes)
4. **packaging-and-oci**: Publish to Artifact Registry (20 minutes)
5. **testing-and-lint**: Validate charts (15 minutes)
**Total Time**: ~2 hours

## Where

**GCP Services:**
- **Artifact Registry**: Store Helm charts in OCI format
- **GKE**: Deploy Helm charts to Kubernetes cluster
- No additional GCP services required for basic Helm usage

**IAM Roles Required:**
- `roles/artifactregistry.writer`: Push charts to Artifact Registry
- `roles/container.developer`: Deploy to GKE
- Typically granted during 00-prereqs setup

**Kubernetes Resources:**
- **Namespace**: Any namespace (default, production, etc.)
- **Resources Created**: Depends on chart (Deployment, Service, ConfigMap, Secret, Ingress, etc.)

**Repository Locations:**
- `01-helm-basics/chart-skeleton/`: Basic chart structure examples
- `01-helm-basics/templating-fundamentals/`: Template syntax examples
- `01-helm-basics/dependencies/`: Subchart examples
- `01-helm-basics/packaging-and-oci/`: OCI publishing examples
- `01-helm-basics/testing-and-lint/`: Validation examples

**Key Helm Concepts:**
```
Chart: Collection of files describing Kubernetes resources
Release: Instance of a chart running in a cluster
Repository: Place where charts are stored (HTTP or OCI)
Values: Configuration parameters for a chart
Templates: Kubernetes manifests with Go template syntax
```

**Where Costs Accrue:**
- **Artifact Registry**: $0.10/GB/month storage (minimal for Helm charts)
- **GKE**: Cost of running pods (covered in 00-prereqs)
- Helm itself is free and open-source

## How

### Quickstart: Create and Deploy Your First Chart

```bash
# 1. Create a new chart
helm create my-app

# 2. View the structure
tree my-app/
# Shows: Chart.yaml, values.yaml, templates/, charts/, .helmignore

# 3. Lint the chart (validate syntax)
helm lint my-app/
# Should show: 1 chart(s) linted, 0 chart(s) failed

# 4. Render templates locally (dry-run)
helm template my-release my-app/
# Shows rendered Kubernetes manifests

# 5. Install the chart
helm install my-release my-app/ --namespace default

# 6. Check release status
helm status my-release
kubectl get pods -l app.kubernetes.io/instance=my-release

# 7. Customize with values
helm upgrade my-release my-app/ \
  --set replicaCount=3 \
  --set image.tag=1.0.0

# 8. View release history
helm history my-release

# 9. Rollback if needed
helm rollback my-release 1

# 10. Uninstall
helm uninstall my-release
```

### Verify

```bash
# Check Helm version
helm version
# Should show version 3.x

# List installed releases
helm list --all-namespaces

# Check chart syntax
helm lint my-app/

# Render templates without installing
helm template test my-app/ --debug

# Show default values
helm show values my-app/

# Show chart metadata
helm show chart my-app/

# Show all chart information
helm show all my-app/
```

### Cleanup

```bash
# Uninstall release
helm uninstall my-release

# Verify pods deleted
kubectl get pods -l app.kubernetes.io/instance=my-release
# Should show: No resources found

# Delete chart directory (if testing)
rm -rf my-app/
```

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
