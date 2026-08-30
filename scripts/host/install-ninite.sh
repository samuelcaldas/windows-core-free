#!/usr/bin/env bash
# ==============================================================================
# scripts/host/install-ninite.sh
# Deploy & Run Interactive Ninite Package Manager on Windows Core Guest
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

VM_HOST="${VM_HOST:-127.0.0.1}"
VM_PORT="${VM_PORT:-2222}"
VM_USER="${VM_USER:-samuelcaldas}"

SSH_OPTS="-p ${VM_PORT} -o StrictHostKeyChecking=accept-new"
SCP_OPTS="-P ${VM_PORT} -o StrictHostKeyChecking=accept-new"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

deploy_script() {
    log_info "Creating remote Ninite directory on guest..."
    ssh ${SSH_OPTS} "${VM_USER}@${VM_HOST}" "powershell -Command \"New-Item -ItemType Directory -Path 'C:\\Program Files\\Ninite', 'C:\\Provisioning\\scripts' -Force | Out-Null\""

    log_info "Transferring Install-NiniteApps.ps1 to guest..."
    scp ${SCP_OPTS} "${REPO_ROOT}/scripts/guest/Install-NiniteApps.ps1" "${VM_USER}@${VM_HOST}:C:/Program Files/Ninite/Install-NiniteApps.ps1"
    scp ${SCP_OPTS} "${REPO_ROOT}/scripts/guest/Install-NiniteApps.ps1" "${VM_USER}@${VM_HOST}:C:/Provisioning/scripts/Install-NiniteApps.ps1"

    log_info "Deploying Desktop Shortcuts..."
    ssh ${SSH_OPTS} "${VM_USER}@${VM_HOST}" "pwsh -ExecutionPolicy Bypass -File 'C:\\Program Files\\Ninite\\Install-NiniteApps.ps1' -DeployOnly"
    log_success "Ninite Manager script and desktop shortcuts deployed."
}

main() {
    echo "=============================================================================="
    echo "  Windows Core - Ninite Interactive Package Manager Orchestrator"
    echo "=============================================================================="

    deploy_script

    if [ "${1:-}" = "--interactive" ] || [ "${1:-}" = "-i" ]; then
        log_info "Launching interactive TUI session over SSH..."
        ssh -t ${SSH_OPTS} "${VM_USER}@${VM_HOST}" "pwsh -ExecutionPolicy Bypass -File 'C:\\Program Files\\Ninite\\Install-NiniteApps.ps1'"
    elif [ "${1:-}" = "--preset" ]; then
        local PRESET="${2:-DevStack}"
        log_info "Running preset: ${PRESET}..."
        ssh ${SSH_OPTS} "${VM_USER}@${VM_HOST}" "pwsh -ExecutionPolicy Bypass -File 'C:\\Program Files\\Ninite\\Install-NiniteApps.ps1' -Preset '${PRESET}' -Silent"
    elif [ "${1:-}" = "--apps" ]; then
        local APPS="${2}"
        log_info "Installing specific apps: ${APPS}..."
        ssh ${SSH_OPTS} "${VM_USER}@${VM_HOST}" "pwsh -ExecutionPolicy Bypass -File 'C:\\Program Files\\Ninite\\Install-NiniteApps.ps1' -Apps @(${APPS}) -Silent"
    fi
}

main "$@"
