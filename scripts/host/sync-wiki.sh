#!/usr/bin/env bash
# ==============================================================================
# scripts/host/sync-wiki.sh
# Synchronizes WCOS Wiki pages to GitHub Wiki repository
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
WIKI_SRC="${REPO_ROOT}/wiki"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

WIKI_GIT_URL="${WIKI_GIT_URL:-git@github.com:samuelcaldas/windows-core-free.wiki.git}"
WIKI_HTTPS_URL="https://github.com/samuelcaldas/windows-core-free.wiki.git"

main() {
    echo "=============================================================================="
    echo "  Windows CoreOS (WCOS) - GitHub Wiki Synchronization"
    echo "=============================================================================="

    if [ ! -d "${WIKI_SRC}" ]; then
        log_error "Wiki source directory '${WIKI_SRC}' does not exist."
        exit 1
    fi

    local PAGE_COUNT
    PAGE_COUNT=$(find "${WIKI_SRC}" -type f -name "*.md" | wc -l)
    log_info "Found ${PAGE_COUNT} wiki markdown pages in ${WIKI_SRC}."

    local TMP_DIR
    TMP_DIR=$(mktemp -d /tmp/wcos-wiki-sync.XXXXXX)
    trap 'rm -rf "${TMP_DIR}"' EXIT

    log_info "Attempting to clone GitHub Wiki repository..."
    if git clone "${WIKI_GIT_URL}" "${TMP_DIR}" 2>/dev/null || git clone "${WIKI_HTTPS_URL}" "${TMP_DIR}" 2>/dev/null; then
        log_info "Existing wiki cloned successfully."
    else
        log_warn "Wiki remote repository could not be cloned directly."
        log_warn "Initializing fresh Git repository for push..."
        git -C "${TMP_DIR}" init -b master
        git -C "${TMP_DIR}" remote add origin "${WIKI_GIT_URL}"
    fi

    log_info "Copying pages from ${WIKI_SRC}..."
    cp -r "${WIKI_SRC}"/* "${TMP_DIR}/"

    git -C "${TMP_DIR}" add .
    if git -C "${TMP_DIR}" diff --staged --quiet; then
        log_info "No changes to sync. GitHub Wiki is already up to date."
        exit 0
    fi

    local COMMIT_MSG="docs(wiki): synchronize WCOS wiki pages ($(date -u +'%Y-%m-%d %H:%M:%SZ'))"
    git -C "${TMP_DIR}" commit -m "${COMMIT_MSG}"

    log_info "Pushing wiki pages to GitHub..."
    if git -C "${TMP_DIR}" push origin master || git -C "${TMP_DIR}" push origin HEAD:master; then
        log_success "GitHub Wiki synchronized successfully!"
    else
        log_error "Failed to push to GitHub Wiki."
        log_warn "Note: GitHub requires the first wiki page to be initialized via the web UI."
        log_warn "Visit https://github.com/samuelcaldas/windows-core-free/wiki and click 'Create the first page' once, then re-run this script."
        exit 1
    fi
}

main "$@"
