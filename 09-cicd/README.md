# CI/CD - Continuous Integration and Deployment

## What

Comprehensive guide to automating testing, building, and deploying Helm charts to GKE using GitHub Actions, covering Helm chart linting and testing, Docker image building and publishing, Helm chart packaging to Artifact Registry, automated deployments to multiple environments, and Workload Identity Federation for secure authentication.

**Resources Created:**
- GitHub Actions workflows (.github/workflows/)
- Workload Identity Pool and Provider (GCP)
- GCP service account for GitHub Actions
- IAM bindings for deployment permissions
- Multi-environment deployment pipelines (dev, staging, production)

## Why

**Why CI/CD Matters:**
- **Automation**: Eliminate manual deployment steps and human errors
- **Speed**: Deploy changes faster with automated pipelines
- **Consistency**: Same process every time, reproducible deployments
- **Quality**: Automated testing catches issues before production
- **Confidence**: Test in staging before production
- **Rollback**: Easy to revert to previous versions
- **Audit Trail**: Track who deployed what and when

**Why Use GitHub Actions:**
- **Native Integration**: Built into GitHub, no external service needed
- **Free for Public Repos**: Generous free tier for private repos
- **Simple YAML**: Easy to understand and maintain
- **Rich Ecosystem**: Thousands of pre-built actions
- **Matrix Builds**: Test multiple configurations in parallel
- **Environments**: Built-in approval gates for production

**Why Use Workload Identity Federation:**
- **No Service Account Keys**: Eliminates key management and rotation
- **Short-Lived Tokens**: Automatic credential rotation
- **Fine-Grained Permissions**: Use IAM for access control
- **Audit Logging**: Track all GCP resource access
- **Best Practice**: Google-recommended authentication method
- **Secure**: No secrets stored in GitHub

**Trade-offs:**
- **Complexity**: CI/CD adds configuration and maintenance overhead
- **Learning Curve**: Understanding GitHub Actions, Helm, Docker, GCP
- **Build Time**: Automated pipelines take time to run
- **Debugging**: Troubleshooting CI/CD issues can be challenging

**Alternatives:**
- **Cloud Build**: GCP-native CI/CD (more complex, tighter GCP integration)
- **GitLab CI**: Alternative to GitHub Actions
- **Jenkins**: Self-hosted, more flexible but more maintenance
- **CircleCI**: Commercial CI/CD service
- **ArgoCD**: GitOps-based continuous deployment

## When

**Implement CI/CD When:**
- Deploying to production (always!)
- Multiple team members deploying
- Need consistent deployments
- Want automated testing
- Need approval gates for production
- Want to track deployment history

**Prerequisites:**
- Completed 00-prereqs (GKE cluster, Artifact Registry)
- GitHub repository with Helm charts
- Understanding of Helm charts and Docker
- GCP project with appropriate APIs enabled
- Basic understanding of YAML and GitHub Actions

**When to Use Each Pipeline:**
- **Lint**: Every pull request (catch issues early)
- **Test**: Every pull request and main branch push
- **Build**: Main branch push and tags (create artifacts)
- **Deploy to Dev**: Automatic on main branch push
- **Deploy to Staging**: Automatic after dev deployment succeeds
- **Deploy to Production**: Manual approval required

**When NOT to Use:**
- Very simple projects (manual deployment may suffice)
- Proof of concepts (can add CI/CD later)
- Single developer projects (less critical but still recommended)

**Learning Sequence:**
1. **github-actions-ct**: Chart testing and linting (20 minutes)
2. **github-actions-helm-oci**: Package and publish charts (25 minutes)
3. **deploy-to-gke**: Automated GKE deployments (30 minutes)
**Total Time**: ~1.5 hours

## Where

**GCP Services:**
- **Artifact Registry**: Store Docker images and Helm charts
- **GKE**: Kubernetes cluster for deployments
- **Workload Identity Federation**: Authenticate GitHub Actions
- **IAM**: Access control for deployments
- **Cloud Logging**: CI/CD audit logs

**IAM Roles Required:**
- `roles/container.developer`: Deploy to GKE
- `roles/artifactregistry.writer`: Push images and charts
- `roles/iam.serviceAccountAdmin`: Create service accounts (setup)
- `roles/iam.workloadIdentityPoolAdmin`: Create Workload Identity Pool (setup)

