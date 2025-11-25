# Datastores - SQL and NoSQL on GKE

Learn how to deploy and connect to SQL and NoSQL databases on GKE, both in-cluster and managed services.

## Overview

This section covers:
- In-cluster databases (free, for development)
- Cloud SQL with proxy sidecar (managed, uses trial credits)
- Firestore and Datastore (NoSQL, serverless)
- Redis (in-cluster and Memorystore)

## Database Options

### In-Cluster Databases (Free Tier Friendly)

**Pros:**
- No additional cost beyond cluster resources
- Fast local access
- Good for development and testing
- Full control

**Cons:**
- You manage backups and HA
- Limited by cluster resources
- Not recommended for production

**Examples:**
- PostgreSQL (Bitnami chart)
- MySQL (Bitnami chart)
- Redis (Bitnami chart)
- MongoDB (Bitnami chart)

### Managed Databases (Uses Trial Credits)

**Pros:**
- Fully managed (backups, HA, patching)
- Better for production
- Automatic scaling
- Built-in monitoring

**Cons:**
- Costs money (uses trial credits)
- Requires Cloud SQL proxy for secure access
- More complex setup

**Examples:**
- Cloud SQL (PostgreSQL, MySQL)
- Firestore (NoSQL document database)
- Cloud Datastore (NoSQL key-value)
- Memorystore (managed Redis)

## Sections

### [in-cluster-postgresql](./in-cluster-postgresql)
Deploy PostgreSQL using Bitnami Helm chart. Free, runs in your cluster.

### [cloud-sql-postgres-proxy](./cloud-sql-postgres-proxy)
Connect to Cloud SQL PostgreSQL using proxy sidecar pattern with Workload Identity.

### [cloud-sql-mysql-proxy](./cloud-sql-mysql-proxy)
Connect to Cloud SQL MySQL using proxy sidecar pattern.

### [firestore](./firestore)
Use Firestore Native mode for NoSQL document storage with Workload Identity.

### [datastore](./datastore)
Use Cloud Datastore for NoSQL key-value storage.

### [redis](./redis)
Deploy Redis in-cluster (Bitnami) or use Memorystore (managed).

## Quick Comparison

| Database | Type | Cost | Use Case | Setup Complexity |
|----------|------|------|----------|------------------|
| PostgreSQL (in-cluster) | SQL | Free | Dev/Test | Low |
| Cloud SQL PostgreSQL | SQL | Paid | Production | Medium |
| Cloud SQL MySQL | SQL | Paid | Production | Medium |
| Firestore | NoSQL | Free tier + paid | Real-time apps | Low |
| Datastore | NoSQL | Free tier + paid | Key-value storage | Low |
| Redis (in-cluster) | Cache | Free | Dev/Test | Low |
| Memorystore | Cache | Paid | Production | Medium |

## Connection Patterns

### Pattern 1: In-Cluster Direct Connection

```yaml
# Application connects directly to service
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
      value: postgresql.default.svc.cluster.local
    - name: DB_PORT
      value: "5432"
    - name: DB_USER
      valueFrom:
        secretKeyRef:
          name: postgresql
          key: username
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: postgresql
          key: password
```

### Pattern 2: Cloud SQL Proxy Sidecar

```yaml
# Application connects to localhost, proxy connects to Cloud SQL
apiVersion: v1
kind: Pod
metadata:
  name: app
spec:
  serviceAccountName: app-ksa  # Workload Identity
  containers:
  - name: app
    image: my-app:1.0
    env:
    - name: DB_HOST
      value: "127.0.0.1"  # Localhost!
    - name: DB_PORT
      value: "5432"
  - name: cloud-sql-proxy
    image: gcr.io/cloud-sql-connectors/cloud-sql-proxy:2.8.0
    args:
    - "--structured-logs"
    - "--port=5432"
    - "PROJECT:REGION:INSTANCE"
    securityContext:
      runAsNonRoot: true
```

### Pattern 3: Workload Identity for GCP Services

