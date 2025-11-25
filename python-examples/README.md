# Python Examples - Database Connections

Python code examples for connecting to SQL and NoSQL databases from applications running on GKE.

## Overview

This section provides production-ready Python code for:
- PostgreSQL (in-cluster and Cloud SQL)
- MySQL (Cloud SQL)
- Firestore (NoSQL document database)
- Cloud Datastore (NoSQL key-value)
- Redis (in-cluster and Memorystore)

## Directory Structure

```
python-examples/
├── sql/
│   ├── postgresql_direct.py          # In-cluster PostgreSQL
│   ├── postgresql_cloudsql.py        # Cloud SQL with proxy
│   ├── mysql_cloudsql.py             # Cloud SQL MySQL
│   └── requirements.txt
└── nosql/
    ├── firestore_example.py          # Firestore operations
    ├── datastore_example.py          # Datastore operations
    ├── redis_example.py              # Redis operations
    └── requirements.txt
```

## SQL Examples

### PostgreSQL (In-Cluster)

**Use Case**: Development, testing, learning

**Connection Method**: Direct connection to PostgreSQL service in cluster

**Dependencies**:
```txt
psycopg2-binary==2.9.9
```

**Example**:
```python
import psycopg2
import os

# Get connection details from environment
DB_HOST = os.getenv('DB_HOST', 'postgresql.default.svc.cluster.local')
DB_PORT = os.getenv('DB_PORT', '5432')
DB_NAME = os.getenv('DB_NAME', 'mydb')
DB_USER = os.getenv('DB_USER', 'postgres')
DB_PASSWORD = os.getenv('DB_PASSWORD', 'password')

# Connect
conn = psycopg2.connect(
    host=DB_HOST,
    port=DB_PORT,
    database=DB_NAME,
    user=DB_USER,
    password=DB_PASSWORD
)

# Create table
with conn.cursor() as cur:
    cur.execute("""
        CREATE TABLE IF NOT EXISTS users (
            id SERIAL PRIMARY KEY,
            name VARCHAR(100),
            email VARCHAR(100),
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)
    conn.commit()

# Insert data
with conn.cursor() as cur:
    cur.execute(
        "INSERT INTO users (name, email) VALUES (%s, %s)",
        ("John Doe", "john@example.com")
    )
    conn.commit()

# Query data
with conn.cursor() as cur:
    cur.execute("SELECT * FROM users")
    for row in cur.fetchall():
        print(row)

conn.close()
```

### Cloud SQL PostgreSQL

**Use Case**: Production applications

**Connection Method**: Cloud SQL Proxy sidecar + Workload Identity

**Dependencies**:
```txt
google-cloud-sql-connector[pg8000]==1.5.0
sqlalchemy==2.0.23
pg8000==1.30.3
```

**Example**:
```python
from google.cloud.sql.connector import Connector
import sqlalchemy
import os

# Get connection details from environment
PROJECT_ID = os.getenv('GCP_PROJECT')
REGION = os.getenv('GCP_REGION', 'us-central1')
INSTANCE_NAME = os.getenv('CLOUDSQL_INSTANCE')
DB_NAME = os.getenv('DB_NAME', 'mydb')
DB_USER = os.getenv('DB_USER', 'postgres')
DB_PASSWORD = os.getenv('DB_PASSWORD')

# Initialize connector
connector = Connector()

def getconn():
    conn = connector.connect(
        f"{PROJECT_ID}:{REGION}:{INSTANCE_NAME}",
        "pg8000",
        user=DB_USER,
        password=DB_PASSWORD,
        db=DB_NAME
    )
    return conn

# Create SQLAlchemy engine
engine = sqlalchemy.create_engine(
    "postgresql+pg8000://",
    creator=getconn,
)

# Use the engine
with engine.connect() as conn:
    result = conn.execute(sqlalchemy.text("SELECT version()"))
    print(result.fetchone())

# Cleanup
connector.close()
```

## NoSQL Examples

### Firestore

**Use Case**: Real-time applications, mobile backends

**Connection Method**: Workload Identity (no credentials needed)

**Dependencies**:
```txt
google-cloud-firestore==2.14.0
```

