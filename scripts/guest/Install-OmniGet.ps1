<#
.SYNOPSIS
    Guest Script: Deploys OmniGet (og) - Universal Multi-Source Package Engine on Windows CoreOS (WCOS).
.DESCRIPTION
    Installs OmniGet to C:\Program Files\OmniGet, adds to system Machine PATH,
    and deploys the desktop shortcut to Public Desktop.
#>
[CmdletBinding()]
param(
    [string]$SourceDir = "C:\Provisioning\packages",
    [switch]$DeployOnly,
    [switch]$Interactive,
    [string]$Preset = "",
    [string[]]$Apps = @()
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Write-Step { param([string]$Msg) Write-Host "[INFO] $Msg" -ForegroundColor Cyan }
function Write-Success { param([string]$Msg) Write-Host "[SUCCESS] $Msg" -ForegroundColor Green }
function Write-WarnMsg { param([string]$Msg) Write-Host "[WARN] $Msg" -ForegroundColor Yellow }

$TargetDir = "C:\Program Files\OmniGet"

function Deploy-OmniGetPackage {
    Write-Step "Installing OmniGet to $TargetDir..."
    if (-not (Test-Path $TargetDir)) {
        New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
    }

    # Search for offline omniget package on CD/USB drives or staging
    $zipFile = Join-Path $SourceDir "omniget.zip"
    if (-not (Test-Path $zipFile)) {
        foreach ($letter in 'DEFGHIJKLMNOPQRSTUVWXYZ'.ToCharArray()) {
            $cand = "${letter}:\omniget.zip"
            if (Test-Path $cand) { $zipFile = $cand; break }
            $cand = "${letter}:\packages\omniget.zip"
            if (Test-Path $cand) { $zipFile = $cand; break }
        }
    }

    if (Test-Path $zipFile) {
        Write-Step "Extracting offline OmniGet package from $zipFile..."
        Expand-Archive -Path $zipFile -DestinationPath $TargetDir -Force
    }
    elseif (-not (Test-Path "$TargetDir\src\OmniGet.ps1")) {
        Write-Step "Downloading latest OmniGet release from GitHub..."
        $zipUrl = "https://github.com/samuelcaldas/omniget/archive/refs/heads/main.zip"
        $tempZip = "$env:TEMP\omniget_main.zip"
        $extractDir = "$env:TEMP\omniget_extract"
        try {
            $curl = "$env:WINDIR\System32\curl.exe"
            if (Test-Path $curl) {
                & $curl -fSL "$zipUrl" -o "$tempZip"
            } else {
                (New-Object System.Net.WebClient).DownloadFile($zipUrl, $tempZip)
            }
            if (Test-Path $extractDir) { Remove-Item -Path $extractDir -Recurse -Force }
            Expand-Archive -Path $tempZip -DestinationPath $extractDir -Force
            $srcDir = Join-Path $extractDir "omniget-main"
            if (-not (Test-Path $srcDir)) { $srcDir = $extractDir }
            Copy-Item -Path "$srcDir\*" -Destination $TargetDir -Recurse -Force
        }
        catch {
            Write-WarnMsg "Online download failed: $_"
        }
        finally {
            Remove-Item -Path $tempZip, $extractDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    if (Test-Path "$TargetDir\src\OmniGet.ps1") {
        & "$TargetDir\src\OmniGet.ps1" -Deploy
        Write-Success "OmniGet deployed and registered in system PATH."
    }
}

function Main {
    Deploy-OmniGetPackage

    if ($DeployOnly) { return }

    $omniExe = "$TargetDir\src\OmniGet.ps1"
    if (-not (Test-Path $omniExe)) {
        Write-WarnMsg "OmniGet launcher not found at $omniExe"
        return
    }

    if ($Apps.Count -gt 0) {
        & $omniExe -Install $Apps -Silent
    }
    elseif (-not [string]::IsNullOrWhiteSpace($Preset)) {
        & $omniExe -Preset $Preset -Silent
    }
    elseif ($Interactive) {
        & $omniExe
    }
}

Main
