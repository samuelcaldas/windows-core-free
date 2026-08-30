#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Phase 2: Build Unattended Windows Core Bootable Installer ISO & OEMDRV (PowerShell 7)
.DESCRIPTION
    Extracts base ISO, injects autounattend.xml into boot.wim index 1 & 2, extracts VirtIO drivers,
    and builds a bootable unattended ISO with UEFI and BIOS support.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$ScriptDir     = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot      = (Resolve-Path "$ScriptDir/../..").Path
$IsoDir        = Join-Path $RepoRoot "iso"
$BaseIso       = Join-Path $IsoDir "17763.737.190906-2324.rs5_release_svc_refresh_SERVERHYPERCORE_OEM_x64FRE_en-us_1.iso"
$VirtioIso     = Join-Path $IsoDir "virtio-win.iso"
$InstallerIso  = Join-Path $IsoDir "windows-core-installer.iso"
$OemdrvIso     = Join-Path $IsoDir "oemdrv.iso"
$UnattendXml   = Join-Path $RepoRoot "autounattend.xml"

function Write-Step { param([string]$Msg) Write-Host "[INFO] $Msg" -ForegroundColor Cyan }
function Write-Success { param([string]$Msg) Write-Host "[SUCCESS] $Msg" -ForegroundColor Green }
function Write-ErrorMsg { param([string]$Msg) Write-Host "[ERROR] $Msg" -ForegroundColor Red }

function Assert-Prerequisites {
    Write-Step "Validating build prerequisites..."
    if (-not (Test-Path $UnattendXml)) { Write-ErrorMsg "Answer file not found: $UnattendXml"; exit 1 }
    if (-not (Test-Path $BaseIso)) { Write-ErrorMsg "Base ISO missing: $BaseIso"; exit 1 }
    if (-not (Test-Path $VirtioIso)) {
        Write-Step "VirtIO ISO missing. Running setup-host.ps1..."
        & (Join-Path $ScriptDir "setup-host.ps1")
    }
}

