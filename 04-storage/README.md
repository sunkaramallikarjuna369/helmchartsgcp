# Storage - Persistent Storage on GKE

## What

Persistent storage solutions for stateful applications on GKE using GCE Persistent Disks, PersistentVolumes (PV), PersistentVolumeClaims (PVC), and StatefulSets. This creates Kubernetes storage resources that survive pod restarts and enable data persistence for databases, file storage, and stateful workloads.

**Resources Created:**
- StorageClass (defines storage type and parameters)
- PersistentVolume (actual storage allocation)
- PersistentVolumeClaim (storage request by pods)
- StatefulSet (manages stateful pods with stable identities)

## Why

**Why This Matters:**
- **Data Persistence**: Containers are ephemeral; storage ensures data survives pod restarts and rescheduling
- **Stateful Applications**: Databases, message queues, and file servers require persistent storage
- **Performance**: Different storage classes offer varying performance characteristics (SSD vs HDD)
- **Backup and Recovery**: Persistent disks can be snapshotted for backups
- **High Availability**: StatefulSets provide stable network identities and ordered deployment

**Trade-offs:**
- **Cost**: Persistent disks cost money (vs ephemeral storage which is free)
- **Complexity**: StatefulSets are more complex than Deployments
- **Performance**: Network-attached storage is slower than local SSDs
- **Portability**: GCE Persistent Disks are GCP-specific

**Alternatives:**
- EmptyDir volumes (ephemeral, free, but data lost on pod restart)
- HostPath volumes (not allowed in GKE Autopilot)
- Cloud Storage FUSE (for object storage needs)
- Filestore (managed NFS for shared storage)

## When

**Use Persistent Storage When:**
- Running databases (PostgreSQL, MySQL, MongoDB)
- Storing application state or user uploads
- Running message queues (RabbitMQ, Kafka)
- Need data to survive pod restarts
- Running stateful applications requiring stable network identities

**Prerequisites:**
- GKE cluster created (00-prereqs completed)
- Compute Engine API enabled
- Understanding of Kubernetes storage concepts
- Cost awareness (persistent disks are billed)

**When NOT to Use:**
- For temporary/cache data (use emptyDir)
- For shared file systems (use Filestore instead)
- For object storage (use Cloud Storage)
- For read-only configuration (use ConfigMaps)
- In development with no data persistence needs

**Sequencing:**
1. Complete 00-prereqs (GKE cluster setup)
2. Understand storage requirements (size, performance, access mode)
3. Create StorageClass (if custom parameters needed)
4. Create PVC (requests storage)
5. Mount PVC in Pod/StatefulSet
6. Verify data persistence

## Where

**GCP Services:**
- **Compute Engine Persistent Disks**: Block storage for GKE
- **Compute Engine API**: Required for disk operations
- **GKE Storage Classes**: Pre-configured storage types
  - `standard-rwo`: HDD, ReadWriteOnce (default)
  - `premium-rwo`: SSD, ReadWriteOnce
  - `standard-rwx`: HDD, ReadWriteMany (Filestore)

**IAM Roles Required:**
- `roles/compute.storageAdmin`: Create and manage disks
- `roles/container.developer`: Deploy workloads with PVCs
- Typically granted to node service account automatically

**Kubernetes Resources:**
- **Namespace**: Any namespace (default, production, etc.)
- **Resources Created**:
  - StorageClass (cluster-scoped)
  - PersistentVolume (cluster-scoped, auto-created)
  - PersistentVolumeClaim (namespace-scoped)
  - StatefulSet or Deployment (namespace-scoped)

**Repository Locations:**
- `04-storage/storageclass-gcepd/`: Custom StorageClass examples
- `04-storage/pv-pvc/`: PV and PVC examples
- `04-storage/statefulsets/`: StatefulSet examples with storage

**Key Values to Set:**
```yaml
# StorageClass
provisioner: pd.csi.storage.gke.io
type: pd-standard  # or pd-ssd, pd-balanced
replication-type: none  # or regional-pd

# PVC
storageClassName: standard-rwo
accessModes: [ReadWriteOnce]  # or ReadWriteMany
storage: 10Gi

# StatefulSet
volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: [ReadWriteOnce]
      storageClassName: premium-rwo
      resources:
        requests:
          storage: 10Gi
```

