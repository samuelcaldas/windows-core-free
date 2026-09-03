#!/usr/bin/env bash
# ==============================================================================
# scripts/host/build-iso.sh
# Phase 2: Build Unattended Windows Core Bootable Installer ISO & OEMDRV Media
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ISO_DIR="${REPO_ROOT}/iso"
BASE_ISO="${ISO_DIR}/17763.737.190906-2324.rs5_release_svc_refresh_SERVERHYPERCORE_OEM_x64FRE_en-us_1.iso"
VIRTIO_ISO="${ISO_DIR}/virtio-win.iso"
INSTALLER_ISO="${ISO_DIR}/windows-core-installer.iso"
OEMDRV_ISO="${ISO_DIR}/oemdrv.iso"
UNATTEND_XML="${REPO_ROOT}/autounattend.xml"

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

STAGING_DIR=""
cleanup() {
    if [ -n "${STAGING_DIR}" ] && [ -d "${STAGING_DIR}" ]; then
        rm -rf "${STAGING_DIR}"
    fi
}
trap cleanup EXIT

check_prerequisites() {
    log_info "Validating build prerequisites..."
    if [ ! -f "${UNATTEND_XML}" ]; then
        log_error "Answer file not found: ${UNATTEND_XML}"
        exit 1
    fi

    if [ ! -f "${BASE_ISO}" ]; then
        log_error "Base Windows Hyper-V Server ISO not found: ${BASE_ISO}"
        exit 1
    fi

    if [ ! -f "${VIRTIO_ISO}" ]; then
        log_warn "VirtIO ISO missing. Running host setup to fetch it..."
        "${SCRIPT_DIR}/setup-host.sh"
    fi

    for cmd in 7z xorriso wimlib-imagex; do
        if ! command -v "${cmd}" &>/dev/null; then
            log_error "Required tool missing: ${cmd}. Run setup-host.sh first."
            exit 1
        fi
    done
}

