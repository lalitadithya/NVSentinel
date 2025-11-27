# Runbook: Node Condition Update Failures

## Overview

Node conditions reflect hardware health status (GPU, NVSwitch). Update failures prevent accurate health reporting and can impact scheduling decisions.

**Key points:**
- Conditions updated for both fatal and non-fatal events
- Failures block health status visibility
- Fatal conditions trigger remediation when working

## Symptoms

- Metric `nvsentinel_node_condition_update_total{status="failed"}` is increasing
- Node conditions don't reflect current hardware health
- Health events in MongoDB but not on nodes

## Procedure

### 1. Check Platform-Connector Logs

```bash
kubectl logs -n nvsentinel deployment/platform-connector --tail=50 | grep -i "failed to update node"
```

Look for error codes:
- **429** → API server throttling
- **403** → RBAC permission denied
- **404** → Node doesn't exist
- **409** → Conflict (should auto-resolve with retries)
- **Connection refused/timeout** → API server unreachable

### 2. Verify API Server is Reachable

```bash
# Check API server health
kubectl cluster-info

# Check platform-connector status
kubectl get pods -n nvsentinel -l app=platform-connector
```

### 3. Verify RBAC Permissions

```bash
kubectl auth can-i update nodes/status --as=system:serviceaccount:nvsentinel:platform-connector
```

Should return `yes`. If `no`, check the ClusterRole:

```bash
kubectl get clusterrole platform-connector -o yaml | grep -A 5 "nodes/status"
```

Should include `update`, `patch` verbs for `nodes/status`.

### 4. Check Node Exists

```bash
# Verify node from logs exists
kubectl get node <NODE_NAME>
```

If node was deleted or renamed, updates will fail.

### 5. Common Issues

#### API Server Throttling (429 errors)

- Too many health events causing frequent node updates
- Check health monitor event rates in their logs

#### RBAC Denied (403 errors)

- Fix RBAC and restart:
```bash
kubectl rollout restart deployment/platform-connector -n nvsentinel
```

### 6. Verify Resolution

```bash
# Check node conditions reflect current health
kubectl describe node <NODE_NAME> | grep -A 20 "Conditions:"

# Look for Gpu*, NVSwitch* conditions
```
