<#
.SYNOPSIS
    Host Script (PowerShell 7): Setup of ReactShell Desktop Environment on Windows Core Guest.
.DESCRIPTION
    Transfers ReactShell, WinXShell, and Explorer++ packages and invokes Install-DesktopShell.ps1 over SSH.
#>
[CmdletBinding()]
param(
    [string]$VmHost = "127.0.0.1",
    [int]$VmPort = 2222,
    [string]$VmUser = "samuelcaldas",
    [ValidateSet('ReactShell', 'WinXShell', 'None')][string]$ShellProvider = 'ReactShell',
    [ValidateSet('ReactFM', 'ExplorerPlusPlus', 'None')][string]$FileManager = 'ReactFM'
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
    Write-Host "  Windows Core - Desktop Shell ($ShellProvider / $FileManager) Deployment (PowerShell)"
    Write-Host "=============================================================================="

    $rshellZip    = Join-Path $IsoDir "reactshell_x64.zip"
    $winxshellZip = Join-Path $IsoDir "winxshell_x64.zip"
    $explorerZip  = Join-Path $IsoDir "explorerpp_x64.zip"

    Write-Step "Creating remote provisioning directories..."
    & ssh -p $VmPort -o StrictHostKeyChecking=accept-new "$VmUser@$VmHost" "powershell -Command `"New-Item -ItemType Directory -Path 'C:\Provisioning\packages', 'C:\Provisioning\scripts' -Force | Out-Null`""

    Write-Step "Transferring packages to guest..."
    if (Test-Path $rshellZip) {
        & scp -P $VmPort -o StrictHostKeyChecking=accept-new $rshellZip "${VmUser}@${VmHost}:C:/Provisioning/packages/reactshell_x64.zip"
    }
    if (Test-Path $winxshellZip) {
        & scp -P $VmPort -o StrictHostKeyChecking=accept-new $winxshellZip "${VmUser}@${VmHost}:C:/Provisioning/packages/winxshell_x64.zip"
    }
    if (Test-Path $explorerZip) {
        & scp -P $VmPort -o StrictHostKeyChecking=accept-new $explorerZip "${VmUser}@${VmHost}:C:/Provisioning/packages/explorerpp_x64.zip"
    }
    $configXml = Join-Path $RepoRoot "config/explorerpp/config.xml"
    if (Test-Path $configXml) {
        & scp -P $VmPort -o StrictHostKeyChecking=accept-new $configXml "${VmUser}@${VmHost}:C:/Provisioning/packages/config.xml"
    }
    $wxsLua = Join-Path $RepoRoot "config/winxshell/WinXShell.lua"
    if (Test-Path $wxsLua) {
        & scp -P $VmPort -o StrictHostKeyChecking=accept-new $wxsLua "${VmUser}@${VmHost}:C:/Provisioning/packages/WinXShell.lua"
    }
    $wxsReg = Join-Path $RepoRoot "config/winxshell/shell-settings.reg"
    if (Test-Path $wxsReg) {
        & scp -P $VmPort -o StrictHostKeyChecking=accept-new $wxsReg "${VmUser}@${VmHost}:C:/Provisioning/packages/shell-settings.reg"
    }
    & scp -P $VmPort -o StrictHostKeyChecking=accept-new (Join-Path $RepoRoot "scripts/guest/Install-DesktopShell.ps1") "${VmUser}@${VmHost}:C:/Provisioning/scripts/Install-DesktopShell.ps1"

    Write-Step "Executing Install-DesktopShell.ps1 on guest..."
    & ssh -p $VmPort -o StrictHostKeyChecking=accept-new "$VmUser@$VmHost" "powershell -ExecutionPolicy Bypass -File 'C:\Provisioning\scripts\Install-DesktopShell.ps1' -ShellProvider '$ShellProvider' -FileManager '$FileManager'"

    Write-Success "Desktop shell setup ($ShellProvider / $FileManager) completed successfully."
}

Main