build_unattended_installer_iso() {
    STAGING_DIR="$(mktemp -d -t win_installer_staging_XXXXXX)"
    log_info "Extracting base ISO into staging directory (${STAGING_DIR})..."

    # 1. Extract base ISO contents
    7z x -y "${BASE_ISO}" "-o${STAGING_DIR}" >/dev/null

    # 2. Copy autounattend.xml to ISO root
    log_info "Injecting autounattend.xml into ISO root..."
    cp "${UNATTEND_XML}" "${STAGING_DIR}/autounattend.xml"

    # 3. Inject autounattend.xml into boot.wim (WinPE Index 1 and Setup Index 2)
    local BOOT_WIM="${STAGING_DIR}/sources/boot.wim"
    if [ -f "${BOOT_WIM}" ]; then
        log_info "Slipstreaming autounattend.xml into boot.wim (Index 1 & 2)..."
        wimlib-imagex update "${BOOT_WIM}" 1 --command="add ${UNATTEND_XML} /autounattend.xml" --quiet || true
        wimlib-imagex update "${BOOT_WIM}" 2 --command="add ${UNATTEND_XML} /autounattend.xml" --quiet
    fi

    # 4. Extract VirtIO drivers into ISO
    log_info "Extracting VirtIO drivers into ISO image..."
    mkdir -p "${STAGING_DIR}/virtio"
    7z x -y "${VIRTIO_ISO}" \
        "-o${STAGING_DIR}/virtio" \
        "viostor/2k19/amd64/*" \
        "vioscsi/2k19/amd64/*" \
        "NetKVM/2k19/amd64/*" \
        "vioserial/2k19/amd64/*" \
        "Balloon/2k19/amd64/*" \
        "guest-agent/qemu-ga-x86_64.msi" \
        "virtio-win-guest-tools.exe" \
        "virtio-win-gt-x64.msi" >/dev/null

    # 5. Copy guest provisioning scripts
    log_info "Embedding guest provisioning scripts into ISO image..."
    mkdir -p "${STAGING_DIR}/scripts/guest"
    cp -r "${REPO_ROOT}/scripts/guest/"* "${STAGING_DIR}/scripts/guest/"

    # 6. Embed offline packages (OpenSSH, WinXShell, Explorer++)
    mkdir -p "${STAGING_DIR}/packages"
    if [ -f "${ISO_DIR}/OpenSSH-Win64.zip" ]; then
        log_info "Embedding offline Win32-OpenSSH package into ISO..."
        mkdir -p "${STAGING_DIR}/openssh"
        cp "${ISO_DIR}/OpenSSH-Win64.zip" "${STAGING_DIR}/openssh/"
    fi
    if [ -f "${ISO_DIR}/reactshell_x64.zip" ]; then
        log_info "Embedding ReactShell package into ISO..."
        cp "${ISO_DIR}/reactshell_x64.zip" "${STAGING_DIR}/packages/"
    fi
    if [ -f "${ISO_DIR}/winxshell_x64.zip" ]; then
        log_info "Embedding WinXShell desktop package into ISO..."
        cp "${ISO_DIR}/winxshell_x64.zip" "${STAGING_DIR}/packages/"
    fi
    if [ -f "${ISO_DIR}/explorerpp_x64.zip" ]; then
        log_info "Embedding Explorer++ package into ISO..."
        cp "${ISO_DIR}/explorerpp_x64.zip" "${STAGING_DIR}/packages/"
    fi
    if [ -f "${ISO_DIR}/winfile_x64.zip" ]; then
        log_info "Embedding WinFile package into ISO..."
        cp "${ISO_DIR}/winfile_x64.zip" "${STAGING_DIR}/packages/"
    fi
    if [ -f "${ISO_DIR}/terminal_x64.zip" ]; then
        log_info "Embedding Windows Terminal package into ISO..."
        cp "${ISO_DIR}/terminal_x64.zip" "${STAGING_DIR}/packages/"
    fi
    if [ -f "${ISO_DIR}/vc_redist.x64.exe" ]; then
        log_info "Embedding Visual C++ Redistributable into ISO..."
        cp "${ISO_DIR}/vc_redist.x64.exe" "${STAGING_DIR}/packages/"
    fi
    if [ -f "${REPO_ROOT}/config/explorerpp/config.xml" ]; then
        log_info "Embedding Explorer++ portable config.xml into ISO..."
        cp "${REPO_ROOT}/config/explorerpp/config.xml" "${STAGING_DIR}/packages/"
    fi
    if [ -f "${REPO_ROOT}/config/winxshell/WinXShell.lua" ]; then
        log_info "Embedding WinXShell.lua into ISO..."
        cp "${REPO_ROOT}/config/winxshell/WinXShell.lua" "${STAGING_DIR}/packages/"
    fi
    if [ -f "${REPO_ROOT}/config/winxshell/shell-settings.reg" ]; then
        log_info "Embedding shell-settings.reg into ISO..."
        cp "${REPO_ROOT}/config/winxshell/shell-settings.reg" "${STAGING_DIR}/packages/"
    fi
    if [ -d "${REPO_ROOT}/config/wallpaper" ]; then
        log_info "Embedding wallpaper and OEM branding into ISO..."
        cp -r "${REPO_ROOT}/config/wallpaper/"* "${STAGING_DIR}/packages/"
    fi
    if [ -f "${REPO_ROOT}/config/hosts/hosts" ]; then
        log_info "Embedding Dan Pollock hosts blocklist into ISO..."
        mkdir -p "${STAGING_DIR}/config/hosts"
        cp "${REPO_ROOT}/config/hosts/hosts" "${STAGING_DIR}/config/hosts/"
    fi
    if [ -d "${REPO_ROOT}/external/omniget" ]; then
        log_info "Packaging and embedding OmniGet (og) package into ISO..."
        (cd "${REPO_ROOT}/external/omniget" && zip -rq "${STAGING_DIR}/packages/omniget.zip" .)
    fi

    # 7. Build bootable ISO with UEFI + BIOS support
    log_info "Packaging bootable unattended ISO (${INSTALLER_ISO})..."
    rm -f "${INSTALLER_ISO}"

    xorriso -as mkisofs \
        -iso-level 4 \
        -l -R -J \
        -b boot/etfsboot.com \
        -no-emul-boot \
        -boot-load-size 8 \
        -boot-info-table \
        -eltorito-alt-boot \
        -e efi/microsoft/boot/efisys_noprompt.bin \
        -no-emul-boot \
        -boot-load-size 1 \
        -V "WINDOWS_CORE" \
        -o "${INSTALLER_ISO}" \
        "${STAGING_DIR}" 2>/dev/null

    log_success "Unattended installer ISO generated successfully (${INSTALLER_ISO}, $(du -h "${INSTALLER_ISO}" | cut -f1))."
}

