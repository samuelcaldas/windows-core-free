#!/usr/bin/env bash
# ==============================================================================
# scripts/host/setup-host.sh
# Phase 1: Host Environment & Virtualization Tooling Setup
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ISO_DIR="${REPO_ROOT}/iso"
VIRTIO_ISO="${ISO_DIR}/virtio-win.iso"
VIRTIO_URL="https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso"

# Official Microsoft Hyper-V Server 2019 OEM ISO
MS_ISO_NAME="17763.737.190906-2324.rs5_release_svc_refresh_SERVERHYPERCORE_OEM_x64FRE_en-us_1.iso"
MS_ISO_PATH="${ISO_DIR}/${MS_ISO_NAME}"
MS_ISO_URL="https://software-download.microsoft.com/download/pr/${MS_ISO_NAME}"
MS_ISO_SHA256="48e9b944518e5bbc80876a9a7ff99716f386f404f4be48dca47e16a66ae7872c"

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

# ------------------------------------------------------------------------------
# 1. KVM Acceleration Validation
# ------------------------------------------------------------------------------
check_kvm() {
    log_info "Validating KVM hardware acceleration support..."
    if [ ! -e /dev/kvm ]; then
        log_error "/dev/kvm not found! Hardware virtualization is either disabled in BIOS or unsupported."
        exit 1
    fi

    if [ ! -r /dev/kvm ] || [ ! -w /dev/kvm ]; then
        log_warn "Current user cannot read/write /dev/kvm directly. Adding user to 'kvm' group..."
        ssh root@localhost "usermod -aG kvm ${USER}"
        log_warn "User added to 'kvm' group. You may need to refresh group membership (e.g. 'newgrp kvm')."
    fi

    log_success "KVM acceleration is available and operational."
}

# ------------------------------------------------------------------------------
# 2. Host Package Installation
# ------------------------------------------------------------------------------
install_packages() {
    log_info "Checking and installing required host packages via root SSH..."

    local REQUIRED_PACKAGES=(
        "qemu-system-x86"
        "qemu-utils"
        "ovmf"
        "cloud-image-utils"
        "genisoimage"
        "xorriso"
        "wimtools"
        "mtools"
        "curl"
        "ca-certificates"
    )

    ssh root@localhost "apt-get update -qq && apt-get install -y ${REQUIRED_PACKAGES[*]}"
    log_success "Core virtualization and ISO packages installed."

    # Install PowerShell via snap if pwsh is missing
    if ! command -v pwsh &>/dev/null; then
        log_info "Installing PowerShell (pwsh) via snap..."
        ssh root@localhost "snap install powershell --classic"
        log_success "PowerShell installed."
    else
        log_info "PowerShell is already installed ($(pwsh --version))."
    fi
}

# ------------------------------------------------------------------------------
# 3. VirtIO Windows Drivers Download
# ------------------------------------------------------------------------------
fetch_virtio_iso() {
    mkdir -p "${ISO_DIR}"
    if [ -f "${VIRTIO_ISO}" ] && [ -s "${VIRTIO_ISO}" ]; then
        log_info "VirtIO ISO already cached at ${VIRTIO_ISO} ($(du -h "${VIRTIO_ISO}" | cut -f1))."
    else
        log_info "Downloading stable VirtIO Windows drivers ISO from Fedora..."
        log_info "URL: ${VIRTIO_URL}"
        curl -L --fail --retry 3 --retry-delay 2 -C - -o "${VIRTIO_ISO}.tmp" "${VIRTIO_URL}"
        mv "${VIRTIO_ISO}.tmp" "${VIRTIO_ISO}"
        log_success "VirtIO ISO downloaded successfully (${VIRTIO_ISO})."
    fi
}

