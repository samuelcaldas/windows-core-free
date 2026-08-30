#!/usr/bin/env bash
# ==============================================================================
# scripts/host/install-desktopshell.sh
# Non-destructive Live Setup of WinXShell & Explorer++ on Windows Core Guest
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ISO_DIR="${REPO_ROOT}/iso"

VM_HOST="${VM_HOST:-127.0.0.1}"
VM_PORT="${VM_PORT:-2222}"
VM_USER="${VM_USER:-samuelcaldas}"
VM_PASS="${VM_PASS:-hebroN@1994}"

SSH_OPTS="-p ${VM_PORT} -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10"
SCP_OPTS="-P ${VM_PORT} -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

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
    echo "  Windows Core - WinXShell & Explorer++ Desktop Shell Deployment"
    echo "=============================================================================="

    # 1. Verify package availability on host
    if [ ! -f "${ISO_DIR}/winxshell_x64.zip" ]; then
        log_error "Missing ${ISO_DIR}/winxshell_x64.zip. Please build or download it first."
        exit 1
    fi
    if [ ! -f "${ISO_DIR}/explorerpp_x64.zip" ]; then
        log_error "Missing ${ISO_DIR}/explorerpp_x64.zip. Please build or download it first."
        exit 1
    fi

    # 2. Prepare remote staging directories
    log_info "Preparing guest provisioning directories..."
    run_ssh "powershell -Command \"New-Item -ItemType Directory -Path 'C:\\Provisioning\\packages', 'C:\\Provisioning\\scripts' -Force | Out-Null\""

    # 3. Transfer packages and script
    log_info "Transferring WinXShell and Explorer++ packages to guest..."
    run_scp "${ISO_DIR}/winxshell_x64.zip" "C:/Provisioning/packages/winxshell_x64.zip"
    run_scp "${ISO_DIR}/explorerpp_x64.zip" "C:/Provisioning/packages/explorerpp_x64.zip"
    if [ -f "${REPO_ROOT}/config/explorerpp/config.xml" ]; then
        run_scp "${REPO_ROOT}/config/explorerpp/config.xml" "C:/Provisioning/packages/config.xml"
    fi
    run_scp "${REPO_ROOT}/scripts/guest/Install-DesktopShell.ps1" "C:/Provisioning/scripts/Install-DesktopShell.ps1"

    # 4. Execute Guest Installation Script
    log_info "Executing Install-DesktopShell.ps1 on Windows Core..."
    run_ssh "powershell -ExecutionPolicy Bypass -File 'C:\\Provisioning\\scripts\\Install-DesktopShell.ps1'"

    # 5. Verification
    log_info "Verifying desktop shell deployment..."
    run_ssh "powershell -Command \"
        Write-Host '--- Shell Configuration ---'
        Write-Host '--- Desktop Shortcuts in Public Desktop ---'
        Get-ChildItem 'C:\Users\Public\Desktop' -ErrorAction SilentlyContinue | Select-Object Name
    \""

    log_success "WinXShell & Explorer++ successfully installed without modifying existing data."
}

main
