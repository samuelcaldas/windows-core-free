#!/usr/bin/env bash
# ==============================================================================
# Windows Core - System & Memory Optimization Orchestrator (Host Bash)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

VM_HOST="${VM_HOST:-127.0.0.1}"
VM_PORT="${VM_PORT:-2222}"
VM_USER="${VM_USER:-samuelcaldas}"
VM_PASS="${VM_PASS:-windows}"

SSH_OPTS="-p ${VM_PORT} -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10"
SCP_OPTS="-P ${VM_PORT} -o StrictHostKeyChecking=accept-new"

log_info() { echo -e "\033[1;36m[INFO]\033[0m $1"; }
log_success() { echo -e "\033[1;32m[SUCCESS]\033[0m $1"; }
log_error() { echo -e "\033[1;31m[ERROR]\033[0m $1"; }

run_ssh() {
    local CMD="$1"
    if ssh ${SSH_OPTS} "${VM_USER}@${VM_HOST}" "${CMD}"; then
        return 0
    elif command -v sshpass &>/dev/null; then
        sshpass -p "${VM_PASS}" ssh ${SSH_OPTS} "${VM_USER}@${VM_HOST}" "${CMD}"
    else
        ssh ${SSH_OPTS} "${VM_USER}@${VM_HOST}" "${CMD}"
    fi
}

run_scp() {
    local SRC="$1"
    local DST="$2"
    if scp ${SCP_OPTS} "${SRC}" "${VM_USER}@${VM_HOST}:${DST}"; then
        return 0
    elif command -v sshpass &>/dev/null; then
        sshpass -p "${VM_PASS}" scp ${SCP_OPTS} "${SRC}" "${VM_USER}@${VM_HOST}:${DST}"
    else
        scp ${SCP_OPTS} "${SRC}" "${VM_USER}@${VM_HOST}:${DST}"
    fi
}

main() {
    echo "=============================================================================="
    echo "  Windows Core - Live Memory Optimization & Feature Pruning"
    echo "=============================================================================="

    log_info "Preparing guest provisioning directory..."
    run_ssh "powershell -Command \"New-Item -ItemType Directory -Path 'C:\\Provisioning\\scripts' -Force | Out-Null\""

    log_info "Transferring Optimize-System.ps1 to guest..."
    run_scp "${REPO_ROOT}/scripts/guest/Optimize-System.ps1" "C:/Provisioning/scripts/Optimize-System.ps1"

    log_info "Executing Optimize-System.ps1 on Windows Core guest..."
    run_ssh "powershell -ExecutionPolicy Bypass -File 'C:\\Provisioning\\scripts\\Optimize-System.ps1'"

    log_info "Checking Top RAM Consuming Processes..."
    run_ssh 'powershell -Command "Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 10 Name, Id, WorkingSet64 | Format-Table -AutoSize"'

    log_success "Windows Core memory optimization completed successfully."
}

main
