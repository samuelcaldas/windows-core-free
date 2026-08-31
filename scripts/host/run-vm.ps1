#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Phase 2: QEMU / KVM Virtual Machine Orchestrator (PowerShell 7 - UEFI + VirtIO)
.DESCRIPTION
    Launches Windows Server Core in QEMU/KVM with OVMF UEFI firmware, VirtIO storage, network, and port forwards.
    Supports unattended installation mode (--Install) and regular runtime (--Run).
.PARAMETER Install
    Boots with unattended installer ISO for zero-touch installation.
.PARAMETER Run
    Boots installed QCOW2 virtual disk.
.PARAMETER Foreground
    Runs VM in foreground mode (for systemd services and direct monitoring).
.PARAMETER Daemon
    Starts VM in background.
.PARAMETER Status
    Shows running status and port forwarding.
.PARAMETER Stop
    Stops running VM process gracefully via ACPI powerdown.
#>
[CmdletBinding(DefaultParameterSetName = 'Run')]
param(
    [Parameter(ParameterSetName = 'Install')]
    [switch]$Install,

    [Parameter(ParameterSetName = 'Run')]
    [switch]$Run,

    [Parameter(ParameterSetName = 'Status')]
    [switch]$Status,

    [Parameter(ParameterSetName = 'Stop')]
    [switch]$Stop,

    [switch]$Foreground,
    [switch]$Daemon,
    [int]$Ram = 4096,
    [int]$Cpus = 4,
    [int]$SshPort = 2222,
    [int]$WinrmHttpPort = 5985,
    [int]$WinrmHttpsPort = 5986,
    [int]$DaemonPort = 9090,
    [string]$VncDisplay = ":1"
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$ScriptDir     = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot      = (Resolve-Path "$ScriptDir/../..").Path
$IsoDir        = Join-Path $RepoRoot "iso"
$VmDisk        = Join-Path $RepoRoot "windows-core.qcow2"
$PidFile       = Join-Path $RepoRoot ".windows-core-qemu.pid"
$MonitorSock   = Join-Path $RepoRoot ".windows-core-monitor.sock"
$InstallerIso  = Join-Path $IsoDir "windows-core-installer.iso"
$VirtioIso     = Join-Path $IsoDir "virtio-win.iso"
$OvmfCode      = "/usr/share/OVMF/OVMF_CODE_4M.ms.fd"
$OvmfVarsSrc   = "/usr/share/OVMF/OVMF_VARS_4M.ms.fd"
$OvmfVarsLocal = Join-Path $IsoDir "OVMF_VARS.fd"

if (-not (Test-Path $OvmfCode)) {
    $OvmfCode    = "/usr/share/OVMF/OVMF_CODE_4M.fd"
    $OvmfVarsSrc = "/usr/share/OVMF/OVMF_VARS_4M.fd"
}

function Write-Step { param([string]$Msg) Write-Host "[INFO] $Msg" -ForegroundColor Cyan }
function Write-Success { param([string]$Msg) Write-Host "[SUCCESS] $Msg" -ForegroundColor Green }
function Write-WarnMsg { param([string]$Msg) Write-Host "[WARN] $Msg" -ForegroundColor Yellow }
function Write-ErrorMsg { param([string]$Msg) Write-Host "[ERROR] $Msg" -ForegroundColor Red }

function Test-VmRunning {
    if (Test-Path $PidFile) {
        $pidNum = (Get-Content $PidFile -Raw).Trim()
        if ([int]::TryParse($pidNum, [ref]$null)) {
            $proc = Get-Process -Id ([int]$pidNum) -ErrorAction SilentlyContinue
            if ($null -ne $proc) {
                return $true
            }
        }
        Remove-Item -Path $PidFile -Force -ErrorAction SilentlyContinue
    }
    return $false
}

function Init-UefiVars {
    if (-not (Test-Path $IsoDir)) {
        New-Item -ItemType Directory -Path $IsoDir -Force | Out-Null
    }
    if (-not (Test-Path $OvmfVarsLocal)) {
        Write-Step "Initializing UEFI VARS firmware ($OvmfVarsLocal)..."
        Copy-Item -Path $OvmfVarsSrc -Destination $OvmfVarsLocal -Force
    }
}

function Assert-DiskExists {
    if (-not (Test-Path $VmDisk)) {
        Write-Step "Creating sparse dynamic QCOW2 virtual disk ($VmDisk, 64G)..."
        & qemu-img create -f qcow2 $VmDisk 64G | Out-Null
        Write-Success "Virtual disk created."
    }
    else {
        $sizeMb = [math]::Round((Get-Item $VmDisk).Length / 1MB, 2)
        Write-Step "Virtual disk found: $VmDisk ($sizeMb MB)"
    }
}

function Show-Status {
    if (Test-VmRunning) {
        $pidNum = (Get-Content $PidFile -Raw).Trim()
        Write-Success "Windows Core VM is RUNNING (PID: $pidNum)"
        Write-Host "  - SSH Forwarding: localhost:$SshPort -> Guest:22"
        Write-Host "  - WinRM HTTP:     localhost:$WinrmHttpPort -> Guest:5985"
        Write-Host "  - WinRM HTTPS:    localhost:$WinrmHttpsPort -> Guest:5986"
        Write-Host "  - Antigravity:    localhost:$DaemonPort -> Guest:9090"
        Write-Host "  - VNC Console:    127.0.0.1:5901 (display $VncDisplay)"
    }
    else {
        Write-Step "Windows Core VM is STOPPED."
    }
}

function Stop-Vm {
    if (Test-VmRunning) {
        $pidNum = (Get-Content $PidFile -Raw).Trim()
        Write-Step "Stopping Windows Core VM (PID: $pidNum)..."

        # 1. Attempt ACPI powerdown via QEMU monitor socket
        if (Test-Path $MonitorSock) {
            Write-Step "Sending ACPI system_powerdown signal to Windows guest..."
            try {
                $pyScript = "import socket; s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM); s.connect('$MonitorSock'); s.sendall(b'system_powerdown\n'); s.close()"
                & python3 -c $pyScript 2>$null
            }
            catch { }
        }
        else {
            Stop-Process -Id ([int]$pidNum) -ErrorAction SilentlyContinue
        }

        # Wait up to 30s for clean shutdown
        for ($i = 0; $i -lt 30; $i++) {
            if (-not (Test-VmRunning)) {
                Remove-Item -Path $PidFile, $MonitorSock -Force -ErrorAction SilentlyContinue
                Write-Success "Windows Core VM stopped cleanly."
                return
            }
            Start-Sleep -Seconds 1
        }

        # 2. Force termination if not stopped
        Write-WarnMsg "VM did not exit within 30s, stopping process..."
        Stop-Process -Id ([int]$pidNum) -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        Remove-Item -Path $PidFile, $MonitorSock -Force -ErrorAction SilentlyContinue
        Write-Success "Windows Core VM stopped."
    }
    else {
        Write-Step "Windows Core VM is not running."
    }
}

function Start-QemuVm {
    param([string]$Mode, [bool]$IsDaemon, [bool]$IsForeground)

    if (Test-VmRunning) {
        $pidNum = (Get-Content $PidFile -Raw).Trim()
        Write-WarnMsg "VM is already running (PID: $pidNum). Stop it first."
        return
    }

    Init-UefiVars
    Assert-DiskExists
    Remove-Item -Path $MonitorSock -Force -ErrorAction SilentlyContinue

    $qemuArgs = @(
        "-name", "windows-core,process=windows-core",
        "-machine", "q35,accel=kvm,usb=off,vmport=off",
        "-cpu", "host,hv_relaxed,hv_spinlocks=0x1fff,hv_vapic,hv_time,hv_vpindex,hv_synic,hv_stimer,hv_frequencies",
        "-smp", "cores=$Cpus,threads=1,sockets=1",
        "-m", "$Ram",
        "-rtc", "base=localtime,clock=host,driftfix=slew",
        "-drive", "if=pflash,format=raw,readonly=on,file=$OvmfCode",
        "-drive", "if=pflash,format=raw,file=$OvmfVarsLocal",
        "-device", "virtio-balloon-pci,id=balloon0",
        "-device", "virtio-scsi-pci,id=scsi0",
        "-drive", "file=$VmDisk,if=none,id=hd0,format=qcow2,cache=writeback,discard=unmap",
        "-device scsi-hd,drive=hd0,bootindex=1",
        "-netdev", "user,id=net0,hostfwd=tcp::$SshPort-:22,hostfwd=tcp::$WinrmHttpPort-:5985,hostfwd=tcp::$WinrmHttpsPort-:5986,hostfwd=tcp::$DaemonPort-:9090",
        "-device", "virtio-net-pci,netdev=net0",
        "-vga", "std",
        "-display", "none",
        "-vnc", "127.0.0.1$VncDisplay",
        "-monitor", "unix:$MonitorSock,server,nowait",
        "-pidfile", "$PidFile"
    )

    if ($Mode -eq 'Install') {
        if (-not (Test-Path $InstallerIso)) {
            Write-Step "Installer ISO missing. Generating..."
            & (Join-Path $ScriptDir "build-iso.ps1")
        }
        $qemuArgs += @(
            "-drive", "file=$InstallerIso,media=cdrom,readonly=on",
            "-drive", "file=$VirtioIso,media=cdrom,readonly=on"
        )
    }
    elseif (Test-Path $VirtioIso) {
        $qemuArgs += @("-drive", "file=$VirtioIso,media=cdrom,readonly=on")
    }

    Write-Step "Starting QEMU VM (Mode: $Mode, RAM: ${Ram}MB, CPUs: $Cpus)..."
    Write-Step "VNC Debug console: 127.0.0.1:5901"
    Write-Step "Forwarded ports: SSH=$SshPort, WinRM=$WinrmHttpPort/$WinrmHttpsPort, Daemon=$DaemonPort"

    if ($IsDaemon) {
        $proc = Start-Process -FilePath "qemu-system-x86_64" -ArgumentList ($qemuArgs + "-daemonize") -PassThru
        Start-Sleep -Seconds 2
        if (Test-VmRunning) {
            Write-Success "Windows Core VM started in background."
        }
    }
    elseif ($IsForeground) {
        Write-Step "Running QEMU in foreground mode (systemd / interactive)..."
        $PID | Out-File -FilePath $PidFile -Force
        & "qemu-system-x86_64" @qemuArgs
    }
    else {
        $proc = Start-Process -FilePath "qemu-system-x86_64" -ArgumentList $qemuArgs -PassThru
        $proc.Id | Out-File -FilePath $PidFile -Force
        Write-Success "Windows Core VM started (PID: $($proc.Id))."
    }
}

if ($Status) { Show-Status; exit 0 }
if ($Stop) { Stop-Vm; exit 0 }
if ($Install) { Start-QemuVm -Mode 'Install' -IsDaemon $Daemon -IsForeground $Foreground; exit 0 }
Start-QemuVm -Mode 'Run' -IsDaemon $Daemon -IsForeground $Foreground
