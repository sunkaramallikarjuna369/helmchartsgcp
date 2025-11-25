#!/bin/bash

set -e

echo "⚠️  WARNING: This will delete ALL resources created by this guide!"
echo "This includes:"
echo "  - GKE cluster"
echo "  - Artifact Registry repositories"
echo "  - Load Balancers"
echo "  - Cloud SQL instances"
echo "  - Persistent Disks"
echo "  - Service Accounts"
echo ""

if [ -z "$PROJECT_ID" ]; then
    echo "ERROR: PROJECT_ID environment variable is not set"
    echo "Please run: export PROJECT_ID=your-project-id"
    exit 1
fi

if [ -z "$REGION" ]; then
    echo "WARNING: REGION not set, using default: us-central1"
    export REGION="us-central1"
fi

CLUSTER_NAME="${CLUSTER_NAME:-helm-learning-cluster}"
REPO_NAME="${REPO_NAME:-helm-charts}"

echo "Configuration:"
echo "  Project ID: $PROJECT_ID"
echo "  Region: $REGION"
echo "  Cluster Name: $CLUSTER_NAME"
echo ""

read -p "Are you sure you want to delete all resources? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Cleanup cancelled"
    exit 0
fi

echo ""
echo "Starting cleanup..."
echo ""

echo "1. Deleting GKE cluster..."
gcloud container clusters delete $CLUSTER_NAME \
  --region=$REGION \
  --project=$PROJECT_ID \
  --quiet || echo "  Cluster not found or already deleted"

echo "✓ Cluster deleted"
echo ""

echo "2. Deleting Artifact Registry repository..."
gcloud artifacts repositories delete $REPO_NAME \
  --location=$REGION \
  --project=$PROJECT_ID \
  --quiet || echo "  Repository not found or already deleted"

echo "✓ Artifact Registry deleted"
echo ""

echo "3. Checking for Load Balancers..."
LBS=$(gcloud compute forwarding-rules list --project=$PROJECT_ID --format="value(name)" 2>/dev/null || echo "")
if [ -n "$LBS" ]; then
    echo "Found Load Balancers:"
    echo "$LBS"
    for lb in $LBS; do
        echo "  Deleting $lb..."
        gcloud compute forwarding-rules delete $lb --region=$REGION --project=$PROJECT_ID --quiet || true
    done
    echo "✓ Load Balancers deleted"
else
    echo "  No Load Balancers found"
fi
echo ""

echo "4. Checking for Cloud SQL instances..."
SQL_INSTANCES=$(gcloud sql instances list --project=$PROJECT_ID --format="value(name)" 2>/dev/null || echo "")
if [ -n "$SQL_INSTANCES" ]; then
    echo "Found Cloud SQL instances:"
    echo "$SQL_INSTANCES"
    for instance in $SQL_INSTANCES; do
        echo "  Deleting $instance..."
        gcloud sql instances delete $instance --project=$PROJECT_ID --quiet || true
    done
    echo "✓ Cloud SQL instances deleted"
else
    echo "  No Cloud SQL instances found"
fi
echo ""

echo "5. Checking for orphaned persistent disks..."
DISKS=$(gcloud compute disks list --project=$PROJECT_ID --format="value(name)" 2>/dev/null || echo "")
if [ -n "$DISKS" ]; then
    echo "Found persistent disks:"
    echo "$DISKS"
    echo "  Note: These may be in use. Skipping automatic deletion."
    echo "  To delete manually:"
    echo "    gcloud compute disks delete DISK_NAME --zone=ZONE"
else
    echo "  No orphaned disks found"
fi
echo ""

echo "6. Listing service accounts..."
echo "  Service accounts are not automatically deleted."
echo "  To delete manually:"
echo "    gcloud iam service-accounts delete SA_EMAIL --project=$PROJECT_ID"
gcloud iam service-accounts list --project=$PROJECT_ID --format="value(email)" | grep -v "gserviceaccount.com$" || echo "  No custom service accounts found"
echo ""

echo "✓ Cleanup complete!"
echo ""
echo "Remaining manual steps:"
echo "  1. Check for any remaining resources:"
echo "     gcloud compute instances list --project=$PROJECT_ID"
echo "     gcloud compute disks list --project=$PROJECT_ID"
echo "     gcloud sql instances list --project=$PROJECT_ID"
echo ""
echo "  2. Check billing to ensure no ongoing charges:"
echo "     https://console.cloud.google.com/billing"
echo ""
echo "  3. Optionally delete the project:"
echo "     gcloud projects delete $PROJECT_ID"
