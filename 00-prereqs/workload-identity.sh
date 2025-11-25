#!/bin/bash

set -e

echo "Configuring Workload Identity..."

if [ -z "$PROJECT_ID" ]; then
    echo "ERROR: PROJECT_ID environment variable is not set"
    echo "Please run: export PROJECT_ID=your-project-id"
    exit 1
fi

GSA_NAME="${GSA_NAME:-app-service-account}"
KSA_NAME="${KSA_NAME:-app-ksa}"
NAMESPACE="${NAMESPACE:-default}"

echo "Configuration:"
echo "  Project ID: $PROJECT_ID"
echo "  GCP Service Account: $GSA_NAME"
echo "  Kubernetes Service Account: $KSA_NAME"
echo "  Namespace: $NAMESPACE"
echo ""

echo "Creating GCP service account..."
gcloud iam service-accounts create $GSA_NAME \
  --display-name="Application Service Account for Workload Identity" \
  --project=$PROJECT_ID

GSA_EMAIL="${GSA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
echo "✓ GCP service account created: $GSA_EMAIL"
echo ""

echo "Granting basic permissions..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${GSA_EMAIL}" \
  --role="roles/logging.logWriter"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${GSA_EMAIL}" \
  --role="roles/monitoring.metricWriter"

echo "✓ Basic permissions granted"
echo ""

echo "Creating Kubernetes service account..."
kubectl create serviceaccount $KSA_NAME -n $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

echo "✓ Kubernetes service account created"
echo ""

echo "Binding Kubernetes SA to GCP SA..."
gcloud iam service-accounts add-iam-policy-binding $GSA_EMAIL \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:${PROJECT_ID}.svc.id.goog[${NAMESPACE}/${KSA_NAME}]" \
  --project=$PROJECT_ID

echo "✓ Workload Identity binding created"
echo ""

echo "Annotating Kubernetes service account..."
kubectl annotate serviceaccount $KSA_NAME \
  -n $NAMESPACE \
  iam.gke.io/gcp-service-account=$GSA_EMAIL \
  --overwrite

echo "✓ Kubernetes service account annotated"
echo ""

echo "✓ Workload Identity configured successfully!"
echo ""
echo "Summary:"
echo "  GCP SA: $GSA_EMAIL"
echo "  K8s SA: $KSA_NAME (namespace: $NAMESPACE)"
echo ""
echo "To use in your pods, add:"
echo "  serviceAccountName: $KSA_NAME"
echo ""
echo "To grant additional permissions (example for Cloud SQL):"
echo "  gcloud projects add-iam-policy-binding $PROJECT_ID \\"
echo "    --member=\"serviceAccount:${GSA_EMAIL}\" \\"
echo "    --role=\"roles/cloudsql.client\""
echo ""
echo "To grant Firestore access:"
echo "  gcloud projects add-iam-policy-binding $PROJECT_ID \\"
echo "    --member=\"serviceAccount:${GSA_EMAIL}\" \\"
echo "    --role=\"roles/datastore.user\""
echo ""
echo "Setup complete! You're ready to deploy Helm charts."
