#!/usr/bin/env bash
# ==============================================================================
# scripts/host/run-vm.sh
# Phase 2: QEMU / KVM Virtual Machine Orchestrator for Windows CoreOS (WCOS)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ISO_DIR="${REPO_ROOT}/iso"

# VM Configuration
VM_NAME="windows-core"
VM_DISK="${REPO_ROOT}/windows-core.qcow2"
VM_DISK_SIZE="${VM_DISK_SIZE:-64G}"
VM_RAM="${VM_RAM:-4096}"
VM_CPUS="${VM_CPUS:-4}"

# Port Map (Host -> Guest)
PORT_SSH="${PORT_SSH:-2222}"
PORT_WINRM_HTTP="${PORT_WINRM_HTTP:-5985}"
PORT_WINRM_HTTPS="${PORT_WINRM_HTTPS:-5986}"
PORT_DAEMON="${PORT_DAEMON:-9090}"
VNC_DISPLAY="${VNC_DISPLAY:-:1}" # 127.0.0.1:5901

# Files & Sockets
PID_FILE="${REPO_ROOT}/.windows-core-qemu.pid"
MONITOR_SOCK="${REPO_ROOT}/.windows-core-monitor.sock"
INSTALLER_ISO="${ISO_DIR}/windows-core-installer.iso"
VIRTIO_ISO="${ISO_DIR}/virtio-win.iso"
OVMF_CODE="/usr/share/OVMF/OVMF_CODE_4M.ms.fd"
OVMF_VARS_SRC="/usr/share/OVMF/OVMF_VARS_4M.ms.fd"
OVMF_VARS_LOCAL="${ISO_DIR}/OVMF_VARS.fd"

# Fallbacks for standard OVMF if MS secureboot keys not present
if [ ! -f "${OVMF_CODE}" ]; then
    OVMF_CODE="/usr/share/OVMF/OVMF_CODE_4M.fd"
    OVMF_VARS_SRC="/usr/share/OVMF/OVMF_VARS_4M.fd"
fi

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

is_vm_running() {
    if [ -f "${PID_FILE}" ]; then
        local pid
        pid=$(cat "${PID_FILE}")
        if kill -0 "${pid}" 2>/dev/null; then
            return 0
        fi
        rm -f "${PID_FILE}"
    fi
    return 1
}

init_uefi_vars() {
    mkdir -p "${ISO_DIR}"
    if [ ! -f "${OVMF_VARS_LOCAL}" ]; then
        log_info "Initializing UEFI VARS firmware (${OVMF_VARS_LOCAL})..."
        cp "${OVMF_VARS_SRC}" "${OVMF_VARS_LOCAL}"
    fi
}

create_disk_if_missing() {
    if [ ! -f "${VM_DISK}" ]; then
        log_info "Creating sparse dynamic QCOW2 virtual disk (${VM_DISK}, ${VM_DISK_SIZE})..."
        qemu-img create -f qcow2 "${VM_DISK}" "${VM_DISK_SIZE}"
        log_success "Virtual disk created."
    else
        log_info "Virtual disk found: ${VM_DISK} ($(du -h "${VM_DISK}" | cut -f1))"
    fi
}

check_install_prerequisites() {
    if [ ! -f "${INSTALLER_ISO}" ]; then
        log_warn "Unattended installer ISO missing. Running build-iso.sh..."
        "${SCRIPT_DIR}/build-iso.sh"
    fi

    if [ ! -f "${VIRTIO_ISO}" ]; then
        log_warn "VirtIO ISO missing. Running setup-host.sh..."
        "${SCRIPT_DIR}/setup-host.sh"
    fi
}

cmd_status() {
    if is_vm_running; then
        local pid
        pid=$(cat "${PID_FILE}")
        log_success "Windows Core VM is RUNNING (PID: ${pid})"
        echo "  - SSH Forwarding: localhost:${PORT_SSH} -> Guest:22"
        echo "  - WinRM HTTP:     localhost:${PORT_WINRM_HTTP} -> Guest:5985"
        echo "  - WinRM HTTPS:    localhost:${PORT_WINRM_HTTPS} -> Guest:5986"
        echo "  - Antigravity:    localhost:${PORT_DAEMON} -> Guest:9090"
        echo "  - VNC Console:    127.0.0.1:5901 (display ${VNC_DISPLAY})"
    else
        log_info "Windows Core VM is STOPPED."
    fi
}

cmd_stop() {
    if is_vm_running; then
        local pid
        pid=$(cat "${PID_FILE}")
        log_info "Stopping Windows Core VM (PID: ${pid})..."

        # 1. Attempt graceful ACPI shutdown via QEMU monitor socket
        if [ -S "${MONITOR_SOCK}" ]; then
            log_info "Sending ACPI system_powerdown signal to Windows guest..."
            python3 -c "import socket; s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM); s.connect('${MONITOR_SOCK}'); s.sendall(b'system_powerdown\n'); s.close()" 2>/dev/null || true
        else
            kill "${pid}" 2>/dev/null || true
        fi

        # Wait up to 30 seconds for guest to shut down cleanly
        for ((i=1; i<=30; i++)); do
            if ! kill -0 "${pid}" 2>/dev/null; then
                rm -f "${PID_FILE}" "${MONITOR_SOCK}"
                log_success "Windows CoreOS (WCOS) stopped cleanly."
                return 0
            fi
            sleep 1
        done

        # 2. Fallback to SIGTERM
        log_warn "VM did not exit within 30s, sending SIGTERM..."
        kill "${pid}" 2>/dev/null || true
        for ((i=1; i<=10; i++)); do
            if ! kill -0 "${pid}" 2>/dev/null; then
                rm -f "${PID_FILE}" "${MONITOR_SOCK}"
                log_success "Windows Core VM stopped via SIGTERM."
                return 0
            fi
            sleep 1
        done

        # 3. Final fallback to SIGKILL
        log_warn "VM did not exit after SIGTERM, sending SIGKILL..."
        kill -9 "${pid}" 2>/dev/null || true
        rm -f "${PID_FILE}" "${MONITOR_SOCK}"
        log_success "Windows Core VM killed."
    else
        log_info "Windows Core VM is not running."
    fi
}

