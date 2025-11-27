# Runbook: Health Monitor UDS Communication Failures

## Overview

Health monitors (GPU, NVSwitch, syslog, CSP) publish events via gRPC over Unix Domain Socket (UDS) to platform-connector. Communication failures block all health event reporting.

**Key points:**
- Platform-connector creates UDS socket that monitors connect to
- Each node has its own UDS socket (`/var/run/nvsentinel/platform-connector.sock`)
- Failures prevent health events from reaching MongoDB

## Symptoms

- Metric `health_events_insertion_to_uds_error` (GPU) or `trigger_uds_send_errors_total` (CSP) increasing
- Health monitors logs show gRPC errors (code 14: Unavailable)
- No health events in MongoDB despite monitors running

## Procedure

### 1. Identify Affected Monitor and Node

```bash
# Check GPU monitor metrics
kubectl logs -n nvsentinel daemonset/gpu-health-monitor --tail=50 | grep -i uds_error

# For DaemonSet monitors, find affected node
kubectl get pods -n nvsentinel -l app=gpu-health-monitor -o wide
```

### 2. Check Health Monitor Logs

```bash
# For GPU monitor
kubectl logs -n nvsentinel <GPU_MONITOR_POD> --tail=50 | grep -i "uds\|failed to send"

# For CSP monitor
kubectl logs -n nvsentinel deployment/csp-health-monitor --tail=50 | grep -i "uds"
```

Look for:
- `"code = Unavailable"` → Socket closed or platform-connector not running
- `"connection refused"` → Socket doesn't exist
- `"broken pipe"` → Socket was closed mid-communication

### 3. Check Platform-Connector Status

```bash
kubectl get pods -n nvsentinel -l app=platform-connector

# Check for restarts or crashes
kubectl logs -n nvsentinel deployment/platform-connector --tail=50 | grep -i "grpc\|uds"
```

Platform-connector should log: `"Starting gRPC server on unix:///var/run/nvsentinel/platform-connector.sock"`

### 4. Verify Volume Mounts

Both platform-connector and health monitors must mount `/var/run/nvsentinel`:

```bash
# Check platform-connector mount
kubectl get deployment platform-connector -n nvsentinel -o yaml | grep -A 3 "/var/run/nvsentinel"

# Check health monitor mount
kubectl get daemonset gpu-health-monitor -n nvsentinel -o yaml | grep -A 3 "/var/run/nvsentinel"
```

Should be mounted from hostPath.

### 5. Restart Components

Health monitors implement retry logic, but if socket was down, restart is needed:

```bash
# Step 1: Restart platform-connector (creates socket)
kubectl rollout restart deployment/platform-connector -n nvsentinel
kubectl rollout status deployment/platform-connector -n nvsentinel

# Step 2: Wait for socket creation (30 seconds)
sleep 30

# Step 3: Restart affected health monitor
kubectl rollout restart daemonset/gpu-health-monitor -n nvsentinel
```

### 6. Verify Resolution

```bash
# Watch health monitor logs for successful sends
kubectl logs -n nvsentinel daemonset/gpu-health-monitor -f | grep "Successfully sent"

# Check health events appearing in MongoDB
kubectl exec -n nvsentinel mongodb-0 -- mongosh --eval 'db.HealthEvents.find().sort({_id: -1}).limit(3)'
```

## Common Issues

#### Socket Missing

- Platform-connector not running or crashed
- Volume mount misconfigured
- **Fix:** Restart platform-connector, verify volume mounts

#### Intermittent Failures

- Platform-connector restarts
- **Fix:** Monitor will auto-retry, investigate platform-connector crashes if frequent

#### All Monitors Failing

- Platform-connector socket corrupted
- **Fix:** Restart platform-connector, then all health monitors
