# Datastores - SQL and NoSQL on GKE

## What

Comprehensive guide to deploying and connecting to SQL and NoSQL databases on GKE, covering both in-cluster databases (free, for development) and managed GCP services (Cloud SQL, Firestore, Datastore, Memorystore). Includes connection patterns with Workload Identity and Cloud SQL proxy sidecar.

**Resources Created:**
- In-cluster databases: PostgreSQL, MySQL, Redis (using Bitnami Helm charts)
- Cloud SQL instances: PostgreSQL, MySQL (managed)
- Firestore/Datastore databases (NoSQL, serverless)
- Cloud SQL proxy sidecar containers
- ServiceAccount with Workload Identity for GCP service access
- Secrets for database credentials

## Why

**Why Database Integration Matters:**
- **Data Persistence**: Applications need to store and retrieve data reliably
- **Scalability**: Databases must handle growing data and traffic
- **High Availability**: Production databases need backups, replication, and failover
- **Security**: Protect sensitive data with encryption and access controls
- **Performance**: Choose the right database type (SQL vs NoSQL) for your use case
- **Cost Efficiency**: Balance managed services vs self-hosted based on needs

**Why Use In-Cluster Databases:**
- **Free**: Only costs cluster resources (minimal with small PVCs)
- **Fast**: Local access, no network latency
- **Simple**: Easy to deploy with Helm charts
- **Learning**: Great for development and testing
- **Control**: Full control over configuration

**Why Use Managed Databases:**
- **Fully Managed**: Automatic backups, patching, HA, monitoring
- **Production-Ready**: Enterprise-grade reliability and performance
- **Scalability**: Easy to scale up/down as needed
- **Security**: Built-in encryption, IAM integration, audit logging
- **Less Operational Overhead**: Focus on application, not database management

**Trade-offs:**
- **In-Cluster**: Free but you manage everything (backups, HA, scaling)
- **Managed**: Costs money but fully managed and production-ready
- **Cloud SQL**: More expensive but better for production
- **Firestore**: Serverless and scalable but NoSQL (different data model)

**Alternatives:**
- **Cloud Spanner**: Global SQL database (expensive, for large scale)
- **BigQuery**: Data warehouse (analytics, not transactional)
- **Cloud Bigtable**: NoSQL for massive scale (expensive)
- **AlloyDB**: PostgreSQL-compatible, high performance (expensive)

## When

**Use In-Cluster Databases When:**
- Development and testing environments
- Learning and prototyping
- Small applications with minimal data
- Cost is a primary concern (free tier)
- Don't need managed backups or HA

**Use Cloud SQL When:**
- Production environments
- Need managed backups and HA
- Require point-in-time recovery
- Want automatic patching and updates
- Need to scale compute and storage independently

**Use Firestore/Datastore When:**
- Need NoSQL document or key-value storage
- Building real-time applications
- Need automatic scaling
- Want serverless (no infrastructure management)
- Have flexible schema requirements

**Use Redis When:**
- Need caching layer
- Session storage
- Real-time analytics
- Message queuing
- Leaderboards or counters

**Prerequisites:**
- Completed 00-prereqs (GKE cluster, Workload Identity setup)
- For Cloud SQL: Cloud SQL Admin API enabled
- For Firestore: Firestore API enabled
- GCP service account with appropriate IAM roles
- Understanding of SQL vs NoSQL concepts

**When NOT to Use:**
- Don't use in-cluster databases for production (unless you have expertise)
- Don't use managed services if staying within free tier is critical
- Don't use SQL for unstructured data (use NoSQL)
- Don't use NoSQL for complex transactions (use SQL)

**Learning Sequence:**
1. **in-cluster-postgresql**: Free PostgreSQL (20 minutes)
2. **firestore**: NoSQL with free tier (20 minutes)
3. **cloud-sql-postgres-proxy**: Managed PostgreSQL (30 minutes)
4. **redis**: Caching layer (15 minutes)
**Total Time**: ~1.5 hours

## Where