start_qemu() {
    local MODE="$1"
    local DAEMON_MODE="${2:-false}"
    local FOREGROUND_MODE="${3:-false}"

    if is_vm_running; then
        log_warn "VM is already running (PID: $(cat "${PID_FILE}")). Stop it first."
        exit 0
    fi

    init_uefi_vars
    create_disk_if_missing
    rm -f "${MONITOR_SOCK}"

    local QEMU_ARGS=(
        qemu-system-x86_64
        -name "${VM_NAME},process=${VM_NAME}"
        -machine q35,accel=kvm,usb=off,vmport=off
        -cpu host,hv_relaxed,hv_spinlocks=0x1fff,hv_vapic,hv_time,hv_vpindex,hv_synic,hv_stimer,hv_frequencies
        -smp "cores=${VM_CPUS},threads=1,sockets=1"
        -m "${VM_RAM}"
        -rtc base=localtime,clock=host,driftfix=slew
        -drive "if=pflash,format=raw,readonly=on,file=${OVMF_CODE}"
        -drive "if=pflash,format=raw,file=${OVMF_VARS_LOCAL}"
        -device virtio-balloon-pci,id=balloon0
        -device virtio-scsi-pci,id=scsi0
        -drive "file=${VM_DISK},if=none,id=hd0,format=qcow2,cache=writeback,discard=unmap"
        -device scsi-hd,drive=hd0,bootindex=1
        -netdev "user,id=net0,hostfwd=tcp::${PORT_SSH}-:22,hostfwd=tcp::${PORT_WINRM_HTTP}-:5985,hostfwd=tcp::${PORT_WINRM_HTTPS}-:5986,hostfwd=tcp::${PORT_DAEMON}-:9090"
        -device virtio-net-pci,netdev=net0
        -vga std
        -display none
        -vnc "127.0.0.1${VNC_DISPLAY}"
        -monitor "unix:${MONITOR_SOCK},server,nowait"
        -pidfile "${PID_FILE}"
    )

    if [ "${MODE}" = "install" ]; then
        check_install_prerequisites
        log_info "Configuring unattended UEFI installer media..."
        QEMU_ARGS+=(
            -drive "file=${INSTALLER_ISO},media=cdrom,readonly=on"
            -drive "file=${VIRTIO_ISO},media=cdrom,readonly=on"
        )
    else
        # Normal run mode: attach VirtIO ISO for guest tools if available
        if [ -f "${VIRTIO_ISO}" ]; then
            QEMU_ARGS+=(-drive "file=${VIRTIO_ISO},media=cdrom,readonly=on")
        fi
    fi

    log_info "Starting QEMU VM (Mode: ${MODE}, RAM: ${VM_RAM}MB, CPUs: ${VM_CPUS})..."
    log_info "VNC Debug console: 127.0.0.1:5901"
    log_info "Forwarded ports: SSH=${PORT_SSH}, WinRM=${PORT_WINRM_HTTP}/${PORT_WINRM_HTTPS}, Daemon=${PORT_DAEMON}"

    if [ "${DAEMON_MODE}" = "true" ]; then
        "${QEMU_ARGS[@]}" -daemonize
        sleep 2
        if is_vm_running; then
            log_success "Windows Core VM started in background (PID: $(cat "${PID_FILE}"))."
        else
            log_error "Failed to start QEMU VM."
            exit 1
        fi
    elif [ "${FOREGROUND_MODE}" = "true" ]; then
        log_info "Running QEMU in foreground mode (systemd / interactive)..."
        echo "$$" > "${PID_FILE}"
        exec "${QEMU_ARGS[@]}"
    else
        "${QEMU_ARGS[@]}" &
        local pid=$!
        echo "${pid}" > "${PID_FILE}"
        log_success "Windows CoreOS (WCOS) VM started (PID: ${pid})."
    fi
}

usage() {
    echo "=============================================================================="
    echo "  Windows CoreOS (WCOS) - QEMU VM Orchestrator"
    echo "=============================================================================="
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --install, -i      Boot with unattended installer ISO for zero-touch install"
    echo "  --run, -r          Start installed Windows CoreOS VM (default)"
    echo "  --foreground, -f   Run VM in foreground mode (recommended for systemd services)"
    echo "  --daemon, -d       Run VM as background daemon"
    echo "  --status, -s       Check VM running status and port mapping"
    echo "  --stop             Gracefully stop the running VM via ACPI shutdown"
    echo "  --kill             Force kill the running VM"
    echo "  --help, -h         Show this help message"
    echo ""
}

main() {
    local ACTION="run"
    local DAEMON="false"
    local FOREGROUND="false"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --install|-i)
                ACTION="install"
                shift
                ;;
            --run|-r)
                ACTION="run"
                shift
                ;;
            --foreground|-f)
                FOREGROUND="true"
                shift
                ;;
            --daemon|-d)
                DAEMON="true"
                shift
                ;;
            --status|-s)
                cmd_status
                exit 0
                ;;
            --stop)
                cmd_stop
                exit 0
                ;;
            --kill)
                cmd_stop
                exit 0
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown argument: $1"
                usage
                exit 1
                ;;
        esac
    done

    start_qemu "${ACTION}" "${DAEMON}" "${FOREGROUND}"
}

main "$@"
