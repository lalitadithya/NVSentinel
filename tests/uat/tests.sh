#!/bin/bash
# Copyright (c) 2025, NVIDIA CORPORATION.  All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

get_boot_id() {
    local node=$1
    kubectl get node "$node" -o jsonpath='{.status.nodeInfo.bootID}'
}

wait_for_boot_id_change() {
    local node=$1
    local original_boot_id=$2
    local timeout=600
    local elapsed=0
    
    log "Waiting for node $node to reboot (boot ID to change)..."
    
    while [[ $elapsed -lt $timeout ]]; do
        local current_boot_id
        current_boot_id=$(get_boot_id "$node" 2>/dev/null || echo "")
        
        if [[ -n "$current_boot_id" && "$current_boot_id" != "$original_boot_id" ]]; then
            log "Node $node rebooted successfully (boot ID changed)"
            break
        fi
        
        sleep 5
        elapsed=$((elapsed + 5))
    done
    
    if [[ $elapsed -ge $timeout ]]; then
        error "Timeout waiting for node $node to reboot"
    fi
    
    log "Waiting for node $node to be uncordoned..."
    elapsed=0
    while [[ $elapsed -lt $timeout ]]; do
        local is_cordoned
        is_cordoned=$(kubectl get node "$node" -o jsonpath='{.spec.unschedulable}')
        
        if [[ "$is_cordoned" != "true" ]]; then
            log "Node $node is uncordoned and ready ✓"
            return 0
        fi
        
        sleep 5
        elapsed=$((elapsed + 5))
    done
    
    error "Timeout waiting for node $node to be uncordoned"
}

test_gpu_monitoring_dcgm() {
    log "========================================="
    log "Test 1: GPU monitoring via DCGM"
    log "========================================="
    
    local gpu_node
    gpu_node=$(kubectl get nodes -l workload-type=gpu -o jsonpath='{.items[0].metadata.name}')
    
    if [[ -z "$gpu_node" ]]; then
        error "No GPU nodes found"
    fi
    
    log "Selected GPU node: $gpu_node"
    
    local original_boot_id
    original_boot_id=$(get_boot_id "$gpu_node")
    log "Original boot ID: $original_boot_id"
    
    local dcgm_pod
    dcgm_pod=$(kubectl get pods -n gpu-operator -l app=nvidia-dcgm -o jsonpath="{.items[?(@.spec.nodeName=='$gpu_node')].metadata.name}" | head -1)
    
    if [[ -z "$dcgm_pod" ]]; then
        error "No DCGM pod found on node $gpu_node"
    fi
    
    log "Injecting Inforom error via DCGM on pod: $dcgm_pod"
    kubectl exec -n gpu-operator "$dcgm_pod" -- dcgmi test --inject --gpuid 0 -f 84 -v 0
    
    log "Waiting for node to be quarantined and rebooted..."
    wait_for_boot_id_change "$gpu_node" "$original_boot_id"
    
    log "Test 1 PASSED ✓"
}

test_xid_monitoring_syslog() {
    log "========================================="
    log "Test 2: XID monitoring via syslog"
    log "========================================="
    
    local gpu_node
    gpu_node=$(kubectl get nodes -l workload-type=gpu -o jsonpath='{.items[1].metadata.name}')
    
    if [[ -z "$gpu_node" ]]; then
        gpu_node=$(kubectl get nodes -l workload-type=gpu -o jsonpath='{.items[0].metadata.name}')
    fi
    
    if [[ -z "$gpu_node" ]]; then
        error "No GPU nodes found"
    fi
    
    log "Selected GPU node: $gpu_node"
    
    local original_boot_id
    original_boot_id=$(get_boot_id "$gpu_node")
    log "Original boot ID: $original_boot_id"
    
    local driver_pod
    driver_pod=$(kubectl get pods -n gpu-operator -l app=nvidia-driver-daemonset -o jsonpath="{.items[?(@.spec.nodeName=='$gpu_node')].metadata.name}" | head -1)
    
    if [[ -z "$driver_pod" ]]; then
        error "No driver pod found on node $gpu_node"
    fi
    
    log "Injecting XID 119 message via logger on pod: $driver_pod"
    kubectl exec -n gpu-operator "$driver_pod" -- logger -p daemon.err "[6085126.134786] NVRM: Xid (PCI:0002:00:00): 119, pid=1582259, name=nvc:[driver], Timeout after 6s of waiting for RPC response from GPU1 GSP! Expected function 76 (GSP_RM_CONTROL) (0x20802a02 0x8)."
    
    log "Waiting for node to be quarantined and rebooted..."
    wait_for_boot_id_change "$gpu_node" "$original_boot_id"
    
    log "Test 2 PASSED ✓"
}

main() {
    log "Starting NVSentinel UAT tests..."
    
    test_gpu_monitoring_dcgm
    test_xid_monitoring_syslog
    
    log "========================================="
    log "All tests PASSED ✓"
    log "========================================="
}

main "$@"
