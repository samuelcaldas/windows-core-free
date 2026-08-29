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
# 4. Host Environment Verification
# ------------------------------------------------------------------------------
verify_environment() {
    log_info "Verifying Phase 1 acceptance criteria..."

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

    if [ "${MISSING}" -eq 0 ]; then
        log_success "Phase 1 Host Setup successfully verified and complete!"
    else
        log_error "Phase 1 verification failed with ${MISSING} missing requirement(s)."
        exit 1
    fi
}

main() {
    echo "=============================================================================="
    echo "  Windows Core Headless Host - Phase 1 Setup"
    echo "=============================================================================="
    check_kvm
    install_packages
    fetch_virtio_iso
    verify_environment
}

main "$@"
