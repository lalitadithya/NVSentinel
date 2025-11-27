# Runbook: GPU Health Monitor DCGM Connectivity Failures

## Overview

GPU health monitor requires connection to NVIDIA DCGM for all GPU health checks. Connectivity failures prevent GPU monitoring entirely on affected nodes.

**Key points:**
- DCGM can be exposed via Kubernetes service or localhost
- Failures generate `GpuDcgmConnectivityFailure` node condition
- Complete loss of GPU health monitoring on affected node

## Symptoms

- Node condition `GpuDcgmConnectivityFailure` present
- Metric `dcgm_health_active_events{event_type="GpuDcgmConnectivityFailure"}` equals 1
- GPU monitor logs show DCGM connection errors

## Procedure

### 1. Check GPU Monitor Logs

```bash
kubectl logs -n nvsentinel <GPU_MONITOR_POD> --tail=50 | grep -i dcgm
```

Look for:
- `"Error getting DCGM handle"`
- `"DCGM connectivity failure detected"`
- `"Failed to connect to DCGM"`

### 2. Identify DCGM Configuration

```bash
kubectl get configmap gpu-health-monitor-config -n nvsentinel -o yaml | grep -i dcgm
```

Two modes:
- **Kubernetes Service**: `dcgmK8sServiceEnabled: true`, endpoint like `nvidia-dcgm.gpu-operator.svc:5555`
- **Localhost**: `dcgmK8sServiceEnabled: false`, uses `localhost:5555` with `hostNetwork: true`

### 3. Verify DCGM Pod Running

```bash
# Check DCGM pod on affected node
kubectl get pods -n gpu-operator -l app=nvidia-dcgm -o wide

# Check DCGM logs
kubectl logs -n gpu-operator <DCGM_POD> --tail=30
```

DCGM pod must be `Running` on the same node as the failing GPU monitor.

### 4. Test Connectivity

#### For Kubernetes Service Mode

```bash
# Check if DCGM service exists
kubectl get svc -n gpu-operator | grep dcgm

# Test DNS from GPU monitor pod
kubectl exec -n nvsentinel <GPU_MONITOR_POD> -- nslookup nvidia-dcgm.gpu-operator.svc
```

#### For Localhost Mode

```bash
# Verify GPU monitor uses hostNetwork
kubectl get daemonset gpu-health-monitor -n nvsentinel -o yaml | grep hostNetwork
# Should be: hostNetwork: true
```

### 5. Common Issues

#### DCGM Pod Not Running

- Check GPU Operator status: `kubectl get pods -n gpu-operator`
- Restart DCGM: `kubectl delete pod -n gpu-operator <DCGM_POD>`

#### Wrong Service Endpoint

- Update gpu-health-monitor config with correct DCGM service name
- Restart gpu-health-monitor

#### Network Policy Blocking Connection

- Check network policies: `kubectl get networkpolicies -n gpu-operator`
- Ensure traffic allowed from nvsentinel namespace to gpu-operator

#### Configuration Mismatch

- Using service mode but monitor has `hostNetwork: true` (or vice versa)
- Align configuration and restart gpu-health-monitor

### 6. Restart Sequence

```bash
# Step 1: Restart DCGM
kubectl delete pod -n gpu-operator <DCGM_POD>

# Step 2: Wait for DCGM ready
kubectl wait --for=condition=ready pod -n gpu-operator -l app=nvidia-dcgm --timeout=120s

# Step 3: Restart GPU monitor on affected node
kubectl delete pod -n nvsentinel <GPU_MONITOR_POD>
```

### 7. Verify Resolution

```bash
# Check condition cleared
kubectl describe node <NODE_NAME> | grep GpuDcgmConnectivityFailure
# Should show: Status: False (or condition absent)

# Watch GPU monitor logs for health checks
kubectl logs -n nvsentinel <GPU_MONITOR_POD> -f | grep "Publish DCGM"

# Verify GPU health events in MongoDB
kubectl exec -n nvsentinel mongodb-0 -- mongosh --eval 'db.HealthEvents.find({"healthevent.agent": "gpu-health-monitor"}).sort({_id: -1}).limit(3)'
```
