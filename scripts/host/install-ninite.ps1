<#
.SYNOPSIS
    Host Script (PowerShell 7): Deploy & Run Interactive Ninite Package Manager on Windows Core Guest.
.DESCRIPTION
    Transfers Install-NiniteApps.ps1 and triggers interactive or scripted execution over SSH.
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
$GuestScript = Join-Path $RepoRoot "scripts/guest/Install-NiniteApps.ps1"

function Write-Step { param([string]$Msg) Write-Host "[INFO] $Msg" -ForegroundColor Cyan }
function Write-Success { param([string]$Msg) Write-Host "[SUCCESS] $Msg" -ForegroundColor Green }

function Main {
    Write-Host "=============================================================================="
    Write-Host "  Windows Core - Ninite Package Manager Orchestrator (PowerShell)"
    Write-Host "=============================================================================="

    Write-Step "Creating remote Ninite directory..."
    & ssh -p $VmPort -o StrictHostKeyChecking=accept-new "$VmUser@$VmHost" "powershell -Command `"New-Item -ItemType Directory -Path 'C:\Program Files\Ninite', 'C:\Provisioning\scripts' -Force | Out-Null`""

    Write-Step "Transferring Install-NiniteApps.ps1..."
    & scp -P $VmPort -o StrictHostKeyChecking=accept-new $GuestScript "${VmUser}@${VmHost}:C:/Program Files/Ninite/Install-NiniteApps.ps1"
    & scp -P $VmPort -o StrictHostKeyChecking=accept-new $GuestScript "${VmUser}@${VmHost}:C:/Provisioning/scripts/Install-NiniteApps.ps1"

    Write-Step "Deploying desktop shortcuts..."
    & ssh -p $VmPort -o StrictHostKeyChecking=accept-new "$VmUser@$VmHost" "pwsh -ExecutionPolicy Bypass -File 'C:\Program Files\Ninite\Install-NiniteApps.ps1' -DeployOnly"

    if ($Interactive) {
        Write-Step "Starting interactive TUI session over SSH..."
        & ssh -t -p $VmPort -o StrictHostKeyChecking=accept-new "$VmUser@$VmHost" "pwsh -ExecutionPolicy Bypass -File 'C:\Program Files\Ninite\Install-NiniteApps.ps1'"
    }
    elseif (-not [string]::IsNullOrWhiteSpace($Preset)) {
        Write-Step "Executing preset: $Preset..."
        & ssh -p $VmPort -o StrictHostKeyChecking=accept-new "$VmUser@$VmHost" "pwsh -ExecutionPolicy Bypass -File 'C:\Program Files\Ninite\Install-NiniteApps.ps1' -Preset '$Preset' -Silent"
    }
    elseif ($Apps.Count -gt 0) {
        $appList = ($Apps | ForEach-Object { "'$_'" }) -join ','
        Write-Step "Installing applications: $appList..."
        & ssh -p $VmPort -o StrictHostKeyChecking=accept-new "$VmUser@$VmHost" "pwsh -ExecutionPolicy Bypass -File 'C:\Program Files\Ninite\Install-NiniteApps.ps1' -Apps @($appList) -Silent"
    }

    Write-Success "Ninite deployment completed."
}

Main