# ------------------------------------------------------------------------------
# 4. Official Microsoft Hyper-V Server 2019 ISO Download
# ------------------------------------------------------------------------------
fetch_microsoft_iso() {
    mkdir -p "${ISO_DIR}"
    if [ -f "${MS_ISO_PATH}" ] && [ -s "${MS_ISO_PATH}" ]; then
        log_info "Verifying existing official Microsoft ISO checksum..."
        local ACTUAL_HASH
        ACTUAL_HASH="$(sha256sum "${MS_ISO_PATH}" | awk '{print $1}')"
        if [ "${ACTUAL_HASH}" = "${MS_ISO_SHA256}" ]; then
            log_success "Official Microsoft ISO verified (SHA256: ${ACTUAL_HASH})."
            return 0
        else
            log_warn "Checksum mismatch on existing ISO. Re-downloading from Microsoft..."
        fi
    fi

    log_info "Downloading official Microsoft Hyper-V Server 2019 OEM ISO (~2.8GB)..."
    log_info "Source: ${MS_ISO_URL}"
    log_info "Destination: ${MS_ISO_PATH}"
    curl -L --fail --retry 5 --retry-delay 3 -C - -o "${MS_ISO_PATH}.tmp" "${MS_ISO_URL}"

    log_info "Verifying downloaded ISO integrity..."
    local DOWNLOADED_HASH
    DOWNLOADED_HASH="$(sha256sum "${MS_ISO_PATH}.tmp" | awk '{print $1}')"
    if [ "${DOWNLOADED_HASH}" != "${MS_ISO_SHA256}" ]; then
        log_error "SHA256 verification failed! Expected ${MS_ISO_SHA256}, got ${DOWNLOADED_HASH}."
        rm -f "${MS_ISO_PATH}.tmp"
        exit 1
    fi

    mv "${MS_ISO_PATH}.tmp" "${MS_ISO_PATH}"
    log_success "Official Microsoft ISO downloaded and verified successfully."
}

# ------------------------------------------------------------------------------
# 5. Host Environment Verification
# ------------------------------------------------------------------------------
verify_environment() {
    log_info "Verifying host acceptance criteria..."

    local MISSING=0
    for cmd in qemu-system-x86_64 qemu-img xorriso mkisofs wimlib-imagex pwsh; do
        if command -v "${cmd}" &>/dev/null; then
            echo -e "  - ${cmd}: ${GREEN}OK${NC} ($(command -v "${cmd}"))"
        elif [ "${cmd}" = "mkisofs" ] && command -v genisoimage &>/dev/null; then
            echo -e "  - mkisofs (genisoimage): ${GREEN}OK${NC} ($(command -v genisoimage))"
        else
            echo -e "  - ${cmd}: ${RED}MISSING${NC}"
            MISSING=$((MISSING + 1))
        fi
    done

    if [ -f "${VIRTIO_ISO}" ]; then
        echo -e "  - VirtIO ISO: ${GREEN}OK${NC} (${VIRTIO_ISO})"
    else
        echo -e "  - VirtIO ISO: ${RED}MISSING${NC}"
        MISSING=$((MISSING + 1))
    fi

    if [ -f "${MS_ISO_PATH}" ]; then
        echo -e "  - Microsoft Windows Core 2019 ISO: ${GREEN}OK${NC} (${MS_ISO_PATH})"
    else
        echo -e "  - Microsoft Windows Core 2019 ISO: ${YELLOW}NOT FOUND (Run with --download-iso)${NC}"
    fi

    if [ "${MISSING}" -eq 0 ]; then
        log_success "Host Setup successfully verified and operational!"
    else
        log_error "Host verification failed with ${MISSING} missing requirement(s)."
        exit 1
    fi
}

main() {
    echo "=============================================================================="
    echo "  Windows CoreOS (WCOS) - Host Environment & Virtualization Setup"
    echo "=============================================================================="

    local DOWNLOAD_MS_ISO=false
    for arg in "$@"; do
        case "${arg}" in
            --download-iso|-d)
                DOWNLOAD_MS_ISO=true
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo "Options:"
                echo "  --download-iso, -d   Download and verify official Microsoft Hyper-V Server 2019 ISO (~2.8GB)"
                echo "  --help, -h           Show this help message"
                exit 0
                ;;
        esac
    done

    check_kvm
    install_packages
    fetch_virtio_iso

    if [ "${DOWNLOAD_MS_ISO}" = true ]; then
        fetch_microsoft_iso
    fi

    verify_environment
}

main "$@"
