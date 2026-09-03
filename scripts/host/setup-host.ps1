#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Phase 1: Host Environment & Virtualization Tooling Setup (PowerShell 7)
.DESCRIPTION
    Validates KVM support, installs host dependencies (QEMU, OVMF, wimtools, ISO tools),
    downloads stable VirtIO Windows drivers, and validates acceptance criteria.
#>
[CmdletBinding()]
param(
    [Alias('d')]
    [switch]$DownloadIso
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot  = (Resolve-Path "$ScriptDir/../..").Path
$IsoDir    = Join-Path $RepoRoot "iso"
$VirtioIso = Join-Path $IsoDir "virtio-win.iso"
$VirtioUrl = "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso"

# Official Microsoft Hyper-V Server 2019 OEM ISO
$MsIsoName   = "17763.737.190906-2324.rs5_release_svc_refresh_SERVERHYPERCORE_OEM_x64FRE_en-us_1.iso"
$MsIsoPath   = Join-Path $IsoDir $MsIsoName
$MsIsoUrl    = "https://software-download.microsoft.com/download/pr/$MsIsoName"
$MsIsoSha256 = "48e9b944518e5bbc80876a9a7ff99716f386f404f4be48dca47e16a66ae7872c"

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

function Get-MicrosoftIso {
    if (-not (Test-Path $IsoDir)) { New-Item -ItemType Directory -Path $IsoDir -Force | Out-Null }
    if (Test-Path $MsIsoPath) {
        Write-Step "Verifying existing official Microsoft ISO checksum..."
        $actualHash = (Get-FileHash -Path $MsIsoPath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actualHash -eq $MsIsoSha256.ToLowerInvariant()) {
            Write-Success "Official Microsoft ISO verified (SHA256: $actualHash)."
            return
        }
        else {
            Write-WarnMessage "Checksum mismatch on existing ISO. Re-downloading from Microsoft..."
        }
    }

    Write-Step "Downloading official Microsoft Hyper-V Server 2019 OEM ISO (~2.8GB)..."
    Write-Step "Source: $MsIsoUrl"
    $tmpIso = "$MsIsoPath.tmp"
    & curl -L --fail --retry 5 --retry-delay 3 -C - -o $tmpIso $MsIsoUrl

    Write-Step "Verifying downloaded ISO integrity..."
    $downloadedHash = (Get-FileHash -Path $tmpIso -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($downloadedHash -ne $MsIsoSha256.ToLowerInvariant()) {
        Remove-Item -Path $tmpIso -Force -ErrorAction SilentlyContinue
        throw "SHA256 verification failed! Expected $MsIsoSha256, got $downloadedHash."
    }

    Move-Item -Path $tmpIso -Destination $MsIsoPath -Force
    Write-Success "Official Microsoft ISO downloaded and verified successfully."
}

function Test-Phase1Environment {
    Write-Step "Verifying host acceptance criteria..."

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

    if (Test-Path $MsIsoPath) {
        Write-Host "  - Microsoft Windows Core 2019 ISO: " -NoNewline
        Write-Host "OK" -ForegroundColor Green -NoNewline
        Write-Host " ($MsIsoPath)"
    }
    else {
        Write-Host "  - Microsoft Windows Core 2019 ISO: " -NoNewline
        Write-Host "NOT FOUND (Run with -DownloadIso)" -ForegroundColor Yellow
    }

    if ($missing -eq 0) {
        Write-Success "Host Setup successfully verified and operational!"
    }
    else {
        Write-ErrorMessage "Host verification failed with $missing missing requirement(s)."
        exit 1
    }
}

function Main {
    Write-Host "=============================================================================="
    Write-Host "  Windows CoreOS (WCOS) - Host Environment & Virtualization Setup (PowerShell 7)"
    Write-Host "=============================================================================="
    Assert-KvmSupport
    Install-HostPackages
    Get-VirtIoIso

    if ($DownloadIso) {
        Get-MicrosoftIso
    }

    Test-Phase1Environment
}

Main
