#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Phase 1: Host Environment & Virtualization Tooling Setup (PowerShell 7)
.DESCRIPTION
    Validates KVM support, installs host dependencies (QEMU, OVMF, wimtools, ISO tools),
    downloads stable VirtIO Windows drivers, and validates acceptance criteria.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot  = (Resolve-Path "$ScriptDir/../..").Path
$IsoDir    = Join-Path $RepoRoot "iso"
$VirtioIso = Join-Path $IsoDir "virtio-win.iso"
$VirtioUrl = "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso"

function Write-Step {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-WarnMessage {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-ErrorMessage {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Assert-KvmSupport {
    Write-Step "Validating KVM hardware virtualization support..."
    if (-not (Test-Path "/dev/kvm")) {
        Write-ErrorMessage "/dev/kvm not found! Hardware virtualization is disabled in BIOS or unsupported."
        exit 1
    }
    Write-Success "KVM acceleration is available and operational."
}

function Install-HostPackages {
    Write-Step "Checking and installing required host packages via root SSH..."
    $packages = @(
        "qemu-system-x86",
        "qemu-utils",
        "ovmf",
        "cloud-image-utils",
        "genisoimage",
        "xorriso",
        "wimtools",
        "mtools",
        "curl",
        "ca-certificates"
    ) -join " "

    & ssh root@localhost "apt-get update -qq && apt-get install -y $packages"
    if ($LASTEXITCODE -ne 0) {
        Write-ErrorMessage "Failed to install required host packages."
        exit $LASTEXITCODE
    }
    Write-Success "Core virtualization and ISO packages installed."
}

function Get-VirtIoIso {
    if (-not (Test-Path $IsoDir)) {
        New-Item -ItemType Directory -Path $IsoDir -Force | Out-Null
    }

    if ((Test-Path $VirtioIso) -and ((Get-Item $VirtioIso).Length -gt 0)) {
        $sizeMb = [math]::Round((Get-Item $VirtioIso).Length / 1MB, 2)
        Write-Step "VirtIO ISO already cached at $VirtioIso ($sizeMb MB)."
        return
    }

    Write-Step "Downloading stable VirtIO Windows drivers ISO from Fedora..."
    Write-Step "URL: $VirtioUrl"
    $tmpIso = "$VirtioIso.tmp"
    
    & curl -L --fail --retry 3 --retry-delay 2 -C - -o $tmpIso $VirtioUrl
    if ($LASTEXITCODE -ne 0) {
        Write-ErrorMessage "Failed to download VirtIO ISO."
        exit $LASTEXITCODE
    }

    Move-Item -Path $tmpIso -Destination $VirtioIso -Force
    Write-Success "VirtIO ISO downloaded successfully ($VirtioIso)."
}

function Test-Phase1Environment {
    Write-Step "Verifying Phase 1 acceptance criteria..."
    $commands = @("qemu-system-x86_64", "qemu-img", "xorriso", "wimlib-imagex", "pwsh")
    $missing = 0

    foreach ($cmd in $commands) {
        $path = Get-Command $cmd -ErrorAction SilentlyContinue
        if ($null -ne $path) {
            Write-Host "  - $cmd : " -NoNewline
            Write-Host "OK" -ForegroundColor Green -NoNewline
            Write-Host " ($($path.Source))"
        }
        else {
            Write-Host "  - $cmd : " -NoNewline
            Write-Host "MISSING" -ForegroundColor Red
            $missing++
        }
    }

    if (Test-Path $VirtioIso) {
        Write-Host "  - VirtIO ISO: " -NoNewline
        Write-Host "OK" -ForegroundColor Green -NoNewline
        Write-Host " ($VirtioIso)"
    }
    else {
        Write-Host "  - VirtIO ISO: " -NoNewline
        Write-Host "MISSING" -ForegroundColor Red
        $missing++
    }

    if ($missing -eq 0) {
        Write-Success "Phase 1 Host Setup successfully verified and complete!"
    }
    else {
        Write-ErrorMessage "Phase 1 verification failed with $missing missing requirement(s)."
        exit 1
    }
}

function Main {
    Write-Host "=============================================================================="
    Write-Host "  Windows Core Headless Host - Phase 1 Setup (PowerShell 7)"
    Write-Host "=============================================================================="
    Assert-KvmSupport
    Install-HostPackages
    Get-VirtIoIso
    Test-Phase1Environment
}

Main
