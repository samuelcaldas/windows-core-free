<#
.SYNOPSIS
    Host Script (PowerShell 7): Non-destructive Live Setup of WinXShell & Explorer++ on Windows Core Guest.
.DESCRIPTION
    Transfers WinXShell and Explorer++ packages and invokes Install-DesktopShell.ps1 over SSH.
#>
[CmdletBinding()]
param(
    [string]$VmHost = "127.0.0.1",
    [int]$VmPort = 2222,
    [string]$VmUser = "samuelcaldas"
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot  = (Resolve-Path (Join-Path $ScriptDir "../..")).Path
$IsoDir    = Join-Path $RepoRoot "iso"

function Write-Step { param([string]$Msg) Write-Host "[INFO] $Msg" -ForegroundColor Cyan }
function Write-Success { param([string]$Msg) Write-Host "[SUCCESS] $Msg" -ForegroundColor Green }
function Write-WarnMsg { param([string]$Msg) Write-Host "[WARN] $Msg" -ForegroundColor Yellow }
function Write-ErrMsg { param([string]$Msg) Write-Host "[ERROR] $Msg" -ForegroundColor Red }

function Main {
    Write-Host "=============================================================================="
    Write-Host "  Windows Core - WinXShell & Explorer++ Desktop Shell Deployment (PowerShell)"
    Write-Host "=============================================================================="

    $winxshellZip = Join-Path $IsoDir "winxshell_x64.zip"
    $explorerZip  = Join-Path $IsoDir "explorerpp_x64.zip"

    if (-not (Test-Path $winxshellZip) -or -not (Test-Path $explorerZip)) {
        Write-ErrMsg "Required packages missing in $IsoDir."
        exit 1
    }

    Write-Step "Creating remote directories..."
    & ssh -p $VmPort -o StrictHostKeyChecking=accept-new "$VmUser@$VmHost" "powershell -Command `"New-Item -ItemType Directory -Path 'C:\Provisioning\packages', 'C:\Provisioning\scripts' -Force | Out-Null`""

    Write-Step "Transferring packages..."
    & scp -P $VmPort -o StrictHostKeyChecking=accept-new $winxshellZip "${VmUser}@${VmHost}:C:/Provisioning/packages/winxshell_x64.zip"
    & scp -P $VmPort -o StrictHostKeyChecking=accept-new $explorerZip "${VmUser}@${VmHost}:C:/Provisioning/packages/explorerpp_x64.zip"
    $configXml = Join-Path $RepoRoot "config/explorerpp/config.xml"
    if (Test-Path $configXml) {
        & scp -P $VmPort -o StrictHostKeyChecking=accept-new $configXml "${VmUser}@${VmHost}:C:/Provisioning/packages/config.xml"
    }
    & scp -P $VmPort -o StrictHostKeyChecking=accept-new (Join-Path $RepoRoot "scripts/guest/Install-DesktopShell.ps1") "${VmUser}@${VmHost}:C:/Provisioning/scripts/Install-DesktopShell.ps1"

    Write-Step "Executing Install-DesktopShell.ps1..."
    & ssh -p $VmPort -o StrictHostKeyChecking=accept-new "$VmUser@$VmHost" "powershell -ExecutionPolicy Bypass -File 'C:\Provisioning\scripts\Install-DesktopShell.ps1'"

    Write-Success "Desktop shell setup completed."
}

Main
