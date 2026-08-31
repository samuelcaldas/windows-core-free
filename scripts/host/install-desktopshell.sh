#!/usr/bin/env bash
# ==============================================================================
# scripts/host/install-desktopshell.sh
# Non-destructive Live Setup of ReactShell Desktop Environment on Windows Core
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ISO_DIR="${REPO_ROOT}/iso"

VM_HOST="${VM_HOST:-127.0.0.1}"
VM_PORT="${VM_PORT:-2222}"
VM_USER="${VM_USER:-samuelcaldas}"
VM_PASS="${VM_PASS:-hebroN@1994}"

SHELL_PROVIDER="${1:-ReactShell}"
FILE_MANAGER="${2:-ReactFM}"

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

ensure_reactshell_package() {
    if [ ! -f "${ISO_DIR}/reactshell_x64.zip" ]; then
        log_info "Packaging ReactShell binaries into ${ISO_DIR}/reactshell_x64.zip..."
        mkdir -p "${ISO_DIR}"
        local RS_BIN_DIR=""
        if [ -d "${REPO_ROOT}/external/ReactShell/build/bin" ] && [ -f "${REPO_ROOT}/external/ReactShell/build/bin/react-shell.exe" ]; then
            RS_BIN_DIR="${REPO_ROOT}/external/ReactShell/build/bin"
        elif [ -d "/home/samuelcaldas/repos/ReactShell/build/bin" ] && [ -f "/home/samuelcaldas/repos/ReactShell/build/bin/react-shell.exe" ]; then
            RS_BIN_DIR="/home/samuelcaldas/repos/ReactShell/build/bin"
        fi

        if [ -n "${RS_BIN_DIR}" ]; then
            7z a -tzip "${ISO_DIR}/reactshell_x64.zip" "${RS_BIN_DIR}/"* >/dev/null
            log_success "ReactShell package generated successfully."
        else
            log_error "ReactShell binaries not found. Please build ReactShell first."
            exit 1
        fi
    fi
}

main() {
    echo "=============================================================================="
    echo "  Windows Core - Desktop Shell (${SHELL_PROVIDER} / ${FILE_MANAGER}) Deployment"
    echo "=============================================================================="

    ensure_reactshell_package

    # 1. Prepare remote staging directories
    log_info "Preparing guest provisioning directories..."
    run_ssh "powershell -Command \"New-Item -ItemType Directory -Path 'C:\\Provisioning\\packages', 'C:\\Provisioning\\scripts' -Force | Out-Null\""

    # 2. Transfer packages and script
    log_info "Transferring desktop shell packages to guest..."
    if [ -f "${ISO_DIR}/reactshell_x64.zip" ]; then
        run_scp "${ISO_DIR}/reactshell_x64.zip" "C:/Provisioning/packages/reactshell_x64.zip"
    fi
    if [ -f "${ISO_DIR}/winxshell_x64.zip" ]; then
        run_scp "${ISO_DIR}/winxshell_x64.zip" "C:/Provisioning/packages/winxshell_x64.zip"
    fi
    if [ -f "${ISO_DIR}/explorerpp_x64.zip" ]; then
        run_scp "${ISO_DIR}/explorerpp_x64.zip" "C:/Provisioning/packages/explorerpp_x64.zip"
    fi
    if [ -f "${ISO_DIR}/winfile_x64.zip" ]; then
        run_scp "${ISO_DIR}/winfile_x64.zip" "C:/Provisioning/packages/winfile_x64.zip"
    fi
    if [ -f "${REPO_ROOT}/config/explorerpp/config.xml" ]; then
        run_scp "${REPO_ROOT}/config/explorerpp/config.xml" "C:/Provisioning/packages/config.xml"
    fi
    if [ -f "${REPO_ROOT}/config/winxshell/WinXShell.lua" ]; then
        run_scp "${REPO_ROOT}/config/winxshell/WinXShell.lua" "C:/Provisioning/packages/WinXShell.lua"
    fi
    if [ -f "${REPO_ROOT}/config/winxshell/shell-settings.reg" ]; then
        run_scp "${REPO_ROOT}/config/winxshell/shell-settings.reg" "C:/Provisioning/packages/shell-settings.reg"
    fi
    if [ -f "${REPO_ROOT}/config/wallpaper/wallpaper.jpg" ]; then
        run_scp "${REPO_ROOT}/config/wallpaper/wallpaper.jpg" "C:/Provisioning/packages/wallpaper.jpg"
    fi
    if [ -f "${REPO_ROOT}/config/wallpaper/wallpaper.bmp" ]; then
        run_scp "${REPO_ROOT}/config/wallpaper/wallpaper.bmp" "C:/Provisioning/packages/wallpaper.bmp"
    fi
    if [ -f "${REPO_ROOT}/config/wallpaper/oemlogo.bmp" ]; then
        run_scp "${REPO_ROOT}/config/wallpaper/oemlogo.bmp" "C:/Provisioning/packages/oemlogo.bmp"
    fi
    run_scp "${REPO_ROOT}/scripts/guest/Install-DesktopShell.ps1" "C:/Provisioning/scripts/Install-DesktopShell.ps1"

    # 3. Execute Guest Installation Script
    log_info "Executing Install-DesktopShell.ps1 on Windows Core..."
    run_ssh "powershell -ExecutionPolicy Bypass -File 'C:\\Provisioning\\scripts\\Install-DesktopShell.ps1' -ShellProvider '${SHELL_PROVIDER}' -FileManager '${FILE_MANAGER}'"

    # 4. Verification
    log_info "Verifying desktop shell deployment..."
    run_ssh "powershell -Command \"
        Write-Host '--- Winlogon Shell ---'
        (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon').Shell
        Write-Host '--- Default Folder Handler ---'
        (Get-ItemProperty 'HKLM:\SOFTWARE\Classes\Folder\shell\open\command').'(Default)'
        Write-Host '--- Desktop Shortcuts in Public Desktop ---'
        Get-ChildItem 'C:\Users\Public\Desktop' -ErrorAction SilentlyContinue | Select-Object Name
    \""

    log_success "Desktop shell setup (${SHELL_PROVIDER} / ${FILE_MANAGER}) completed successfully."
}

main