**GCP Services:**
- **Cloud SQL**: Managed PostgreSQL and MySQL
- **Firestore**: NoSQL document database (Native mode)
- **Cloud Datastore**: NoSQL key-value database
- **Memorystore**: Managed Redis (optional, expensive)
- **Cloud SQL Admin API**: Required for Cloud SQL proxy
- **Workload Identity**: Secure pod-to-GCP authentication

**IAM Roles Required:**
- **Cloud SQL**:
  - `roles/cloudsql.client`: Connect via proxy
  - `roles/cloudsql.admin`: Create and manage instances (setup)
- **Firestore/Datastore**:
  - `roles/datastore.user`: Read and write data
  - `roles/datastore.viewer`: Read-only access
- **Secret Manager** (optional):
  - `roles/secretmanager.secretAccessor`: Read database credentials

**Kubernetes Resources:**
- **Namespace**: Any namespace (default, production, etc.)
- **StatefulSet**: For in-cluster databases (PostgreSQL, MySQL, Redis)
- **PersistentVolumeClaim**: Storage for in-cluster databases
- **Service**: Expose databases within cluster
- **Deployment**: For applications with Cloud SQL proxy sidecar
- **ServiceAccount**: With Workload Identity annotations
- **Secret**: Store database credentials

**Repository Locations:**
- `06-datastores/in-cluster-postgresql/`: Bitnami PostgreSQL chart
- `06-datastores/cloud-sql-postgres-proxy/`: Cloud SQL with proxy sidecar
- `06-datastores/cloud-sql-mysql-proxy/`: Cloud SQL MySQL
- `06-datastores/firestore/`: Firestore examples
- `06-datastores/datastore/`: Datastore examples
- `06-datastores/redis/`: In-cluster Redis and Memorystore notes

**Key Values to Set:**
```yaml
# In-cluster PostgreSQL
postgresql:
  auth:
    username: myuser
    password: mypassword
    database: mydb
  primary:
    persistence:
      size: 1Gi  # Small for learning

# Cloud SQL proxy
cloudsql:
  instance: "PROJECT:REGION:INSTANCE"
  port: 5432

# Firestore
firestore:
  projectId: my-project-id
  # No credentials needed with Workload Identity

# Redis
redis:
  auth:
    password: mypassword
  master:
    persistence:
      size: 1Gi
```

**Where Costs Accrue:**
- **In-Cluster Databases**: Only cluster resources (minimal)
  - 1 GB PVC: ~$0.04/month (standard disk)
  - 250m CPU, 512Mi RAM: ~$0.03/hour = ~$22/month
- **Cloud SQL**:
  - db-f1-micro (shared CPU): ~$7-10/month
  - 10 GB storage: ~$1.70/month
  - **Total: ~$10/month from trial credits**
- **Firestore**:
  - 1 GB storage free, then $0.18/GB/month
  - 50K reads, 20K writes, 20K deletes per day free
  - Beyond free tier: $0.06 per 100K reads
- **Memorystore**:
  - 1 GB instance: ~$35/month (expensive!)
  - **Use in-cluster Redis for learning**

**Cost Example (Learning Setup):**
- In-cluster PostgreSQL + Redis: ~$22/month (cluster resources only)
- Cloud SQL (trial): ~$10/month (from $300 trial credits)
- Firestore (free tier): $0/month (stay within limits)
- **Total: ~$22/month + trial credits**

## How

### Quickstart: In-Cluster PostgreSQL (Free)

```bash
# 1. Add Bitnami repo
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# 2. Install PostgreSQL
helm install postgresql bitnami/postgresql \
  --set auth.username=myuser \
  --set auth.password=mypassword \
  --set auth.database=mydb \
  --set primary.persistence.size=1Gi \
  --set primary.resources.requests.cpu=100m \
  --set primary.resources.requests.memory=128Mi

# 3. Get connection info
export POSTGRES_PASSWORD=$(kubectl get secret postgresql -o jsonpath="{.data.postgres-password}" | base64 -d)
echo "Host: postgresql.default.svc.cluster.local"
echo "Port: 5432"
echo "User: myuser"
echo "Password: $POSTGRES_PASSWORD"

# 4. Test connection
kubectl run postgresql-client --rm --tty -i --restart='Never' \
  --image docker.io/bitnami/postgresql:14 \
  --env="PGPASSWORD=$POSTGRES_PASSWORD" \
  --command -- psql --host postgresql -U myuser -d mydb -p 5432
```

