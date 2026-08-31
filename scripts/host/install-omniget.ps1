<#
.SYNOPSIS
    Host Script (PowerShell 7): Deploy & Run OmniGet (og) Universal Package Manager on Windows Core Guest.
.DESCRIPTION
    Transfers external/omniget submodule and Install-OmniGet.ps1 to guest and orchestrates execution over SSH.
#>
[CmdletBinding()]
param(
    [string]$VmHost = "127.0.0.1",
    [int]$VmPort = 2222,
    [string]$VmUser = "samuelcaldas",
    [switch]$Interactive,
    [string]$Preset = "",
    [string[]]$Apps = @()
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot  = (Resolve-Path (Join-Path $ScriptDir "../..")).Path
$GuestScript = Join-Path $RepoRoot "scripts/guest/Install-OmniGet.ps1"
$OmniSubmodule = Join-Path $RepoRoot "external/omniget"

function Write-Step { param([string]$Msg) Write-Host "[INFO] $Msg" -ForegroundColor Cyan }
function Write-Success { param([string]$Msg) Write-Host "[SUCCESS] $Msg" -ForegroundColor Green }

function Main {
    Write-Host "=============================================================================="
    Write-Host "  Windows Core - OmniGet (og) Orchestrator (PowerShell 7)"
    Write-Host "=============================================================================="

    Write-Step "Creating remote directories..."
    & ssh -p $VmPort -o StrictHostKeyChecking=accept-new "$VmUser@$VmHost" "powershell -Command `"New-Item -ItemType Directory -Path 'C:\Program Files\OmniGet', 'C:\Provisioning\scripts', 'C:\Provisioning\packages' -Force | Out-Null`""

    Write-Step "Transferring Install-OmniGet.ps1..."
    & scp -P $VmPort -o StrictHostKeyChecking=accept-new $GuestScript "${VmUser}@${VmHost}:C:/Provisioning/scripts/Install-OmniGet.ps1"

    if (Test-Path $OmniSubmodule) {
        Write-Step "Packaging and transferring external/omniget submodule..."
        $tempZip = Join-Path ([System.IO.Path]::GetTempPath()) "omniget_submodule.zip"
        Compress-Archive -Path "$OmniSubmodule\*" -DestinationPath $tempZip -Force
        & scp -P $VmPort -o StrictHostKeyChecking=accept-new $tempZip "${VmUser}@${VmHost}:C:/Provisioning/packages/omniget.zip"
        Remove-Item -Path $tempZip -Force -ErrorAction SilentlyContinue
    }

    Write-Step "Deploying OmniGet environment & desktop shortcuts..."
    & ssh -p $VmPort -o StrictHostKeyChecking=accept-new "$VmUser@$VmHost" "pwsh -ExecutionPolicy Bypass -File 'C:\Provisioning\scripts\Install-OmniGet.ps1' -DeployOnly"

    if ($Interactive -or ($Apps.Count -eq 0 -and [string]::IsNullOrWhiteSpace($Preset))) {
        Write-Step "Starting interactive OmniGet TUI session over SSH..."
        & ssh -t -p $VmPort -o StrictHostKeyChecking=accept-new "$VmUser@$VmHost" "pwsh -ExecutionPolicy Bypass -File 'C:\Program Files\OmniGet\src\OmniGet.ps1'"
    }
    elseif (-not [string]::IsNullOrWhiteSpace($Preset)) {
        Write-Step "Executing preset: $Preset..."
        & ssh -p $VmPort -o StrictHostKeyChecking=accept-new "$VmUser@$VmHost" "pwsh -ExecutionPolicy Bypass -File 'C:\Program Files\OmniGet\src\OmniGet.ps1' -Preset '$Preset' -Silent"
    }
    elseif ($Apps.Count -gt 0) {
        $appList = ($Apps | ForEach-Object { "'$_'" }) -join ','
        Write-Step "Installing packages: $appList..."
        & ssh -p $VmPort -o StrictHostKeyChecking=accept-new "$VmUser@$VmHost" "pwsh -ExecutionPolicy Bypass -File 'C:\Program Files\OmniGet\src\OmniGet.ps1' -Install @($appList) -Silent"
    }

    Write-Success "OmniGet deployment completed."
}

Main
