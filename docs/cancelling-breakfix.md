# Cancelling Break-Fix Workflows

## Overview

NVSentinel provides two ways to stop automated break-fix workflows:

1. **Temporary cancellation**: Uncordon a quarantined node to stop the current workflow
2. **Permanent opt-out**: Label nodes to completely disable NVSentinel break-fix automation

## Temporary Cancellation: Uncordoning a Node

### When to Use This

Cancel a workflow when you need to handle a specific situation manually:

- False positive detection
- Need to investigate the node before remediation
- Want to apply a different fix
- Need the node back in service urgently

### How to Cancel

Simply uncordon the node:

```bash
kubectl uncordon <node-name>
```

NVSentinel detects the uncordon and immediately:
- Stops the automated workflow
- Cleans up quarantine state (annotations, taints, labels)
- Marks health events as cancelled
- Returns the node to normal operation

The node can schedule new workloads right away. If the health issue happens again later, NVSentinel will treat it as a new incident.

### Checking Cancellation Status

See if a node was manually uncordoned:

```bash
kubectl get node <node-name> -o jsonpath='{.metadata.annotations.k8saas\.nvidia\.com/quarantinedNodeUncordonedManually}'
```

If this returns `"true"`, the node was manually uncordoned.

## Permanent Opt-Out: Disabling Break-Fix on Nodes

### When to Use This

Disable NVSentinel break-fix automation permanently on nodes when:

- Performing planned maintenance (driver upgrades, OS updates)
- Testing or development nodes that shouldn't be automatically managed
- Nodes with special workloads that need custom handling
- Want to use NVSentinel for monitoring only, not automation

### How to Disable Break-Fix

Label the node to opt out:

```bash
kubectl label node <node-name> k8saas.nvidia.com/ManagedByNVSentinel=false
```

**Effect**: NVSentinel will completely ignore health events from this node. No quarantine, no drain, no remediation.

### How to Re-Enable Break-Fix

Remove the label to opt back in:

```bash
kubectl label node <node-name> k8saas.nvidia.com/ManagedByNVSentinel-
```

The node will be managed by NVSentinel again for any new health events.

### Disabling Multiple Nodes

For planned maintenance across many nodes:

```bash
# Disable all nodes
kubectl label node --all k8saas.nvidia.com/ManagedByNVSentinel=false

# Perform maintenance

# Re-enable all nodes
kubectl label node --all k8saas.nvidia.com/ManagedByNVSentinel-
```

## Comparison: Uncordon vs. Opt-Out Label

| Aspect | Uncordoning | Opt-Out Label |
|:-------|:-----------|:--------------|
| **Duration** | One-time cancellation | Permanent until removed |
| **Scope** | Current workflow only | All future workflows |
| **Use case** | Handle this incident manually | Disable automation entirely |
| **Re-quarantine** | Possible for new events | Not possible while label is set |
| **Visibility** | Adds cancellation annotation | Node ignored in metrics/logs |

## Example Scenarios

### Scenario 1: False Positive
A GPU XID error was detected but you determine it's transient and not a real issue.

#### Action
Uncordon the node
```bash
kubectl uncordon gpu-node-42
```

#### Result
Workflow cancelled, node returns to service. If the error reoccurs, NVSentinel will evaluate it again.

### Scenario 2: Driver Upgrade
You're upgrading GPU drivers across the cluster and don't want NVSentinel to interfere.

#### Action
Label nodes before upgrade
```bash
kubectl label node --all k8saas.nvidia.com/ManagedByNVSentinel=false
# Perform driver upgrade
kubectl label node --all k8saas.nvidia.com/ManagedByNVSentinel-
```

#### Result
NVSentinel ignores all health events during the maintenance window.