function Build-InstallerIso {
    $stagingDir = Join-Path ([System.IO.Path]::GetTempPath()) "win_installer_$([System.Guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $stagingDir -Force | Out-Null

    try {
        Write-Step "Extracting base ISO into staging ($stagingDir)..."
        & 7z x -y $BaseIso "-o$stagingDir" | Out-Null

        Write-Step "Injecting autounattend.xml into ISO root..."
        Copy-Item -Path $UnattendXml -Destination (Join-Path $stagingDir "autounattend.xml") -Force

        $bootWim = Join-Path $stagingDir "sources/boot.wim"
        if (Test-Path $bootWim) {
            Write-Step "Slipstreaming autounattend.xml into boot.wim..."
            & wimlib-imagex update $bootWim 1 --command="add $UnattendXml /autounattend.xml" --quiet
            & wimlib-imagex update $bootWim 2 --command="add $UnattendXml /autounattend.xml" --quiet
        }

        Write-Step "Extracting VirtIO drivers into ISO..."
        $virtioDir = Join-Path $stagingDir "virtio"
        New-Item -ItemType Directory -Path $virtioDir -Force | Out-Null
        & 7z x -y $VirtioIso "-o$virtioDir" "viostor/2k19/amd64/*" "vioscsi/2k19/amd64/*" "NetKVM/2k19/amd64/*" "virtio-win-guest-tools.exe" | Out-Null

        Write-Step "Embedding guest provisioning scripts into ISO..."
        $guestScriptsTarget = Join-Path $stagingDir "scripts/guest"
        New-Item -ItemType Directory -Path $guestScriptsTarget -Force | Out-Null
        Copy-Item -Path (Join-Path $RepoRoot "scripts/guest/*") -Destination $guestScriptsTarget -Force

        $opensshZip  = Join-Path $IsoDir "OpenSSH-Win64.zip"
        $winxZip     = Join-Path $IsoDir "winxshell_x64.zip"
        $explorerZip = Join-Path $IsoDir "explorerpp_x64.zip"
        $terminalZip = Join-Path $IsoDir "terminal_x64.zip"
        $vcRedist    = Join-Path $IsoDir "vc_redist.x64.exe"

        if (Test-Path $opensshZip) {
            Write-Step "Embedding offline Win32-OpenSSH package into ISO..."
            $opensshTarget = Join-Path $stagingDir "openssh"
            New-Item -ItemType Directory -Path $opensshTarget -Force | Out-Null
            Copy-Item -Path $opensshZip -Destination $opensshTarget -Force
        }

        $packagesTarget = Join-Path $stagingDir "packages"
        New-Item -ItemType Directory -Path $packagesTarget -Force | Out-Null
        if (Test-Path $winxZip) { Copy-Item -Path $winxZip -Destination $packagesTarget -Force }
        if (Test-Path $explorerZip) { Copy-Item -Path $explorerZip -Destination $packagesTarget -Force }
        if (Test-Path $terminalZip) { Copy-Item -Path $terminalZip -Destination $packagesTarget -Force }
        if (Test-Path $vcRedist) { Copy-Item -Path $vcRedist -Destination $packagesTarget -Force }

        Write-Step "Packaging bootable unattended ISO ($InstallerIso)..."
        if (Test-Path $InstallerIso) { Remove-Item -Path $InstallerIso -Force }

        & xorriso -as mkisofs `
            -iso-level 4 `
            -l -R -J `
            -b boot/etfsboot.com `
            -no-emul-boot `
            -boot-load-size 8 `
            -boot-info-table `
            -eltorito-alt-boot `
            -e efi/microsoft/boot/efisys_noprompt.bin `
            -no-emul-boot `
            -boot-load-size 1 `
            -V "WINDOWS_CORE" `
            -o $InstallerIso `
            $stagingDir 2>$null

        $sizeMb = [math]::Round((Get-Item $InstallerIso).Length / 1MB, 2)
        Write-Success "Unattended installer ISO generated successfully ($InstallerIso, $sizeMb MB)."
    }
    finally {
        if (Test-Path $stagingDir) { Remove-Item -Path $stagingDir -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

function Build-OemdrvIso {
    $oemStaging = Join-Path ([System.IO.Path]::GetTempPath()) "oemdrv_$([System.Guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $oemStaging -Force | Out-Null

    try {
        Write-Step "Building OEMDRV secondary ISO ($OemdrvIso)..."
        Copy-Item -Path $UnattendXml -Destination (Join-Path $oemStaging "autounattend.xml") -Force
        & 7z x -y $VirtioIso "-o$oemStaging" "viostor/2k19/amd64/*" "vioscsi/2k19/amd64/*" "NetKVM/2k19/amd64/*" "virtio-win-guest-tools.exe" | Out-Null

        $oemScriptsTarget = Join-Path $oemStaging "scripts/guest"
        New-Item -ItemType Directory -Path $oemScriptsTarget -Force | Out-Null
        Copy-Item -Path (Join-Path $RepoRoot "scripts/guest/*") -Destination $oemScriptsTarget -Force

        $opensshZip  = Join-Path $IsoDir "OpenSSH-Win64.zip"
        $winxZip     = Join-Path $IsoDir "winxshell_x64.zip"
        $explorerZip = Join-Path $IsoDir "explorerpp_x64.zip"
        $terminalZip = Join-Path $IsoDir "terminal_x64.zip"
        $vcRedist    = Join-Path $IsoDir "vc_redist.x64.exe"

        if (Test-Path $opensshZip) {
            $oemOpensshTarget = Join-Path $oemStaging "openssh"
            New-Item -ItemType Directory -Path $oemOpensshTarget -Force | Out-Null
            Copy-Item -Path $opensshZip -Destination $oemOpensshTarget -Force
        }

        $oemPackagesTarget = Join-Path $oemStaging "packages"
        New-Item -ItemType Directory -Path $oemPackagesTarget -Force | Out-Null
        if (Test-Path $winxZip) { Copy-Item -Path $winxZip -Destination $oemPackagesTarget -Force }
        if (Test-Path $explorerZip) { Copy-Item -Path $explorerZip -Destination $oemPackagesTarget -Force }
        if (Test-Path $terminalZip) { Copy-Item -Path $terminalZip -Destination $oemPackagesTarget -Force }
        if (Test-Path $vcRedist) { Copy-Item -Path $vcRedist -Destination $oemPackagesTarget -Force }

        if (Test-Path $OemdrvIso) { Remove-Item -Path $OemdrvIso -Force }
        & xorriso -as mkisofs -quiet -o $OemdrvIso -V "OEMDRV" -J -r -iso-level 3 $oemStaging
        Write-Success "OEMDRV secondary ISO generated successfully."
    }
    finally {
        if (Test-Path $oemStaging) { Remove-Item -Path $oemStaging -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

function Main {
    Write-Host "=============================================================================="
    Write-Host "  Windows Core Headless Host - Build Unattended Installer ISO (PowerShell 7)"
    Write-Host "=============================================================================="
    Assert-Prerequisites
    Build-InstallerIso
    Build-OemdrvIso
}

Main
