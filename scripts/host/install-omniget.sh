#!/usr/bin/env bash
# ==============================================================================
# scripts/host/install-omniget.sh
# Deploy & Run OmniGet (og) Universal Package Manager on Windows Core Guest
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

deploy_omniget() {
    log_info "Creating remote OmniGet and provisioning directories on guest..."
    ssh ${SSH_OPTS} "${VM_USER}@${VM_HOST}" "powershell -Command \"New-Item -ItemType Directory -Path 'C:\\Program Files\\OmniGet', 'C:\\Provisioning\\scripts' -Force | Out-Null\""

    log_info "Transferring Install-OmniGet.ps1 to guest..."
    scp ${SCP_OPTS} "${REPO_ROOT}/scripts/guest/Install-OmniGet.ps1" "${VM_USER}@${VM_HOST}:C:/Provisioning/scripts/Install-OmniGet.ps1"

    if [ -d "${REPO_ROOT}/external/omniget" ]; then
        log_info "Packaging and synchronizing external/omniget submodule to guest..."
        local TEMP_ZIP="/tmp/omniget_submodule.zip"
        (cd "${REPO_ROOT}/external/omniget" && zip -rq "${TEMP_ZIP}" .)
        scp ${SCP_OPTS} "${TEMP_ZIP}" "${VM_USER}@${VM_HOST}:C:/Provisioning/packages/omniget.zip"
        rm -f "${TEMP_ZIP}"
    fi

    log_info "Deploying OmniGet environment & desktop shortcuts..."
    ssh ${SSH_OPTS} "${VM_USER}@${VM_HOST}" "pwsh -ExecutionPolicy Bypass -File 'C:\\Provisioning\\scripts\\Install-OmniGet.ps1' -DeployOnly"
    log_success "OmniGet package engine deployed."
}

main() {
    echo "=============================================================================="
    echo "  Windows Core - OmniGet (og) Universal Package Manager Host Orchestrator"
    echo "=============================================================================="

    deploy_omniget

    if [ "${1:-}" = "--interactive" ] || [ "${1:-}" = "-i" ] || [ $# -eq 0 ]; then
        log_info "Launching interactive OmniGet TUI session over SSH..."
        ssh -t ${SSH_OPTS} "${VM_USER}@${VM_HOST}" "pwsh -ExecutionPolicy Bypass -File 'C:\\Program Files\\OmniGet\\src\\OmniGet.ps1'"
    elif [ "${1:-}" = "--preset" ]; then
        local PRESET="${2:-DevStack}"
        log_info "Executing preset: ${PRESET}..."
        ssh ${SSH_OPTS} "${VM_USER}@${VM_HOST}" "pwsh -ExecutionPolicy Bypass -File 'C:\\Program Files\\OmniGet\\src\\OmniGet.ps1' -Preset '${PRESET}' -Silent"
    elif [ "${1:-}" = "--install" ] || [ "${1:-}" = "-a" ]; then
        local APPS="${2}"
        log_info "Installing specific packages: ${APPS}..."
        ssh ${SSH_OPTS} "${VM_USER}@${VM_HOST}" "pwsh -ExecutionPolicy Bypass -File 'C:\\Program Files\\OmniGet\\src\\OmniGet.ps1' -Install @(${APPS}) -Silent"
    fi
}

main "$@"