**Example**:
```python
from google.cloud import firestore
import os

# Initialize Firestore client (uses Workload Identity)
PROJECT_ID = os.getenv('GCP_PROJECT')
db = firestore.Client(project=PROJECT_ID)

# Create document
doc_ref = db.collection('users').document('user1')
doc_ref.set({
    'name': 'John Doe',
    'email': 'john@example.com',
    'age': 30
})

# Read document
doc = doc_ref.get()
if doc.exists:
    print(f"Document data: {doc.to_dict()}")

# Query collection
users_ref = db.collection('users')
query = users_ref.where('age', '>=', 18)
for doc in query.stream():
    print(f"{doc.id}: {doc.to_dict()}")

# Update document
doc_ref.update({
    'age': 31
})

# Delete document
doc_ref.delete()
```

### Cloud Datastore

**Use Case**: Key-value storage, structured data

**Connection Method**: Workload Identity

**Dependencies**:
```txt
google-cloud-datastore==2.19.0
```

**Example**:
```python
from google.cloud import datastore
import os

# Initialize Datastore client
PROJECT_ID = os.getenv('GCP_PROJECT')
client = datastore.Client(project=PROJECT_ID)

# Create entity
key = client.key('User', 'user1')
entity = datastore.Entity(key=key)
entity.update({
    'name': 'John Doe',
    'email': 'john@example.com',
    'age': 30
})
client.put(entity)

# Read entity
key = client.key('User', 'user1')
entity = client.get(key)
print(entity)

# Query entities
query = client.query(kind='User')
query.add_filter('age', '>=', 18)
results = list(query.fetch())
for entity in results:
    print(entity)

# Delete entity
client.delete(key)
```

### Redis

**Use Case**: Caching, session storage

**Connection Method**: Direct connection to Redis service

**Dependencies**:
```txt
redis==5.0.1
```

**Example**:
```python
import redis
import os

# Get connection details
REDIS_HOST = os.getenv('REDIS_HOST', 'redis.default.svc.cluster.local')
REDIS_PORT = int(os.getenv('REDIS_PORT', '6379'))
REDIS_PASSWORD = os.getenv('REDIS_PASSWORD', '')

# Connect to Redis
r = redis.Redis(
    host=REDIS_HOST,
    port=REDIS_PORT,
    password=REDIS_PASSWORD,
    decode_responses=True
)

# Set key-value
r.set('user:1:name', 'John Doe')
r.set('user:1:email', 'john@example.com')

# Get value
name = r.get('user:1:name')
print(f"Name: {name}")

# Hash operations
r.hset('user:2', mapping={
    'name': 'Jane Doe',
    'email': 'jane@example.com',
    'age': 28
})

user = r.hgetall('user:2')
print(f"User: {user}")

# List operations
r.lpush('tasks', 'task1', 'task2', 'task3')
tasks = r.lrange('tasks', 0, -1)
print(f"Tasks: {tasks}")

# Set expiration (TTL)
r.setex('session:abc123', 3600, 'session_data')

# Delete key
r.delete('user:1:name')
```

## Deployment Patterns

### Pattern 1: Environment Variables

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: python-app
spec:
  template:
    spec:
      containers:
      - name: app
        image: my-python-app:1.0
        env:
        - name: DB_HOST
          value: postgresql.default.svc.cluster.local
        - name: DB_PORT
          value: "5432"
        - name: DB_NAME
          value: mydb
        - name: DB_USER
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: username
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: password
```

### Pattern 2: Cloud SQL Proxy Sidecar

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: python-app
spec:
  template:
    spec:
      serviceAccountName: app-ksa  # Workload Identity
      containers:
      - name: app
        image: my-python-app:1.0
        env:
        - name: DB_HOST
          value: "127.0.0.1"
        - name: DB_PORT
          value: "5432"
        - name: DB_USER
          valueFrom:
            secretKeyRef:
              name: cloudsql-credentials
              key: username
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: cloudsql-credentials
              key: password
      - name: cloud-sql-proxy
        image: gcr.io/cloud-sql-connectors/cloud-sql-proxy:2.8.0
        args:
        - "--structured-logs"
        - "--port=5432"
        - "PROJECT:REGION:INSTANCE"
        securityContext:
          runAsNonRoot: true
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
```