build_oemdrv_media() {
    local OEM_STAGING
    OEM_STAGING="$(mktemp -d -t oemdrv_staging_XXXXXX)"
    
    log_info "Building standalone OEMDRV secondary ISO (${OEMDRV_ISO})..."
    cp "${UNATTEND_XML}" "${OEM_STAGING}/autounattend.xml"
    7z x -y "${VIRTIO_ISO}" \
        "-o${OEM_STAGING}" \
        "viostor/2k19/amd64/*" \
        "vioscsi/2k19/amd64/*" \
        "NetKVM/2k19/amd64/*" \
        "virtio-win-guest-tools.exe" >/dev/null

    mkdir -p "${OEM_STAGING}/scripts/guest"
    cp -r "${REPO_ROOT}/scripts/guest/"* "${OEM_STAGING}/scripts/guest/"

    mkdir -p "${OEM_STAGING}/packages"
    if [ -f "${ISO_DIR}/OpenSSH-Win64.zip" ]; then
        mkdir -p "${OEM_STAGING}/openssh"
        cp "${ISO_DIR}/OpenSSH-Win64.zip" "${OEM_STAGING}/openssh/"
    fi
    if [ -f "${ISO_DIR}/reactshell_x64.zip" ]; then
        cp "${ISO_DIR}/reactshell_x64.zip" "${OEM_STAGING}/packages/"
    fi
    if [ -f "${ISO_DIR}/winxshell_x64.zip" ]; then
        cp "${ISO_DIR}/winxshell_x64.zip" "${OEM_STAGING}/packages/"
    fi
    if [ -f "${ISO_DIR}/explorerpp_x64.zip" ]; then
        cp "${ISO_DIR}/explorerpp_x64.zip" "${OEM_STAGING}/packages/"
    fi
    if [ -f "${ISO_DIR}/terminal_x64.zip" ]; then
        cp "${ISO_DIR}/terminal_x64.zip" "${OEM_STAGING}/packages/"
    fi
    if [ -f "${ISO_DIR}/vc_redist.x64.exe" ]; then
        cp "${ISO_DIR}/vc_redist.x64.exe" "${OEM_STAGING}/packages/"
    fi
    if [ -f "${REPO_ROOT}/config/explorerpp/config.xml" ]; then
        cp "${REPO_ROOT}/config/explorerpp/config.xml" "${OEM_STAGING}/packages/"
    fi
    if [ -f "${REPO_ROOT}/config/winxshell/WinXShell.lua" ]; then
        cp "${REPO_ROOT}/config/winxshell/WinXShell.lua" "${OEM_STAGING}/packages/"
    fi
    if [ -f "${REPO_ROOT}/config/winxshell/shell-settings.reg" ]; then
        cp "${REPO_ROOT}/config/winxshell/shell-settings.reg" "${OEM_STAGING}/packages/"
    fi
    if [ -f "${REPO_ROOT}/config/hosts/hosts" ]; then
        mkdir -p "${OEM_STAGING}/config/hosts"
        cp "${REPO_ROOT}/config/hosts/hosts" "${OEM_STAGING}/config/hosts/"
    fi
    if [ -d "${REPO_ROOT}/external/omniget" ]; then
        log_info "Embedding OmniGet package into OEMDRV media..."
        (cd "${REPO_ROOT}/external/omniget" && zip -rq "${OEM_STAGING}/packages/omniget.zip" .)
    fi

    rm -f "${OEMDRV_ISO}"
    xorriso -as mkisofs \
        -quiet \
        -o "${OEMDRV_ISO}" \
        -V "OEMDRV" \
        -J -r -iso-level 3 \
        "${OEM_STAGING}"
    
    rm -rf "${OEM_STAGING}"
    log_success "OEMDRV secondary ISO generated successfully."
}

main() {
    echo "=============================================================================="
    echo "  Windows Core Headless Host - Build Unattended Installer ISO"
    echo "=============================================================================="
    check_prerequisites
    build_unattended_installer_iso
    build_oemdrv_media
}

main "$@"
