# Observability - Monitoring and Logging

Learn how to monitor and observe your applications running on GKE.

## Overview

This section covers:
- Metrics collection with Prometheus
- Logging with Cloud Logging
- Distributed tracing
- Alerting and SLOs
- Dashboards and visualization

## Observability Pillars

### 1. Metrics
Numerical measurements over time (CPU, memory, request rate, latency).

### 2. Logs
Discrete events with timestamps (errors, warnings, info).

### 3. Traces
Request flow through distributed systems.

## Monitoring Options

### kube-prometheus-stack (In-Cluster)
**Pros:**
- Complete monitoring solution
- Prometheus + Grafana + Alertmanager
- Free (uses cluster resources)
- Full control

**Cons:**
- You manage it
- Uses cluster resources
- Need to configure storage

**Use for:**
- Development
- Learning
- Custom metrics

### Google Cloud Monitoring (Managed)
**Pros:**
- Fully managed
- Integrated with GKE
- No cluster resources needed
- Built-in dashboards

**Cons:**
- Costs money (free tier available)
- Less flexible than Prometheus

**Use for:**
- Production
- Enterprise deployments
- Multi-cluster monitoring

## Metrics with Prometheus

### Installing kube-prometheus-stack

```bash
# Add Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install with minimal resources (free tier friendly)
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.resources.requests.cpu=100m \
  --set prometheus.prometheusSpec.resources.requests.memory=256Mi \
  --set prometheus.prometheusSpec.resources.limits.cpu=200m \
  --set prometheus.prometheusSpec.resources.limits.memory=512Mi \
  --set grafana.resources.requests.cpu=50m \
  --set grafana.resources.requests.memory=128Mi \
  --set grafana.resources.limits.cpu=100m \
  --set grafana.resources.limits.memory=256Mi
```

### Exposing Metrics in Your Application

**Python (Flask + prometheus_client):**
```python
from flask import Flask
from prometheus_client import Counter, Histogram, generate_latest, REGISTRY

app = Flask(__name__)

# Define metrics
request_count = Counter(
    'http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'status']
)

request_duration = Histogram(
    'http_request_duration_seconds',
    'HTTP request duration',
    ['method', 'endpoint']
)

@app.route('/metrics')
def metrics():
    """Prometheus metrics endpoint"""
    return generate_latest(REGISTRY)

@app.before_request
def before_request():
    request.start_time = time.time()

@app.after_request
def after_request(response):
    duration = time.time() - request.start_time
    request_duration.labels(
        method=request.method,
        endpoint=request.endpoint
    ).observe(duration)
    
    request_count.labels(
        method=request.method,
        endpoint=request.endpoint,
        status=response.status_code
    ).inc()
    
    return response
```

### ServiceMonitor for Prometheus

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: my-app
  labels:
    app: my-app
spec:
  selector:
    matchLabels:
      app: my-app
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
```

### Common Metrics to Track

**Application Metrics:**
- Request rate (requests/second)
- Error rate (errors/second)
- Request duration (latency)
- Active connections
- Queue depth

**Resource Metrics:**
- CPU usage
- Memory usage
- Disk I/O
- Network I/O

**Business Metrics:**
- User signups
- Orders processed
- Revenue
- Active users

## Logging

### Structured Logging

**Python:**
```python
import logging
import json
from datetime import datetime

def log_structured(message, severity='INFO', **kwargs):
    """Log in structured format for GCP Cloud Logging"""
    log_entry = {
        'severity': severity,
        'message': message,
        'timestamp': datetime.utcnow().isoformat(),
        'labels': {
            'service': 'my-app',
            'version': '1.0.0'
        },
        **kwargs
    }
    print(json.dumps(log_entry))

# Usage
log_structured('User logged in', user_id=123, email='user@example.com')
log_structured('Database error', severity='ERROR', error='Connection timeout')
```

**Log Levels:**
- DEBUG: Detailed debugging information
- INFO: General informational messages
- WARNING: Warning messages
- ERROR: Error messages
- CRITICAL: Critical errors

### Cloud Logging Integration

GKE automatically sends container logs to Cloud Logging.

**View logs:**
```bash
# Using gcloud
gcloud logging read "resource.type=k8s_container AND resource.labels.namespace_name=default" --limit 50