### Pattern 3: Workload Identity for GCP Services

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: python-app
spec:
  template:
    spec:
      serviceAccountName: app-ksa  # Annotated with GCP SA
      containers:
      - name: app
        image: my-python-app:1.0
        env:
        - name: GCP_PROJECT
          value: my-project-id
        # No DB credentials needed for Firestore/Datastore!
        # Workload Identity handles authentication
```

## Best Practices

### 1. Connection Pooling

```python
from sqlalchemy import create_engine, pool

# Use connection pooling for better performance
engine = create_engine(
    "postgresql+pg8000://",
    creator=getconn,
    pool_size=5,
    max_overflow=2,
    pool_timeout=30,
    pool_recycle=1800,
)
```

### 2. Error Handling

```python
import psycopg2
from psycopg2 import OperationalError, IntegrityError

try:
    conn = psycopg2.connect(...)
    # Database operations
except OperationalError as e:
    print(f"Connection error: {e}")
    # Retry logic
except IntegrityError as e:
    print(f"Data integrity error: {e}")
    # Handle constraint violations
finally:
    if conn:
        conn.close()
```

### 3. Environment Configuration

```python
import os
from dataclasses import dataclass

@dataclass
class DatabaseConfig:
    host: str
    port: int
    database: str
    user: str
    password: str
    
    @classmethod
    def from_env(cls):
        return cls(
            host=os.getenv('DB_HOST', 'localhost'),
            port=int(os.getenv('DB_PORT', '5432')),
            database=os.getenv('DB_NAME', 'mydb'),
            user=os.getenv('DB_USER', 'postgres'),
            password=os.getenv('DB_PASSWORD', '')
        )

config = DatabaseConfig.from_env()
```

### 4. Structured Logging

```python
import logging
import json

# Configure structured logging for GCP
logging.basicConfig(
    level=logging.INFO,
    format='%(message)s'
)

def log_structured(message, severity='INFO', **kwargs):
    log_entry = {
        'severity': severity,
        'message': message,
        **kwargs
    }
    print(json.dumps(log_entry))

log_structured('Database connection established', 
               severity='INFO',
               database='mydb',
               host='postgresql.default.svc.cluster.local')
```

### 5. Health Checks

```python
from flask import Flask, jsonify
import psycopg2

app = Flask(__name__)

@app.route('/health')
def health():
    try:
        conn = psycopg2.connect(...)
        conn.close()
        return jsonify({'status': 'healthy'}), 200
    except Exception as e:
        return jsonify({'status': 'unhealthy', 'error': str(e)}), 503

@app.route('/ready')
def ready():
    # Check if app is ready to serve traffic
    return jsonify({'status': 'ready'}), 200
```

## Docker Images

### Dockerfile for SQL Applications

```dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Run as non-root user
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app
USER appuser

CMD ["python", "app.py"]
```

### Dockerfile for NoSQL Applications

```dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Run as non-root user
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app
USER appuser

CMD ["python", "app.py"]
```

## Testing

### Unit Tests

```python
import unittest
from unittest.mock import patch, MagicMock

class TestDatabaseOperations(unittest.TestCase):
    
    @patch('psycopg2.connect')
    def test_create_user(self, mock_connect):
        # Mock database connection
        mock_conn = MagicMock()
        mock_cursor = MagicMock()
        mock_connect.return_value = mock_conn
        mock_conn.cursor.return_value.__enter__.return_value = mock_cursor
        
        # Test your function
        result = create_user('John Doe', 'john@example.com')
        
        # Assertions
        self.assertTrue(result)
        mock_cursor.execute.assert_called_once()

if __name__ == '__main__':
    unittest.main()
```

## Next Steps

1. Explore [sql](./sql) for complete SQL examples
2. Explore [nosql](./nosql) for complete NoSQL examples
3. Check [06-datastores](../06-datastores) for Helm chart deployments
4. Review [10-enterprise-app](../10-enterprise-app) for complete application example

## Resources

- [psycopg2 Documentation](https://www.psycopg.org/docs/)
- [SQLAlchemy Documentation](https://docs.sqlalchemy.org/)
- [Firestore Python Client](https://cloud.google.com/firestore/docs/quickstart-servers#python)
- [Datastore Python Client](https://cloud.google.com/datastore/docs/reference/libraries#client-libraries-install-python)
- [Redis Python Client](https://redis-py.readthedocs.io/)
