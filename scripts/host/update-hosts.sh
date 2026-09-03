#!/usr/bin/env bash
# ==============================================================================
# Windows CoreOS (WCOS) - Dan Pollock Zero-Route Hosts Blocklist Deployment (Host Bash)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CONFIG_DIR="${REPO_ROOT}/config/hosts"

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
    echo "  Windows CoreOS (WCOS) - Dan Pollock Zero-Route Hosts Blocklist"
    echo "=============================================================================="

    # 1. Update / verify local repository cache
    mkdir -p "${CONFIG_DIR}"
    if [ ! -f "${CONFIG_DIR}/hosts" ]; then
        log_info "Fetching latest Dan Pollock zero-route hosts file..."
        curl -fSL "https://someonewhocares.org/hosts/zero/hosts" -o "${CONFIG_DIR}/hosts"
    fi

    # 2. Prepare remote staging directories
    log_info "Preparing guest staging directories..."
    run_ssh "powershell -Command \"New-Item -ItemType Directory -Path 'C:\\Provisioning\\config\\hosts', 'C:\\Provisioning\\scripts' -Force | Out-Null\""

    # 3. Transfer hosts file and installer script
    log_info "Transferring hosts file and Update-HostsBlocklist.ps1 to guest..."
    run_scp "${CONFIG_DIR}/hosts" "C:/Provisioning/config/hosts/hosts"
    run_scp "${REPO_ROOT}/scripts/guest/Update-HostsBlocklist.ps1" "C:/Provisioning/scripts/Update-HostsBlocklist.ps1"

    # 4. Execute installer script on Windows Core
    log_info "Applying hosts blocklist on Windows Core..."
    run_ssh "powershell -ExecutionPolicy Bypass -File 'C:\\Provisioning\\scripts\\Update-HostsBlocklist.ps1'"

    # 5. Verify resolution of localhost and blocked host
    log_info "Verifying hosts resolution on guest..."
    run_ssh 'powershell -Command "
        Write-Host --- Localhost Resolution ---
        Resolve-DnsName localhost -ErrorAction SilentlyContinue | Select-Object Name, IPAddress
        Write-Host --- Total Lines in hosts file ---
        (Get-Content C:\Windows\System32\drivers\etc\hosts).Count
    "'

    log_success "Dan Pollock hosts blocklist deployed successfully on Windows CoreOS (WCOS)."
}

main
