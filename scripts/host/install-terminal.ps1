<#
.SYNOPSIS
    Host Script (PowerShell 7): Non-destructive Live Setup of Windows Terminal on Windows CoreOS (WCOS) Guest.
.DESCRIPTION
    Transfers Windows Terminal and Visual C++ packages and invokes Install-WindowsTerminal.ps1 over SSH.
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
function Write-ErrMsg { param([string]$Msg) Write-Host "[ERROR] $Msg" -ForegroundColor Red }

function Main {
    Write-Host "=============================================================================="
    Write-Host "  Windows Core - Windows Terminal Deployment (PowerShell)"
    Write-Host "=============================================================================="

    $terminalZip = Join-Path $IsoDir "terminal_x64.zip"
    $vcRedist    = Join-Path $IsoDir "vc_redist.x64.exe"

    if (-not (Test-Path $terminalZip)) {
        Write-Step "Downloading WezTerm portable zip..."
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri "https://github.com/wezterm/wezterm/releases/download/20240203-110809-5046fc22/WezTerm-windows-20240203-110809-5046fc22.zip" -OutFile $terminalZip -UseBasicParsing
    }
    if (-not (Test-Path $vcRedist)) {
        Write-Step "Downloading Visual C++ Redistributable..."
        Invoke-WebRequest -Uri "https://aka.ms/vs/17/release/vc_redist.x64.exe" -OutFile $vcRedist -UseBasicParsing
    }

    Write-Step "Creating remote directories..."
    & ssh -p $VmPort -o StrictHostKeyChecking=accept-new "$VmUser@$VmHost" "powershell -Command `"New-Item -ItemType Directory -Path 'C:\Provisioning\packages', 'C:\Provisioning\scripts' -Force | Out-Null`""

    Write-Step "Transferring packages..."
    & scp -P $VmPort -o StrictHostKeyChecking=accept-new $terminalZip "${VmUser}@${VmHost}:C:/Provisioning/packages/terminal_x64.zip"
    & scp -P $VmPort -o StrictHostKeyChecking=accept-new $vcRedist "${VmUser}@${VmHost}:C:/Provisioning/packages/vc_redist.x64.exe"
    & scp -P $VmPort -o StrictHostKeyChecking=accept-new (Join-Path $RepoRoot "scripts/guest/Install-WindowsTerminal.ps1") "${VmUser}@${VmHost}:C:/Provisioning/scripts/Install-WindowsTerminal.ps1"

    Write-Step "Executing Install-WindowsTerminal.ps1..."
    & ssh -p $VmPort -o StrictHostKeyChecking=accept-new "$VmUser@$VmHost" "powershell -ExecutionPolicy Bypass -File 'C:\Provisioning\scripts\Install-WindowsTerminal.ps1'"

    Write-Success "Windows Terminal setup completed."
}

Main
