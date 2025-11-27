# Runbook: Node Event Creation Failures

## Overview

Node events provide visibility into non-fatal hardware problems. When creation fails, warning signs are hidden from operators.

**Key points:**
- Node events are for non-fatal health issues (warnings)
- Node conditions are for fatal issues
- Failures typically indicate API server issues

## Symptoms

- Metric `nvsentinel_node_event_operations_total{operation="create", status="failed"}` is increasing
- Health events in MongoDB but not visible in `kubectl describe node`

## Procedure

### 1. Check Platform-Connector Logs

```bash
kubectl logs -n nvsentinel deployment/platform-connector --tail=50 | grep -i "failed to create event"
```

Look for error codes:
- **429** → API server throttling
- **403** → RBAC permission denied
- **Connection refused/timeout** → API server unreachable
- **409** → Conflict (should auto-resolve with retries)

### 2. Verify API Server is Reachable

```bash
# Check if API server is accessible
kubectl cluster-info

# Check platform-connector pod status
kubectl get pods -n nvsentinel -l app=platform-connector
```

If pods are in `CrashLoopBackOff` or `Error`, API connectivity may be broken.

### 3. Verify RBAC Permissions

```bash
kubectl auth can-i create events --as=system:serviceaccount:nvsentinel:platform-connector -n default
```

Should return `yes`. If `no`, check the ClusterRole:

```bash
kubectl get clusterrole platform-connector -o yaml | grep -A 3 "resources: events"
```

Should include `create`, `update`, `list` verbs for `events` resource.

### 4. Common Issues

#### API Server Throttling (429 errors)

- Health monitors may be generating too many events
- Check health monitor polling intervals in their configs

#### RBAC Denied (403 errors)

- Fix RBAC permissions and restart platform-connector:
```bash
kubectl rollout restart deployment/platform-connector -n nvsentinel
```

#### API Server Unreachable

- Check cluster status: `kubectl cluster-info`
- Check for network policies blocking platform-connector

### 5. Verify Resolution

```bash
# Watch for successful event creations
kubectl get events --field-selector involvedObject.kind=Node --watch

# Monitor platform-connector logs
kubectl logs -n nvsentinel deployment/platform-connector -f | grep event
```
