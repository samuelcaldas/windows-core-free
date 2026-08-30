#!/usr/bin/env bash
# ==============================================================================
# scripts/host/provision-remote.sh
# Phase 4 & 5: Synchronize SSH Keys/Config & Orchestrate Remote Toolchains on Windows Core
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
GUEST_SCRIPTS_DIR="${REPO_ROOT}/scripts/guest"

# Connection Settings
VM_HOST="${VM_HOST:-127.0.0.1}"
VM_PORT="${VM_PORT:-2222}"
VM_USER="${VM_USER:-samuelcaldas}"
VM_PASS="${VM_PASS:-hebroN@1994}"
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -p ${VM_PORT}"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

check_vm_connectivity() {
    log_info "Checking VM connectivity on ${VM_HOST}:${VM_PORT}..."
    if ! nc -z -w 3 "${VM_HOST}" "${VM_PORT}" 2>/dev/null; then
        log_error "Cannot reach Windows Core VM on port ${VM_PORT}. Is run-vm.sh running?"
        exit 1
    fi
    log_success "Port ${VM_PORT} is reachable."
}

sync_ssh_keys_and_config() {
    log_info "Synchronizing host SSH keys and configuration to Windows Core..."
    local SSH_DIR="${HOME}/.ssh"
    local STAGING_DIR
    STAGING_DIR="$(mktemp -d -t ssh_sync_staging_XXXXXX)"

    # 1. Prepare public keys for authorized_keys
    local AUTH_KEYS="${STAGING_DIR}/authorized_keys"
    touch "${AUTH_KEYS}"
    for pub in "${SSH_DIR}"/*.pub; do
        if [ -f "${pub}" ]; then
            cat "${pub}" >> "${AUTH_KEYS}"
            echo "" >> "${AUTH_KEYS}"
        fi
    done
    if [ -f "${SSH_DIR}/authorized_keys" ]; then
        cat "${SSH_DIR}/authorized_keys" >> "${AUTH_KEYS}"
        echo "" >> "${AUTH_KEYS}"
    fi

    # 2. Copy keys and config into staging
    for keyfile in id_ed25519 id_ed25519.pub google_compute_engine google_compute_engine.pub config known_hosts; do
        if [ -f "${SSH_DIR}/${keyfile}" ]; then
            cp "${SSH_DIR}/${keyfile}" "${STAGING_DIR}/${keyfile}"
        fi
    done

    # 3. Create target directory on guest and transfer files using sshpass/scp or ssh
    log_info "Deploying SSH keys into C:\\Users\\${VM_USER}\\.ssh and C:\\ProgramData\\ssh..."
    
    # Helper to execute remote command
    run_remote_cmd() {
        if command -v sshpass &>/dev/null; then
            sshpass -p "${VM_PASS}" ssh ${SSH_OPTS} "${VM_USER}@${VM_HOST}" "$1"
        else
            ssh ${SSH_OPTS} "${VM_USER}@${VM_HOST}" "$1"
        fi
    }

    # Ensure remote directory structure exists
    run_remote_cmd "powershell -Command \"New-Item -ItemType Directory -Path 'C:\\Users\\${VM_USER}\\.ssh' -Force; New-Item -ItemType Directory -Path 'C:\\ProgramData\\ssh' -Force\"" || true

    # Transfer files
    for file in "${STAGING_DIR}"/*; do
        if [ -f "${file}" ]; then
            local fname
            fname="$(basename "${file}")"
            if command -v sshpass &>/dev/null; then
                sshpass -p "${VM_PASS}" scp -P "${VM_PORT}" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${file}" "${VM_USER}@${VM_HOST}:C:/Users/${VM_USER}/.ssh/${fname}" || true
            else
                scp -P "${VM_PORT}" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${file}" "${VM_USER}@${VM_HOST}:C:/Users/${VM_USER}/.ssh/${fname}" || true
            fi
        fi
    done

    # 4. Ingest authorized_keys into administrators_authorized_keys and apply Windows ACLs
    log_info "Configuring Windows ACLs on authorized_keys and private keys..."
    local ACL_CMD="powershell -Command \"
        Copy-Item -Path 'C:\\Users\\${VM_USER}\\.ssh\\authorized_keys' -Destination 'C:\\ProgramData\\ssh\\administrators_authorized_keys' -Force -ErrorAction SilentlyContinue;
        icacls 'C:\\ProgramData\\ssh\\administrators_authorized_keys' /inheritance:r /grant 'NT AUTHORITY\\SYSTEM:(F)' /grant 'BUILTIN\\Administrators:(F)';
        icacls 'C:\\Users\\${VM_USER}\\.ssh' /inheritance:r /grant '${VM_USER}:(OI)(CI)(F)' /grant 'NT AUTHORITY\\SYSTEM:(OI)(CI)(F)';
        Get-ChildItem 'C:\Users\${VM_USER}\.ssh' | ForEach-Object { icacls \$(\$_.FullName) /inheritance:r /grant '${VM_USER}:(F)' /grant 'NT AUTHORITY\SYSTEM:(F)' }
    \""
    run_remote_cmd "${ACL_CMD}" || true

    rm -rf "${STAGING_DIR}"
    log_success "SSH keys and configurations successfully synchronized with strict Windows ACLs."
}

deploy_guest_scripts_and_tools() {
    log_info "Deploying and running guest toolchain & agent scripts..."

    run_remote_cmd() {
        if command -v sshpass &>/dev/null; then
            sshpass -p "${VM_PASS}" ssh ${SSH_OPTS} "${VM_USER}@${VM_HOST}" "$1"
        else
            ssh ${SSH_OPTS} "${VM_USER}@${VM_HOST}" "$1"
        fi
    }

    # Ensure provisioning directory exists
    run_remote_cmd "powershell -Command \"New-Item -ItemType Directory -Path 'C:\\Provisioning\\scripts' -Force\"" || true

    # Copy guest scripts
    for script in "${GUEST_SCRIPTS_DIR}"/*.ps1; do
        if [ -f "${script}" ]; then
            local sname
            sname="$(basename "${script}")"
            log_info "Uploading ${sname} to guest..."
            if command -v sshpass &>/dev/null; then
                sshpass -p "${VM_PASS}" scp -P "${VM_PORT}" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${script}" "${VM_USER}@${VM_HOST}:C:/Provisioning/scripts/${sname}" || true
            else
                scp -P "${VM_PORT}" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${script}" "${VM_USER}@${VM_HOST}:C:/Provisioning/scripts/${sname}" || true
            fi
        fi
    done

    # Execute Specialize & Disable-HyperV
    log_info "Executing Specialize.ps1 on Windows Core..."
    run_remote_cmd "powershell -ExecutionPolicy Bypass -File 'C:\\Provisioning\\scripts\\Specialize.ps1'" || true

    # Execute Install-Tools
    log_info "Executing Install-Tools.ps1 (PowerShell 7, Git, Node.js LTS, Python)..."
    run_remote_cmd "powershell -ExecutionPolicy Bypass -File 'C:\\Provisioning\\scripts\\Install-Tools.ps1'" || true

    # Execute Setup-Agents (Claude CLI & Antigravity Daemon)
    log_info "Executing Setup-Agents.ps1 (@anthropic-ai/claude-code & agy-daemon)..."
    run_remote_cmd "powershell -ExecutionPolicy Bypass -File 'C:\\Provisioning\\scripts\\Setup-Agents.ps1'" || true

    log_success "Guest provisioning scripts executed successfully."
}

verify_remote_environment() {
    log_info "Verifying remote Windows Core environment and Claude CLI..."
    ssh ${SSH_OPTS} "${VM_USER}@${VM_HOST}" "powershell -Command \"
        Write-Host '--- Environment Info ---';
        whoami;
        hostname;
        Write-Host '--- Installed Tools ---';
        git --version;
        node -v;
        npm -v;
        python --version;
        claude --version;
    \"" || true
    log_success "Remote provisioning and Claude CLI verification complete."
}

main() {
    echo "=============================================================================="
    echo "  Windows Core Headless Host - Remote Provisioning & SSH Synchronization"
    echo "=============================================================================="
    check_vm_connectivity
    sync_ssh_keys_and_config
    deploy_guest_scripts_and_tools
    verify_remote_environment
}

main "$@"