# In Cloud Console
# Navigate to: Logging > Logs Explorer
```

**Filter logs:**
```
resource.type="k8s_container"
resource.labels.namespace_name="production"
resource.labels.pod_name=~"my-app-.*"
severity="ERROR"
```

### Log Aggregation

**Fluentd (if needed for custom processing):**
```bash
helm install fluentd bitnami/fluentd \
  --namespace logging \
  --create-namespace \
  --set aggregator.enabled=true
```

## Distributed Tracing

### OpenTelemetry

**Python example:**
```python
from opentelemetry import trace
from opentelemetry.exporter.cloud_trace import CloudTraceSpanExporter
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

# Set up tracing
trace.set_tracer_provider(TracerProvider())
tracer = trace.get_tracer(__name__)

# Export to Cloud Trace
cloud_trace_exporter = CloudTraceSpanExporter()
trace.get_tracer_provider().add_span_processor(
    BatchSpanProcessor(cloud_trace_exporter)
)

# Use in your code
@app.route('/api/users')
def get_users():
    with tracer.start_as_current_span("get_users"):
        with tracer.start_as_current_span("database_query"):
            users = db.query("SELECT * FROM users")
        return jsonify(users)
```

## Alerting

### Prometheus Alerts

**PrometheusRule:**
```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: my-app-alerts
  namespace: monitoring
spec:
  groups:
  - name: my-app
    interval: 30s
    rules:
    - alert: HighErrorRate
      expr: |
        rate(http_requests_total{status=~"5.."}[5m]) > 0.05
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High error rate detected"
        description: "Error rate is {{ $value }} errors/sec"
    
    - alert: HighLatency
      expr: |
        histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 1
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High latency detected"
        description: "95th percentile latency is {{ $value }}s"
    
    - alert: PodCrashLooping
      expr: |
        rate(kube_pod_container_status_restarts_total[15m]) > 0
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "Pod is crash looping"
        description: "Pod {{ $labels.pod }} is restarting"
    
    - alert: HighMemoryUsage
      expr: |
        container_memory_usage_bytes / container_spec_memory_limit_bytes > 0.9
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High memory usage"
        description: "Memory usage is {{ $value | humanizePercentage }}"
```

### Alertmanager Configuration

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: alertmanager-config
  namespace: monitoring
data:
  alertmanager.yml: |
    global:
      resolve_timeout: 5m
    
    route:
      group_by: ['alertname', 'cluster']
      group_wait: 10s
      group_interval: 10s
      repeat_interval: 12h
      receiver: 'default'
      routes:
      - match:
          severity: critical
        receiver: 'critical'
    
    receivers:
    - name: 'default'
      webhook_configs:
      - url: 'http://slack-webhook/alerts'
    
    - name: 'critical'
      webhook_configs:
      - url: 'http://pagerduty-webhook/alerts'
```

## Dashboards

### Grafana Dashboards

**Access Grafana:**
```bash
# Port forward
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Get admin password
kubectl get secret -n monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 --decode

# Open browser
open http://localhost:3000
```

**Import dashboards:**
1. Kubernetes cluster monitoring: Dashboard ID 7249
2. Node exporter: Dashboard ID 1860
3. Pod monitoring: Dashboard ID 6417

**Custom dashboard example:**
```json
{
  "dashboard": {
    "title": "My App Dashboard",
    "panels": [
      {
        "title": "Request Rate",
        "targets": [
          {
            "expr": "rate(http_requests_total[5m])"
          }
        ]
      },
      {
        "title": "Error Rate",
        "targets": [
          {
            "expr": "rate(http_requests_total{status=~\"5..\"}[5m])"
          }
        ]
      },
      {
        "title": "Latency (p95)",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))"
          }
        ]
      }
    ]
  }
}
```