**GitHub Resources:**
- **Workflows**: .github/workflows/*.yaml
- **Secrets**: Repository secrets for GCP project info
- **Environments**: dev, staging, production (with approval gates)
- **Actions**: Pre-built actions from GitHub Marketplace

**Repository Locations:**
- `09-cicd/github-actions-ct/`: Chart testing workflows
- `09-cicd/github-actions-helm-oci/`: Helm OCI publishing workflows
- `09-cicd/deploy-to-gke/`: GKE deployment workflows
- `.github/workflows/`: Actual workflow files

**Key Configuration:**
```yaml
# GitHub Secrets (add to repository settings)
GCP_PROJECT: my-project-id
WIF_PROVIDER: projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github/providers/github
WIF_SERVICE_ACCOUNT: github-actions@PROJECT_ID.iam.gserviceaccount.com
GKE_CLUSTER: my-cluster
GKE_REGION: us-central1

# Workflow trigger
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
```

**Where Costs Accrue:**
- **GitHub Actions**: 2000 minutes/month free (private repos), unlimited for public
- **Artifact Registry**: $0.10/GB/month storage
- **GKE**: Cluster costs (already running)
- **Cloud Build**: Not used (GitHub Actions instead)

**Cost Example:**
- GitHub Actions (within free tier): $0/month
- Artifact Registry (10 GB): ~$1/month
- **Total: ~$1/month**

## How

### Quickstart: Setup Workload Identity Federation

```bash
# 1. Set variables
export PROJECT_ID=$(gcloud config get-value project)
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")
export GITHUB_REPO="owner/repo"  # Replace with your repo

# 2. Create service account for GitHub Actions
gcloud iam service-accounts create github-actions \
  --display-name="GitHub Actions"

# 3. Grant permissions
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:github-actions@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/container.developer"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:github-actions@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/artifactregistry.writer"

# 4. Create Workload Identity Pool
gcloud iam workload-identity-pools create github \
  --location="global" \
  --display-name="GitHub Actions"

# 5. Create Workload Identity Provider
gcloud iam workload-identity-pools providers create-oidc github \
  --location="global" \
  --workload-identity-pool="github" \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository"

# 6. Allow GitHub Actions to impersonate service account
gcloud iam service-accounts add-iam-policy-binding \
  github-actions@${PROJECT_ID}.iam.gserviceaccount.com \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/github/attribute.repository/${GITHUB_REPO}"

# 7. Get Workload Identity Provider name (add to GitHub secrets)
echo "WIF_PROVIDER: projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/github/providers/github"
echo "WIF_SERVICE_ACCOUNT: github-actions@${PROJECT_ID}.iam.gserviceaccount.com"
```

### Quickstart: Create Lint Workflow

```bash
# Create .github/workflows/lint.yaml
mkdir -p .github/workflows
cat > .github/workflows/lint.yaml <<'EOF'
name: Lint Helm Charts

on:
  pull_request:
    paths:
      - 'charts/**'
  push:
    branches:
      - main
    paths:
      - 'charts/**'

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Helm
        uses: azure/setup-helm@v3
        with:
          version: v3.13.0

      - name: Lint charts
        run: |
          for chart in charts/*; do
            if [ -d "$chart" ]; then
              echo "Linting $chart"
              helm lint "$chart"
            fi
          done
EOF

# Commit and push
git add .github/workflows/lint.yaml
git commit -m "Add Helm chart linting workflow"
git push
```

### Quickstart: Create Deploy Workflow

```bash
# Create .github/workflows/deploy.yaml
cat > .github/workflows/deploy.yaml <<'EOF'
name: Deploy to GKE

on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy to'
        required: true
        type: choice
        options:
          - dev
          - staging
          - production
      version:
        description: 'Chart version to deploy'
        required: true
        type: string

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment }}
    permissions:
      contents: read
      id-token: write

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Helm
        uses: azure/setup-helm@v3
        with:
          version: v3.13.0

      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v1
        with:
          workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
          service_account: ${{ secrets.WIF_SERVICE_ACCOUNT }}

      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v1

      - name: Get GKE credentials
        run: |
          gcloud container clusters get-credentials ${{ secrets.GKE_CLUSTER }} \
            --region ${{ secrets.GKE_REGION }} \
            --project ${{ secrets.GCP_PROJECT }}

      - name: Deploy with Helm
        run: |
          helm upgrade --install my-app charts/my-app \
            --namespace ${{ inputs.environment }} \
            --create-namespace \
            --values charts/my-app/values-${{ inputs.environment }}.yaml \
            --wait \
            --timeout 10m

      - name: Verify deployment
        run: |
          kubectl rollout status deployment/my-app -n ${{ inputs.environment }}
          kubectl get pods -n ${{ inputs.environment }}
EOF

# Commit and push
git add .github/workflows/deploy.yaml
git commit -m "Add GKE deployment workflow"
git push
```

### Verify

```bash
# Check GitHub Actions workflows
# Go to: https://github.com/OWNER/REPO/actions

# Check Workload Identity setup
gcloud iam workload-identity-pools describe github --location=global

# Check service account permissions
gcloud projects get-iam-policy $PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:github-actions@*"

# Test workflow manually
# Go to: https://github.com/OWNER/REPO/actions/workflows/deploy.yaml
# Click "Run workflow"
```

### Cleanup

```bash
# Delete Workload Identity Pool (deletes provider too)
gcloud iam workload-identity-pools delete github --location=global --quiet

# Delete service account
gcloud iam service-accounts delete github-actions@${PROJECT_ID}.iam.gserviceaccount.com --quiet

# Delete workflows from repository
rm -rf .github/workflows/
git add .github/
git commit -m "Remove CI/CD workflows"
git push
```

## Overview

This section covers:
- GitHub Actions for CI/CD
- Helm chart testing and linting
- Publishing charts to Artifact Registry
- Automated deployments to GKE
- Multi-environment workflows

## CI/CD Pipeline Stages

### 1. Lint and Test
- Helm lint
- values.schema.json validation
- Chart testing (ct)
- Unit tests

### 2. Build and Package
- Build Docker images
- Push to container registry
- Package Helm charts
- Push to Helm registry

### 3. Deploy
- Deploy to development
- Deploy to staging
- Deploy to production (with approval)

## GitHub Actions Workflows

### Helm Chart Linting

**.github/workflows/lint.yaml:**
```yaml
name: Lint Helm Charts

on:
  pull_request:
    paths:
      - 'charts/**'
  push:
    branches:
      - main
    paths:
      - 'charts/**'

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Set up Helm
        uses: azure/setup-helm@v3
        with:
          version: v3.13.0

      - name: Lint charts
        run: |
          for chart in charts/*; do
            if [ -d "$chart" ]; then
              echo "Linting $chart"
              helm lint "$chart"
            fi
          done

      - name: Install chart-testing
        uses: helm/chart-testing-action@v2

      - name: Run chart-testing (lint)
        run: ct lint --config .github/ct.yaml
```

### Build and Push Docker Image

**.github/workflows/build.yaml:**
```yaml
name: Build and Push Image

on:
  push:
    branches:
      - main
    tags:
      - 'v*'

env:
  REGISTRY: gcr.io
  IMAGE_NAME: ${{ secrets.GCP_PROJECT }}/my-app

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v1
        with:
          workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
          service_account: ${{ secrets.WIF_SERVICE_ACCOUNT }}

      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v1

      - name: Configure Docker
        run: gcloud auth configure-docker

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=ref,event=branch
            type=ref,event=pr
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=sha

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
```

### Package and Push Helm Chart

**.github/workflows/release-chart.yaml:**
```yaml
name: Release Helm Chart

on:
  push:
    tags:
      - 'chart-v*'

env:
  REGISTRY: us-central1-docker.pkg.dev
  PROJECT_ID: ${{ secrets.GCP_PROJECT }}
  REPO_NAME: helm-charts

jobs:
  release:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Helm
        uses: azure/setup-helm@v3
        with:
          version: v3.13.0

      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v1
        with:
          workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
          service_account: ${{ secrets.WIF_SERVICE_ACCOUNT }}

      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v1

      - name: Configure Helm
        run: |
          gcloud auth configure-docker ${{ env.REGISTRY }}
          helm registry login ${{ env.REGISTRY }}

      - name: Package chart
        run: |
          helm package charts/my-app

      - name: Push chart
        run: |
          helm push my-app-*.tgz oci://${{ env.REGISTRY }}/${{ env.PROJECT_ID }}/${{ env.REPO_NAME }}
```

### Deploy to GKE

**.github/workflows/deploy.yaml:**
```yaml
name: Deploy to GKE

on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy to'
        required: true
        type: choice
        options:
          - dev
          - staging
          - production
      version:
        description: 'Chart version to deploy'
        required: true
        type: string

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment }}
    permissions:
      contents: read
      id-token: write

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Helm
        uses: azure/setup-helm@v3
        with:
          version: v3.13.0

      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v1
        with:
          workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
          service_account: ${{ secrets.WIF_SERVICE_ACCOUNT }}

      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v1

      - name: Get GKE credentials
        run: |
          gcloud container clusters get-credentials ${{ secrets.GKE_CLUSTER }} \
            --region ${{ secrets.GKE_REGION }} \
            --project ${{ secrets.GCP_PROJECT }}

      - name: Deploy with Helm
        run: |
          helm upgrade --install my-app \
            oci://${{ env.REGISTRY }}/${{ secrets.GCP_PROJECT }}/helm-charts/my-app \
            --version ${{ inputs.version }} \
            --namespace ${{ inputs.environment }} \
            --create-namespace \
            --values charts/my-app/values-${{ inputs.environment }}.yaml \
            --wait \
            --timeout 10m

      - name: Verify deployment
        run: |
          kubectl rollout status deployment/my-app -n ${{ inputs.environment }}
          kubectl get pods -n ${{ inputs.environment }}
```

### Complete CI/CD Pipeline

**.github/workflows/ci-cd.yaml:**
```yaml
name: CI/CD Pipeline

on:
  push:
    branches:
      - main
  pull_request:
    branches:
      - main

env:
  REGISTRY: gcr.io
  IMAGE_NAME: ${{ secrets.GCP_PROJECT }}/my-app

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Helm
        uses: azure/setup-helm@v3

      - name: Lint charts
        run: helm lint charts/my-app

  test:
    runs-on: ubuntu-latest
    needs: lint
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'

      - name: Install dependencies
        run: |
          pip install -r requirements.txt
          pip install pytest pytest-cov

      - name: Run tests
        run: pytest --cov=app tests/

  build:
    runs-on: ubuntu-latest
    needs: test
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    permissions:
      contents: read
      id-token: write
    outputs:
      image-tag: ${{ steps.meta.outputs.version }}

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v1
        with:
          workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
          service_account: ${{ secrets.WIF_SERVICE_ACCOUNT }}

      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v1

      - name: Configure Docker
        run: gcloud auth configure-docker

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=sha,prefix={{branch}}-

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}

  deploy-dev:
    runs-on: ubuntu-latest
    needs: build
    environment: dev
    permissions:
      contents: read
      id-token: write

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Helm
        uses: azure/setup-helm@v3

      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v1
        with:
          workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
          service_account: ${{ secrets.WIF_SERVICE_ACCOUNT }}

      - name: Get GKE credentials
        run: |
          gcloud container clusters get-credentials ${{ secrets.GKE_CLUSTER }} \
            --region ${{ secrets.GKE_REGION }}

      - name: Deploy to dev
        run: |
          helm upgrade --install my-app charts/my-app \
            --namespace dev \
            --create-namespace \
            --values charts/my-app/values-dev.yaml \
            --set image.tag=${{ needs.build.outputs.image-tag }} \
            --wait

  deploy-staging:
    runs-on: ubuntu-latest
    needs: deploy-dev
    environment: staging
    permissions:
      contents: read
      id-token: write

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Helm
        uses: azure/setup-helm@v3

      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v1
        with:
          workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
          service_account: ${{ secrets.WIF_SERVICE_ACCOUNT }}

      - name: Get GKE credentials
        run: |
          gcloud container clusters get-credentials ${{ secrets.GKE_CLUSTER }} \
            --region ${{ secrets.GKE_REGION }}

      - name: Deploy to staging
        run: |
          helm upgrade --install my-app charts/my-app \
            --namespace staging \
            --create-namespace \
            --values charts/my-app/values-staging.yaml \
            --set image.tag=${{ needs.build.outputs.image-tag }} \
            --wait
```

## Chart Testing Configuration

**.github/ct.yaml:**
```yaml
remote: origin
target-branch: main
chart-dirs:
  - charts
chart-repos:
  - bitnami=https://charts.bitnami.com/bitnami
helm-extra-args: --timeout 600s
check-version-increment: true
validate-maintainers: true
```

## Workload Identity for GitHub Actions

### Setup

```bash
# Create service account
gcloud iam service-accounts create github-actions \
  --display-name="GitHub Actions"

# Grant permissions
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:github-actions@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/container.developer"

gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:github-actions@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/artifactregistry.writer"

# Create Workload Identity Pool
gcloud iam workload-identity-pools create github \
  --location="global" \
  --display-name="GitHub Actions"

# Create Workload Identity Provider
gcloud iam workload-identity-pools providers create-oidc github \
  --location="global" \
  --workload-identity-pool="github" \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository"

# Allow GitHub Actions to impersonate service account
gcloud iam service-accounts add-iam-policy-binding \
  github-actions@PROJECT_ID.iam.gserviceaccount.com \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github/attribute.repository/OWNER/REPO"
```

### GitHub Secrets

Add these secrets to your GitHub repository:

- `GCP_PROJECT`: Your GCP project ID
- `WIF_PROVIDER`: `projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github/providers/github`
- `WIF_SERVICE_ACCOUNT`: `github-actions@PROJECT_ID.iam.gserviceaccount.com`
- `GKE_CLUSTER`: Your GKE cluster name
- `GKE_REGION`: Your GKE cluster region

## Best Practices

### 1. Use Workload Identity

Don't use service account keys. Use Workload Identity Federation.

### 2. Test Before Deploy

Always run tests before deploying:
```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - run: pytest
  
  deploy:
    needs: test  # Only deploy if tests pass
```

### 3. Use Environments

```yaml
jobs:
  deploy-prod:
    environment: production  # Requires approval
```

### 4. Pin Versions

```yaml
- uses: actions/checkout@v4  # Not @main
- uses: azure/setup-helm@v3
  with:
    version: v3.13.0  # Specific version
```

### 5. Use Secrets

```yaml
env:
  PROJECT_ID: ${{ secrets.GCP_PROJECT }}  # Not hardcoded
```

### 6. Validate Charts

```yaml
- name: Validate
  run: |
    helm lint charts/my-app
    helm template charts/my-app | kubectl apply --dry-run=client -f -
```

### 7. Use Helm Hooks

```yaml
# templates/tests/test-connection.yaml
apiVersion: v1
kind: Pod
metadata:
  name: "{{ include "app.fullname" . }}-test"
  annotations:
    "helm.sh/hook": test
spec:
  containers:
  - name: wget
    image: busybox
    command: ['wget']
    args: ['{{ include "app.fullname" . }}:{{ .Values.service.port }}']
  restartPolicy: Never
```

### 8. Implement Rollback

```yaml
- name: Deploy
  id: deploy
  run: helm upgrade --install ...

- name: Rollback on failure
  if: failure() && steps.deploy.outcome == 'failure'
  run: helm rollback my-app
```

## Troubleshooting

### Authentication Failed

```bash
# Check Workload Identity setup
gcloud iam workload-identity-pools describe github --location=global

# Check service account permissions
gcloud projects get-iam-policy PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:github-actions@*"
```

### Helm Install Failed

```bash
# Check chart syntax
helm lint charts/my-app

# Dry-run
helm install my-app charts/my-app --dry-run --debug

# Check cluster access
kubectl cluster-info
kubectl get nodes
```

### Image Pull Failed

```bash
# Check image exists
gcloud container images list --repository=gcr.io/PROJECT_ID

# Check permissions
gcloud projects get-iam-policy PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:*"
```

## Next Steps

1. Set up [github-actions-ct](./github-actions-ct) for chart testing
2. Configure [github-actions-helm-oci](./github-actions-helm-oci) for publishing
3. Implement [deploy-to-gke](./deploy-to-gke) for automated deployments

## Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Helm Chart Testing](https://github.com/helm/chart-testing)
- [Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation)
- [GKE CI/CD Best Practices](https://cloud.google.com/kubernetes-engine/docs/tutorials/gitops-cloud-build)
