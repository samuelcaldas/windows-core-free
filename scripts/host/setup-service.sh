#!/usr/bin/env bash
# ==============================================================================
# scripts/host/setup-service.sh
# Systemd Autostart Service Orchestrator for Windows Core VM (Ubuntu Host)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SERVICE_NAME="windows-core.service"
SERVICE_DEST="/etc/systemd/system/${SERVICE_NAME}"
TEMPLATE_PATH="${REPO_ROOT}/config/systemd/windows-core.service"

CURRENT_USER="$(id -un)"
CURRENT_GROUP="$(id -gn)"

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

run_as_root() {
    local CMD="$1"
    if [ "$(id -u)" -eq 0 ]; then
        eval "${CMD}"
    else
        ssh root@localhost "${CMD}"
    fi
}

generate_service_unit() {
    cat <<EOF
[Unit]
Description=Windows CoreOS (WCOS) Virtual Machine (QEMU/KVM)
Documentation=https://github.com/samuelcaldas/windows-core-free
After=network.target network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${CURRENT_USER}
Group=${CURRENT_GROUP}
SupplementaryGroups=kvm
WorkingDirectory=${REPO_ROOT}
ExecStart=${REPO_ROOT}/scripts/host/run-vm.sh --foreground
ExecStop=${REPO_ROOT}/scripts/host/run-vm.sh --stop
Restart=on-failure
RestartSec=10s
TimeoutStopSec=60s
KillMode=control-group
PIDFile=${REPO_ROOT}/.windows-core-qemu.pid

[Install]
WantedBy=multi-user.target
EOF
}

cmd_install() {
    local AUTO_START="${1:-true}"

    log_info "Configuring systemd autostart service for Windows Core..."
    log_info "Repository root: ${REPO_ROOT}"
    log_info "Service user:    ${CURRENT_USER}:${CURRENT_GROUP} (Supplementary: kvm)"

    # Generate unit definition
    local TEMP_UNIT
    TEMP_UNIT="$(mktemp /tmp/windows-core-unit.XXXXXX)"
    generate_service_unit > "${TEMP_UNIT}"

    # Also keep repo template up to date
    mkdir -p "${REPO_ROOT}/config/systemd"
    cp "${TEMP_UNIT}" "${TEMPLATE_PATH}"

    log_info "Installing unit file to ${SERVICE_DEST} via root SSH..."
    if [ "$(id -u)" -eq 0 ]; then
        cp "${TEMP_UNIT}" "${SERVICE_DEST}"
        chmod 644 "${SERVICE_DEST}"
    else
        scp -q "${TEMP_UNIT}" "root@localhost:${SERVICE_DEST}"
        run_as_root "chmod 644 ${SERVICE_DEST}"
    fi
    rm -f "${TEMP_UNIT}"

    log_info "Reloading systemd daemon..."
    run_as_root "systemctl daemon-reload"

    log_info "Enabling ${SERVICE_NAME} for automatic boot on Ubuntu startup..."
    run_as_root "systemctl enable ${SERVICE_NAME}"
    log_success "Service ${SERVICE_NAME} enabled for automatic startup on Ubuntu boot."

    if [ "${AUTO_START}" = "true" ]; then
        log_info "Starting ${SERVICE_NAME} now..."
        run_as_root "systemctl start ${SERVICE_NAME}"
        sleep 2
        cmd_status
    fi
}

cmd_enable() {
    log_info "Enabling ${SERVICE_NAME} on Ubuntu system startup..."
    run_as_root "systemctl enable ${SERVICE_NAME}"
    log_success "${SERVICE_NAME} is now enabled for autostart."
}

cmd_disable() {
    log_info "Disabling ${SERVICE_NAME} from Ubuntu system startup..."
    run_as_root "systemctl disable ${SERVICE_NAME}"
    log_success "${SERVICE_NAME} autostart disabled."
}

cmd_start() {
    log_info "Starting ${SERVICE_NAME}..."
    run_as_root "systemctl start ${SERVICE_NAME}"
    sleep 2
    cmd_status
}

cmd_stop() {
    log_info "Stopping ${SERVICE_NAME} (graceful ACPI shutdown)..."
    run_as_root "systemctl stop ${SERVICE_NAME}"
    log_success "${SERVICE_NAME} stopped."
}

cmd_restart() {
    log_info "Restarting ${SERVICE_NAME}..."
    run_as_root "systemctl restart ${SERVICE_NAME}"
    sleep 2
    cmd_status
}

cmd_status() {
    if run_as_root "systemctl is-active --quiet ${SERVICE_NAME}" 2>/dev/null; then
        log_success "${SERVICE_NAME} is ACTIVE and RUNNING."
    else
        log_warn "${SERVICE_NAME} is INACTIVE or STOPPED."
    fi

    if run_as_root "systemctl is-enabled --quiet ${SERVICE_NAME}" 2>/dev/null; then
        echo -e "  - Autostart on boot: ${GREEN}ENABLED${NC}"
    else
        echo -e "  - Autostart on boot: ${YELLOW}DISABLED${NC}"
    fi

    echo ""
    systemctl status "${SERVICE_NAME}" --no-pager --lines=10 || true
}

cmd_logs() {
    log_info "Displaying systemd journal logs for ${SERVICE_NAME} (Ctrl+C to exit)..."
    journalctl -u "${SERVICE_NAME}" -n 50 -f
}

cmd_uninstall() {
    log_info "Uninstalling ${SERVICE_NAME}..."
    run_as_root "systemctl stop ${SERVICE_NAME} 2>/dev/null || true"
    run_as_root "systemctl disable ${SERVICE_NAME} 2>/dev/null || true"
    run_as_root "rm -f ${SERVICE_DEST}"
    run_as_root "systemctl daemon-reload"
    log_success "Service ${SERVICE_NAME} uninstalled completely."
}

usage() {
    echo "Usage: $0 [ACTION]"
    echo ""
    echo "Actions:"
    echo "  --install, -i      Install, configure, enable on boot, and start the systemd service (default)"
    echo "  --enable, -e       Enable service to autostart on Ubuntu system boot"
    echo "  --disable, -d      Disable service autostart on Ubuntu boot"
    echo "  --start            Start the Windows Core VM service"
    echo "  --stop             Stop the Windows Core VM service gracefully"
    echo "  --restart, -r      Restart the Windows Core VM service"
    echo "  --status, -s       Check systemd service status and boot enable state"
    echo "  --logs, -l         Follow live systemd journal logs"
    echo "  --uninstall, -u    Stop, disable, and remove the systemd service"
    echo "  --help, -h         Show this help message"
    echo ""
}

main() {
    local ACTION="${1:---install}"

    case "${ACTION}" in
        --install|-i)
            cmd_install "true"
            ;;
        --install-only)
            cmd_install "false"
            ;;
        --enable|-e)
            cmd_enable
            ;;
        --disable|-d)
            cmd_disable
            ;;
        --start)
            cmd_start
            ;;
        --stop)
            cmd_stop
            ;;
        --restart|-r)
            cmd_restart
            ;;
        --status|-s)
            cmd_status
            ;;
        --logs|-l)
            cmd_logs
            ;;
        --uninstall|-u)
            cmd_uninstall
            ;;
        --help|-h)
            usage
            ;;
        *)
            log_error "Unknown option: ${ACTION}"
            usage
            exit 1
            ;;
    esac
}

main "$@"