## SLOs (Service Level Objectives)

### Define SLOs

**Availability SLO:**
```yaml
# 99.9% availability
# = 43 minutes downtime per month
# = 8.76 hours downtime per year

apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: availability-slo
spec:
  groups:
  - name: slo
    rules:
    - record: slo:availability:ratio
      expr: |
        sum(rate(http_requests_total{status!~"5.."}[5m]))
        /
        sum(rate(http_requests_total[5m]))
    
    - alert: SLOBudgetBurn
      expr: slo:availability:ratio < 0.999
      for: 5m
      annotations:
        summary: "SLO budget burning"
```

**Latency SLO:**
```yaml
# 95% of requests < 200ms
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: latency-slo
spec:
  groups:
  - name: slo
    rules:
    - record: slo:latency:ratio
      expr: |
        histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) < 0.2
```

## Health Checks

### Application Health Endpoints

```python
from flask import Flask, jsonify

app = Flask(__name__)

@app.route('/healthz')
def health():
    """Liveness probe"""
    return jsonify({'status': 'healthy'}), 200

@app.route('/ready')
def ready():
    """Readiness probe"""
    try:
        # Check dependencies
        db.ping()
        redis.ping()
        return jsonify({'status': 'ready'}), 200
    except Exception as e:
        return jsonify({'status': 'not ready', 'error': str(e)}), 503

@app.route('/startup')
def startup():
    """Startup probe"""
    if app_initialized:
        return jsonify({'status': 'started'}), 200
    return jsonify({'status': 'starting'}), 503
```

## Best Practices

### 1. Use Structured Logging

```python
# Good
log_structured('User action', user_id=123, action='login', ip='1.2.3.4')

# Bad
print(f"User 123 logged in from 1.2.3.4")
```

### 2. Set Appropriate Log Levels

```python
# Development
LOG_LEVEL = 'DEBUG'

# Production
LOG_LEVEL = 'INFO'
```

### 3. Include Context in Logs

```python
log_structured(
    'Database query',
    query='SELECT * FROM users',
    duration_ms=123,
    rows_returned=50,
    user_id=123
)
```

### 4. Monitor the Four Golden Signals

1. **Latency**: How long requests take
2. **Traffic**: How many requests
3. **Errors**: Rate of failed requests
4. **Saturation**: Resource utilization

### 5. Set Up Alerts

- Alert on symptoms, not causes
- Reduce alert fatigue
- Make alerts actionable
- Include runbooks

### 6. Use Dashboards

- Create dashboards for each service
- Include key metrics
- Make them accessible to the team

## Cost Management

### Free Tier

**Cloud Logging:**
- 50 GB/month free
- $0.50/GB after

**Cloud Monitoring:**
- Free for GKE metrics
- Paid for custom metrics

### Cost Savings

1. **Use sampling for traces**: Don't trace every request
2. **Set log retention**: Delete old logs
3. **Filter logs**: Don't log everything
4. **Use in-cluster Prometheus**: Free for development

## Troubleshooting

### No Metrics Showing

```bash
# Check ServiceMonitor
kubectl get servicemonitor -n monitoring

# Check if Prometheus is scraping
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090
# Visit http://localhost:9090/targets

# Check application metrics endpoint
kubectl port-forward svc/my-app 8080:80
curl http://localhost:8080/metrics
```

### Logs Not Appearing

```bash
# Check if pods are running
kubectl get pods

# Check pod logs
kubectl logs POD_NAME

# Check Cloud Logging
gcloud logging read "resource.type=k8s_container" --limit 10
```

## Next Steps

1. Install [kube-prometheus-stack](./kube-prometheus-stack)
2. Configure [logging](./logging) with structured logs
3. Set up [alerts-slos](./alerts-slos) for your services

## Resources

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Cloud Logging](https://cloud.google.com/logging/docs)
- [Cloud Monitoring](https://cloud.google.com/monitoring/docs)
- [OpenTelemetry](https://opentelemetry.io/docs/)