**Where Costs Accrue:**
- **Persistent Disk Storage**: $0.04/GB/month (standard), $0.17/GB/month (SSD)
- **Snapshots**: $0.026/GB/month
- **Regional Persistent Disks**: 2x cost for replication
- **IOPS and Throughput**: Included in disk cost
- **Free Tier**: None for persistent disks

**Cost Example:**
- 10 GB standard disk: ~$0.40/month
- 10 GB SSD disk: ~$1.70/month
- 100 GB standard disk: ~$4/month

## How

### Quickstart: Simple PVC with Deployment

```bash
# Set environment variables
export NAMESPACE=default

# Create PVC
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-app-data
  namespace: $NAMESPACE
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: standard-rwo
  resources:
    requests:
      storage: 10Gi
EOF

# Create Deployment using PVC
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  namespace: $NAMESPACE
spec:
  replicas: 1
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
      - name: app
        image: nginx:1.21
        volumeMounts:
        - name: data
          mountPath: /data
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: my-app-data
EOF
```

### Quickstart: StatefulSet with Storage

```bash
# Create StatefulSet with volumeClaimTemplates
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  namespace: $NAMESPACE
spec:
  serviceName: postgres
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:14
        env:
        - name: POSTGRES_PASSWORD
          value: changeme
        ports:
        - containerPort: 5432
          name: postgres
        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
        resources:
          requests:
            cpu: 250m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: [ReadWriteOnce]
      storageClassName: standard-rwo
      resources:
        requests:
          storage: 10Gi
EOF
```

### Verify

```bash
# Check PVC status
kubectl get pvc -n $NAMESPACE
# Should show STATUS: Bound

# Check PV (auto-created)
kubectl get pv
# Should show PV bound to your PVC

# Check pod is running
kubectl get pods -n $NAMESPACE

# Verify volume is mounted
kubectl exec -n $NAMESPACE POD_NAME -- df -h /data

# Test data persistence
kubectl exec -n $NAMESPACE POD_NAME -- sh -c "echo 'test data' > /data/test.txt"
kubectl delete pod POD_NAME -n $NAMESPACE
# Wait for pod to restart
kubectl exec -n $NAMESPACE NEW_POD_NAME -- cat /data/test.txt
# Should output: test data
```

### Cleanup

```bash
# Delete Deployment/StatefulSet
kubectl delete deployment my-app -n $NAMESPACE
# or
kubectl delete statefulset postgres -n $NAMESPACE

# Delete PVC (this deletes the PV and disk)
kubectl delete pvc my-app-data -n $NAMESPACE

# Verify disk is deleted
gcloud compute disks list --filter="name~gke-"

# Note: StatefulSet PVCs are NOT auto-deleted
# You must manually delete them:
kubectl delete pvc data-postgres-0 -n $NAMESPACE
```

## Storage Classes

### Default Storage Classes

GKE provides these pre-configured storage classes:

```yaml
# standard-rwo (default)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: standard-rwo
provisioner: pd.csi.storage.gke.io
parameters:
  type: pd-standard
  replication-type: none
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
```

**Available Types:**
- `standard-rwo`: HDD, ReadWriteOnce (cheapest)
- `premium-rwo`: SSD, ReadWriteOnce (faster)
- `balanced-rwo`: Balanced SSD (good price/performance)

