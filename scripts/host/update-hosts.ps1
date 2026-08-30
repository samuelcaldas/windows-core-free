<#
.SYNOPSIS
    Windows Core - Dan Pollock Zero-Route Hosts Blocklist Deployment (PowerShell 7)
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
$ConfigDir = Join-Path $RepoRoot "config/hosts"

function Write-Step { param([string]$Msg) Write-Host "[INFO] $Msg" -ForegroundColor Cyan }
function Write-Success { param([string]$Msg) Write-Host "[SUCCESS] $Msg" -ForegroundColor Green }
function Write-ErrMsg { param([string]$Msg) Write-Host "[ERROR] $Msg" -ForegroundColor Red }

function Main {
    Write-Host "=============================================================================="
    Write-Host "  Windows Core - Dan Pollock Hosts Blocklist Deployment (PowerShell)"
    Write-Host "=============================================================================="

    if (-not (Test-Path $ConfigDir)) {
        New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
    }

    $hostsFile = Join-Path $ConfigDir "hosts"
    if (-not (Test-Path $hostsFile)) {
        Write-Step "Fetching latest Dan Pollock hosts file..."
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri "https://someonewhocares.org/hosts/zero/hosts" -OutFile $hostsFile -UseBasicParsing
    }

    Write-Step "Creating remote directories..."
    & ssh -p $VmPort -o StrictHostKeyChecking=accept-new "$VmUser@$VmHost" "powershell -Command `"New-Item -ItemType Directory -Path 'C:\Provisioning\config\hosts', 'C:\Provisioning\scripts' -Force | Out-Null`""

    Write-Step "Transferring hosts file and Update-HostsBlocklist.ps1..."
    & scp -P $VmPort -o StrictHostKeyChecking=accept-new $hostsFile "${VmUser}@${VmHost}:C:/Provisioning/config/hosts/hosts"
    & scp -P $VmPort -o StrictHostKeyChecking=accept-new (Join-Path $RepoRoot "scripts/guest/Update-HostsBlocklist.ps1") "${VmUser}@${VmHost}:C:/Provisioning/scripts/Update-HostsBlocklist.ps1"

    Write-Step "Executing Update-HostsBlocklist.ps1 on Windows Core..."
    & ssh -p $VmPort -o StrictHostKeyChecking=accept-new "$VmUser@$VmHost" "powershell -ExecutionPolicy Bypass -File 'C:\Provisioning\scripts\Update-HostsBlocklist.ps1'"

    Write-Step "Verifying DNS resolution..."
    & ssh -p $VmPort -o StrictHostKeyChecking=accept-new "$VmUser@$VmHost" "powershell -Command `"(Get-Content 'C:\Windows\System32\drivers\etc\hosts').Count`""

    Write-Success "Dan Pollock hosts blocklist deployed successfully."
}

Main
