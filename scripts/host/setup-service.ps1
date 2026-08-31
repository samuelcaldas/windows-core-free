#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Systemd Autostart Service Orchestrator for Windows Core VM (PowerShell 7 - Ubuntu Host)
.DESCRIPTION
    Installs, configures, enables, and manages the systemd service for Windows Server Core VM.
    Enables automatic VM initialization and boot on Ubuntu host startup.
.PARAMETER Install
    Installs, enables for autostart, and starts the systemd service.
.PARAMETER InstallOnly
    Installs and enables the service without starting it immediately.
.PARAMETER Enable
    Enables autostart on Ubuntu system boot.
.PARAMETER Disable
    Disables autostart on Ubuntu boot.
.PARAMETER Start
    Starts the Windows Core VM service.
.PARAMETER Stop
    Stops the Windows Core VM service gracefully.
.PARAMETER Restart
    Restarts the Windows Core VM service.
.PARAMETER Status
    Checks service status and autostart configuration.
.PARAMETER Logs
    Displays systemd journal logs.
.PARAMETER Uninstall
    Stops, disables, and removes the systemd service.
#>
[CmdletBinding(DefaultParameterSetName = 'Install')]
param(
    [Parameter(ParameterSetName = 'Install')]
    [switch]$Install,

    [Parameter(ParameterSetName = 'InstallOnly')]
    [switch]$InstallOnly,

    [Parameter(ParameterSetName = 'Enable')]
    [switch]$Enable,

    [Parameter(ParameterSetName = 'Disable')]
    [switch]$Disable,

    [Parameter(ParameterSetName = 'Start')]
    [switch]$Start,

    [Parameter(ParameterSetName = 'Stop')]
    [switch]$Stop,

    [Parameter(ParameterSetName = 'Restart')]
    [switch]$Restart,

    [Parameter(ParameterSetName = 'Status')]
    [switch]$Status,

    [Parameter(ParameterSetName = 'Logs')]
    [switch]$Logs,

    [Parameter(ParameterSetName = 'Uninstall')]
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$ScriptDir     = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot      = (Resolve-Path "$ScriptDir/../..").Path
$ServiceName   = "windows-core.service"
$ServiceDest   = "/etc/systemd/system/$ServiceName"
$TemplatePath  = Join-Path $RepoRoot "config/systemd/windows-core.service"

$CurrentUser   = [System.Environment]::UserName
$CurrentGroup  = (id -gn).Trim()

function Write-Step { param([string]$Msg) Write-Host "[INFO] $Msg" -ForegroundColor Cyan }
function Write-Success { param([string]$Msg) Write-Host "[SUCCESS] $Msg" -ForegroundColor Green }
function Write-WarnMsg { param([string]$Msg) Write-Host "[WARN] $Msg" -ForegroundColor Yellow }
function Write-ErrorMsg { param([string]$Msg) Write-Host "[ERROR] $Msg" -ForegroundColor Red }

function Invoke-AsRoot {
    param([string]$Command)
    $currentUid = (id -u).Trim()
    if ($currentUid -eq '0') {
        & bash -c "$Command"
    }
    else {
        & ssh root@localhost "$Command"
    }
}

function Get-ServiceDefinition {
    return @"
[Unit]
Description=Windows Server Core Headless Development VM (QEMU/KVM)
Documentation=https://github.com/samuelcaldas/windows-core
After=network.target network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$CurrentUser
Group=$CurrentGroup
SupplementaryGroups=kvm
WorkingDirectory=$RepoRoot
ExecStart=$RepoRoot/scripts/host/run-vm.sh --foreground
ExecStop=$RepoRoot/scripts/host/run-vm.sh --stop
Restart=on-failure
RestartSec=10s
TimeoutStopSec=60s
KillMode=control-group
PIDFile=$RepoRoot/.windows-core-qemu.pid

[Install]
WantedBy=multi-user.target
"@
}

function Install-Service {
    param([bool]$AutoStart = $true)

    Write-Step "Configuring systemd autostart service for Windows Core..."
    Write-Step "Repository root: $RepoRoot"
    Write-Step "Service user:    ${CurrentUser}:${CurrentGroup} (Supplementary: kvm)"

    $unitContent = Get-ServiceDefinition
    $tempFile = [System.IO.Path]::GetTempFileName()
    Set-Content -Path $tempFile -Value $unitContent -Encoding utf8NoBOM

    $systemdDir = Join-Path $RepoRoot "config/systemd"
    if (-not (Test-Path $systemdDir)) {
        New-Item -ItemType Directory -Path $systemdDir -Force | Out-Null
    }
    Copy-Item -Path $tempFile -Destination $TemplatePath -Force

    Write-Step "Installing unit file to $ServiceDest via root SSH..."
    $currentUid = (id -u).Trim()
    if ($currentUid -eq '0') {
        Copy-Item -Path $tempFile -Destination $ServiceDest -Force
        & chmod 644 $ServiceDest
    }
    else {
        & scp -q $tempFile "root@localhost:$ServiceDest"
        Invoke-AsRoot "chmod 644 $ServiceDest"
    }
    Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue

    Write-Step "Reloading systemd daemon..."
    Invoke-AsRoot "systemctl daemon-reload"

    Write-Step "Enabling $ServiceName for automatic boot on Ubuntu startup..."
    Invoke-AsRoot "systemctl enable $ServiceName"
    Write-Success "Service $ServiceName enabled for automatic startup on Ubuntu boot."

    if ($AutoStart) {
        Write-Step "Starting $ServiceName now..."
        Invoke-AsRoot "systemctl start $ServiceName"
        Start-Sleep -Seconds 2
        Show-ServiceStatus
    }
}

function Show-ServiceStatus {
    $isActive = $false
    try {
        & bash -c "systemctl is-active --quiet $ServiceName"
        if ($LASTEXITCODE -eq 0) { $isActive = $true }
    } catch { }

    if ($isActive) {
        Write-Success "$ServiceName is ACTIVE and RUNNING."
    }
    else {
        Write-WarnMsg "$ServiceName is INACTIVE or STOPPED."
    }

    $isEnabled = $false
    try {
        & bash -c "systemctl is-enabled --quiet $ServiceName"
        if ($LASTEXITCODE -eq 0) { $isEnabled = $true }
    } catch { }

    if ($isEnabled) {
        Write-Host "  - Autostart on boot: " -NoNewline
        Write-Host "ENABLED" -ForegroundColor Green
    }
    else {
        Write-Host "  - Autostart on boot: " -NoNewline
        Write-Host "DISABLED" -ForegroundColor Yellow
    }

    Write-Host ""
    & systemctl status $ServiceName --no-pager --lines=10
}

function Remove-Service {
    Write-Step "Uninstalling $ServiceName..."
    Invoke-AsRoot "systemctl stop $ServiceName 2>/dev/null || true"
    Invoke-AsRoot "systemctl disable $ServiceName 2>/dev/null || true"
    Invoke-AsRoot "rm -f $ServiceDest"
    Invoke-AsRoot "systemctl daemon-reload"
    Write-Success "Service $ServiceName uninstalled completely."
}

if ($Uninstall)   { Remove-Service; exit 0 }
if ($Status)      { Show-ServiceStatus; exit 0 }
if ($Logs)        { & journalctl -u $ServiceName -n 50 -f; exit 0 }
if ($Enable)      { Invoke-AsRoot "systemctl enable $ServiceName"; Write-Success "$ServiceName enabled for autostart."; exit 0 }
if ($Disable)     { Invoke-AsRoot "systemctl disable $ServiceName"; Write-Success "$ServiceName autostart disabled."; exit 0 }
if ($Start)       { Invoke-AsRoot "systemctl start $ServiceName"; Start-Sleep -Seconds 2; Show-ServiceStatus; exit 0 }
if ($Stop)        { Invoke-AsRoot "systemctl stop $ServiceName"; Write-Success "$ServiceName stopped."; exit 0 }
if ($Restart)     { Invoke-AsRoot "systemctl restart $ServiceName"; Start-Sleep -Seconds 2; Show-ServiceStatus; exit 0 }
if ($InstallOnly) { Install-Service -AutoStart $false; exit 0 }

Install-Service -AutoStart $true