### Custom Storage Class

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: pd.csi.storage.gke.io
parameters:
  type: pd-ssd
  replication-type: none
  fstype: ext4
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
reclaimPolicy: Delete
```

**Parameters:**
- `type`: pd-standard, pd-ssd, pd-balanced
- `replication-type`: none (zonal) or regional-pd (replicated)
- `fstype`: ext4 (default) or xfs
- `volumeBindingMode`: WaitForFirstConsumer (recommended) or Immediate
- `allowVolumeExpansion`: true (allows resizing)
- `reclaimPolicy`: Delete (default) or Retain

## Access Modes

**ReadWriteOnce (RWO):**
- Volume can be mounted read-write by a single node
- Most common mode
- Use for: Databases, single-instance applications
- GCE Persistent Disk supports this

**ReadWriteMany (RWX):**
- Volume can be mounted read-write by many nodes
- Requires Filestore (not regular persistent disks)
- Use for: Shared file systems, multi-pod writes
- More expensive

**ReadOnlyMany (ROX):**
- Volume can be mounted read-only by many nodes
- Rare use case
- Use for: Shared read-only data

## StatefulSets

StatefulSets provide:
- **Stable Network Identity**: Pods get predictable names (app-0, app-1, app-2)
- **Stable Storage**: Each pod gets its own PVC
- **Ordered Deployment**: Pods created/deleted in order
- **Ordered Scaling**: Scale up/down one at a time

**Use StatefulSets for:**
- Databases (PostgreSQL, MySQL, MongoDB)
- Distributed systems (Kafka, ZooKeeper, Cassandra)
- Applications requiring stable network identities
- Applications requiring persistent storage per replica

**Example:**
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web
spec:
  serviceName: web
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: nginx
        image: nginx:1.21
        ports:
        - containerPort: 80
          name: web
        volumeMounts:
        - name: www
          mountPath: /usr/share/nginx/html
  volumeClaimTemplates:
  - metadata:
      name: www
    spec:
      accessModes: [ReadWriteOnce]
      storageClassName: standard-rwo
      resources:
        requests:
          storage: 1Gi
```

This creates:
- Pods: web-0, web-1, web-2
- PVCs: www-web-0, www-web-1, www-web-2
- Each pod gets its own persistent storage

## Volume Expansion

Resize PVCs without downtime:

```bash
# Edit PVC to increase size
kubectl patch pvc my-app-data -n $NAMESPACE -p '{"spec":{"resources":{"requests":{"storage":"20Gi"}}}}'

# Check status
kubectl get pvc my-app-data -n $NAMESPACE
# Wait for CAPACITY to update

# For some filesystems, you may need to restart the pod
kubectl rollout restart deployment/my-app -n $NAMESPACE
```

**Requirements:**
- StorageClass must have `allowVolumeExpansion: true`
- Can only increase size (not decrease)
- Some filesystems require pod restart

## Snapshots and Backups

### Create Snapshot

```bash
# Create VolumeSnapshot
cat <<EOF | kubectl apply -f -
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: my-app-snapshot
  namespace: $NAMESPACE
spec:
  volumeSnapshotClassName: pd-snapshot
  source:
    persistentVolumeClaimName: my-app-data
EOF

# Check snapshot status
kubectl get volumesnapshot -n $NAMESPACE
```

### Restore from Snapshot

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-app-data-restored
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: standard-rwo
  resources:
    requests:
      storage: 10Gi
  dataSource:
    name: my-app-snapshot
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
```

## Best Practices

### 1. Use Appropriate Storage Class

```yaml
# Development: standard-rwo (HDD, cheap)
storageClassName: standard-rwo

# Production databases: premium-rwo (SSD, fast)
storageClassName: premium-rwo

# Balanced: balanced-rwo (good price/performance)
storageClassName: balanced-rwo
```

### 2. Set Resource Requests

```yaml
resources:
  requests:
    storage: 10Gi  # Start small, expand later
```

### 3. Use StatefulSets for Stateful Apps

```yaml
# Not this (Deployment with shared PVC)
kind: Deployment
replicas: 3  # All pods share one PVC - BAD

# This (StatefulSet with per-pod PVC)
kind: StatefulSet
replicas: 3  # Each pod gets own PVC - GOOD
volumeClaimTemplates: [...]
```

### 4. Enable Volume Expansion

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: expandable
allowVolumeExpansion: true  # Allow resizing
```

### 5. Use WaitForFirstConsumer

```yaml
volumeBindingMode: WaitForFirstConsumer  # Bind when pod scheduled
```

