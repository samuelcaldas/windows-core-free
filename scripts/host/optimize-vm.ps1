<#
.SYNOPSIS
    Windows CoreOS (WCOS) - System & Memory Optimization Orchestrator (PowerShell 7)
#>

[CmdletBinding()]
param(
    [string]$VmHost = "127.0.0.1",
    [int]$VmPort = 2222,
    [string]$VmUser = "samuelcaldas",
    [string]$VmPass = "windows"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot  = (Resolve-Path (Join-Path $ScriptDir "../..")).Path

function Write-Step { param([string]$Msg) Write-Host "[INFO] $Msg" -ForegroundColor Cyan }
function Write-Success { param([string]$Msg) Write-Host "[SUCCESS] $Msg" -ForegroundColor Green }
function Write-ErrMsg { param([string]$Msg) Write-Host "[ERROR] $Msg" -ForegroundColor Red }

function Main {
    Write-Host "=============================================================================="
    Write-Host "  Windows CoreOS (WCOS) - Live Memory Optimization & Feature Pruning (PowerShell)"
    Write-Host "=============================================================================="

    Write-Step "Creating remote directories..."
    & ssh -p $VmPort -o StrictHostKeyChecking=accept-new "$VmUser@$VmHost" "powershell -Command `"New-Item -ItemType Directory -Path 'C:\Provisioning\scripts' -Force | Out-Null`""

    Write-Step "Transferring Optimize-System.ps1..."
    & scp -P $VmPort -o StrictHostKeyChecking=accept-new (Join-Path $RepoRoot "scripts/guest/Optimize-System.ps1") "${VmUser}@${VmHost}:C:/Provisioning/scripts/Optimize-System.ps1"

    Write-Step "Executing Optimize-System.ps1..."
    & ssh -p $VmPort -o StrictHostKeyChecking=accept-new "$VmUser@$VmHost" "powershell -ExecutionPolicy Bypass -File 'C:\Provisioning\scripts\Optimize-System.ps1'"

    Write-Step "Checking Top RAM Consuming Processes..."
    & ssh -p $VmPort -o StrictHostKeyChecking=accept-new "$VmUser@$VmHost" "powershell -Command `"Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 10 Name, Id, @{Name='RAM (MB)'; Expression={[math]::Round(`$_.WorkingSet64 / 1MB, 2)}} | Format-Table -AutoSize`""

    Write-Success "Windows CoreOS (WCOS) memory optimization completed successfully."
}

Main