### Quickstart: Cloud SQL with Proxy Sidecar

```bash
# 1. Create Cloud SQL instance (takes 5-10 minutes)
gcloud sql instances create my-postgres \
  --database-version=POSTGRES_14 \
  --tier=db-f1-micro \
  --region=$REGION

# 2. Set password
gcloud sql users set-password postgres \
  --instance=my-postgres \
  --password=mypassword

# 3. Create database
gcloud sql databases create mydb --instance=my-postgres

# 4. Grant Cloud SQL client role to GSA
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:my-app-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/cloudsql.client"

# 5. Deploy app with proxy sidecar
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-with-cloudsql
spec:
  replicas: 1
  selector:
    matchLabels:
      app: app-with-cloudsql
  template:
    metadata:
      labels:
        app: app-with-cloudsql
    spec:
      serviceAccountName: my-app-ksa  # Workload Identity
      containers:
      - name: app
        image: nginx:1.21
        env:
        - name: DB_HOST
          value: "127.0.0.1"  # Localhost!
        - name: DB_PORT
          value: "5432"
        - name: DB_USER
          value: "postgres"
        - name: DB_PASSWORD
          value: "mypassword"  # Use Secret in production
        - name: DB_NAME
          value: "mydb"
      - name: cloud-sql-proxy
        image: gcr.io/cloud-sql-connectors/cloud-sql-proxy:2.8.0
        args:
        - "--structured-logs"
        - "--port=5432"
        - "${PROJECT_ID}:${REGION}:my-postgres"
        securityContext:
          runAsNonRoot: true
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
EOF
```

### Quickstart: Firestore (Free Tier)

```bash
# 1. Enable Firestore API
gcloud services enable firestore.googleapis.com

# 2. Create Firestore database (Native mode)
gcloud firestore databases create --region=$REGION

# 3. Grant Datastore user role to GSA
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:my-app-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/datastore.user"

# 4. Deploy app with Workload Identity
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-with-firestore
spec:
  replicas: 1
  selector:
    matchLabels:
      app: app-with-firestore
  template:
    metadata:
      labels:
        app: app-with-firestore
    spec:
      serviceAccountName: my-app-ksa  # Workload Identity
      containers:
      - name: app
        image: nginx:1.21
        env:
        - name: GCP_PROJECT
          value: "${PROJECT_ID}"
        # No credentials needed! Workload Identity handles it
EOF

# 5. Test with Python (see python-examples/nosql/firestore_example.py)
```

### Verify

```bash
# Check in-cluster PostgreSQL
kubectl get pods -l app.kubernetes.io/name=postgresql
kubectl get svc postgresql
kubectl get pvc -l app.kubernetes.io/name=postgresql

# Check Cloud SQL instance
gcloud sql instances list
gcloud sql instances describe my-postgres

# Check Cloud SQL proxy
kubectl get pods -l app=app-with-cloudsql
kubectl logs -l app=app-with-cloudsql -c cloud-sql-proxy

# Check Firestore
gcloud firestore databases list

# Check Workload Identity
kubectl get sa my-app-ksa -o yaml | grep iam.gke.io
```

### Cleanup

```bash
# Delete in-cluster PostgreSQL
helm uninstall postgresql
kubectl delete pvc data-postgresql-0

# Delete Cloud SQL instance (IMPORTANT to avoid charges)
gcloud sql instances delete my-postgres --quiet

# Delete Firestore database (optional, has free tier)
# Note: Firestore databases cannot be deleted, only data can be cleared

# Delete deployments
kubectl delete deployment app-with-cloudsql app-with-firestore
```

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