```yaml
# Application uses Workload Identity to access Firestore
apiVersion: v1
kind: Pod
metadata:
  name: app
spec:
  serviceAccountName: app-ksa  # Annotated with GCP SA
  containers:
  - name: app
    image: my-app:1.0
    env:
    - name: GCP_PROJECT
      value: "my-project"
    # No credentials needed! Workload Identity handles it
```

## Cost Management

### Free Tier Usage

**Firestore:**
- 1 GB storage free
- 50K reads, 20K writes, 20K deletes per day free
- Good for small applications

**Datastore:**
- 1 GB storage free
- 50K reads, 20K writes, 20K deletes per day free

**In-Cluster Databases:**
- Only costs cluster resources (minimal with small PVCs)
- Use small PVCs: 1-5 GB
- Set resource limits: 100m CPU, 256Mi memory

### Trial Credits Usage

**Cloud SQL:**
- Smallest instance: db-f1-micro (~$7-10/month)
- 10 GB storage (~$1.70/month)
- **Total: ~$10/month from trial credits**

**Memorystore:**
- Smallest instance: 1 GB (~$35/month)
- **Use in-cluster Redis for learning**

### Cost Savings Tips

1. **Use in-cluster for development**: Free and sufficient for learning
2. **Delete Cloud SQL when not in use**: Stop instances to save money
3. **Use Firestore free tier**: Stay within daily limits
4. **Set up billing alerts**: Get notified before spending too much
5. **Clean up regularly**: Run cleanup scripts

## Security Best Practices

### 1. Use Workload Identity

Never use service account keys. Always use Workload Identity:

```bash
# Create GCP SA
gcloud iam service-accounts create db-app-sa

# Grant permissions
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:db-app-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/cloudsql.client"

# Create K8s SA
kubectl create serviceaccount db-app-ksa

# Bind them
gcloud iam service-accounts add-iam-policy-binding \
  db-app-sa@${PROJECT_ID}.iam.gserviceaccount.com \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:${PROJECT_ID}.svc.id.goog[default/db-app-ksa]"

# Annotate K8s SA
kubectl annotate serviceaccount db-app-ksa \
  iam.gke.io/gcp-service-account=db-app-sa@${PROJECT_ID}.iam.gserviceaccount.com
```

### 2. Use Secrets for Credentials

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
type: Opaque
stringData:
  username: myuser
  password: mypassword  # Use strong passwords!
  database: mydb
```

### 3. Network Policies

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: db-access
spec:
  podSelector:
    matchLabels:
      app: postgresql
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: my-app
    ports:
    - protocol: TCP
      port: 5432
```

### 4. Least Privilege IAM

Grant only the permissions needed:

```bash
# Cloud SQL client (read/write)
roles/cloudsql.client

# Firestore user (read/write)
roles/datastore.user

# Firestore viewer (read-only)
roles/datastore.viewer
```

## Python Connection Examples

See [python-examples](../python-examples) for complete code:

- **PostgreSQL (in-cluster)**: psycopg2 with connection pooling
- **Cloud SQL PostgreSQL**: google-cloud-sql-connector with SQLAlchemy
- **Cloud SQL MySQL**: google-cloud-sql-connector with SQLAlchemy
- **Firestore**: google-cloud-firestore client
- **Datastore**: google-cloud-datastore client
- **Redis**: redis-py client

## Next Steps

1. Start with [in-cluster-postgresql](./in-cluster-postgresql) for free learning
2. Try [firestore](./firestore) for NoSQL with free tier
3. Explore [cloud-sql-postgres-proxy](./cloud-sql-postgres-proxy) for production patterns
4. Check [python-examples](../python-examples) for application code

## Resources

- [Cloud SQL Documentation](https://cloud.google.com/sql/docs)
- [Firestore Documentation](https://cloud.google.com/firestore/docs)
- [Cloud SQL Proxy](https://cloud.google.com/sql/docs/postgres/sql-proxy)
- [Workload Identity](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity)
- [Bitnami Charts](https://github.com/bitnami/charts)