This ensures the disk is created in the same zone as the pod.

### 6. Set Reclaim Policy

```yaml
# Development: Delete (auto-delete disk)
reclaimPolicy: Delete

# Production: Retain (keep disk for manual cleanup)
reclaimPolicy: Retain
```

### 7. Monitor Storage Usage

```bash
# Check PVC usage
kubectl exec POD_NAME -- df -h /data

# Check disk usage
gcloud compute disks list --filter="name~gke-"
```

## Cost Optimization

### 1. Right-Size Storage

```yaml
# Start small
storage: 5Gi  # Not 100Gi if you only need 5Gi
```

### 2. Use Standard Disks for Non-Critical Data

```yaml
# Use HDD for logs, backups, non-critical data
storageClassName: standard-rwo  # $0.04/GB/month

# Use SSD only for databases and high-IOPS workloads
storageClassName: premium-rwo  # $0.17/GB/month
```

### 3. Delete Unused PVCs

```bash
# StatefulSet PVCs are NOT auto-deleted
kubectl get pvc -n $NAMESPACE
kubectl delete pvc UNUSED_PVC -n $NAMESPACE
```

### 4. Use Snapshots for Backups

```bash
# Snapshots are cheaper than keeping full disks
# $0.026/GB/month vs $0.04/GB/month for standard disks
```

### 5. Avoid Regional Disks Unless Needed

```yaml
# Zonal (cheaper)
replication-type: none

# Regional (2x cost, but HA)
replication-type: regional-pd
```

## GKE Autopilot Considerations

### Restrictions

- No hostPath volumes
- No local SSDs
- Minimum resource requests apply
- Storage is billed separately

### Supported

- PersistentVolumeClaims with GCE Persistent Disks
- StatefulSets
- Volume expansion
- Snapshots

## Troubleshooting

### PVC Stuck in Pending

```bash
# Check PVC events
kubectl describe pvc PVC_NAME -n $NAMESPACE

# Common issues:
# - No storage class found
# - Insufficient quota
# - Zone mismatch (use WaitForFirstConsumer)
```

### Pod Can't Mount Volume

```bash
# Check pod events
kubectl describe pod POD_NAME -n $NAMESPACE

# Common issues:
# - PVC not bound
# - Volume already mounted by another pod (RWO)
# - Node in different zone than disk
```

### Volume Expansion Not Working

```bash
# Check if expansion is allowed
kubectl get sc STORAGE_CLASS -o yaml | grep allowVolumeExpansion

# Check PVC conditions
kubectl describe pvc PVC_NAME -n $NAMESPACE

# May need to restart pod for filesystem resize
kubectl rollout restart deployment/APP_NAME -n $NAMESPACE
```

### Data Loss

```bash
# Check reclaim policy
kubectl get pv PV_NAME -o yaml | grep reclaimPolicy

# If Delete: PV and disk deleted when PVC deleted
# If Retain: PV and disk kept (manual cleanup needed)
```

## Sections

### [storageclass-gcepd](./storageclass-gcepd)
Custom StorageClass configurations for different performance and cost requirements.

### [pv-pvc](./pv-pvc)
PersistentVolume and PersistentVolumeClaim examples with various access modes.

### [statefulsets](./statefulsets)
StatefulSet examples for databases and stateful applications.

## Next Steps

1. Explore [storageclass-gcepd](./storageclass-gcepd) for custom storage configurations
2. Learn [pv-pvc](./pv-pvc) for manual volume provisioning
3. Deploy [statefulsets](./statefulsets) for stateful applications
4. Check [06-datastores](../06-datastores) for database examples using persistent storage

## Resources

- [Kubernetes Storage](https://kubernetes.io/docs/concepts/storage/)
- [GKE Persistent Volumes](https://cloud.google.com/kubernetes-engine/docs/concepts/persistent-volumes)
- [GCE Persistent Disks](https://cloud.google.com/compute/docs/disks)
- [StatefulSets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)
- [Volume Snapshots](https://kubernetes.io/docs/concepts/storage/volume-snapshots/)
