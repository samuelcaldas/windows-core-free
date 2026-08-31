#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Phase 4 & 5: Synchronize SSH Keys/Config & Orchestrate Remote Toolchains (PowerShell 7)
.DESCRIPTION
    Deploys Ubuntu host's SSH keys, configs, and guest provisioning scripts to the Windows Core VM.
    Executes toolchain installations (Git, Node.js, Python, Claude CLI, Antigravity Daemon).
#>
[CmdletBinding()]
param(
    [string]$VmHost = "127.0.0.1",
    [int]$VmPort = 2222,
    [string]$VmUser = "samuelcaldas"
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$ScriptDir        = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot         = (Resolve-Path "$ScriptDir/../..").Path
$GuestScriptsDir  = Join-Path $RepoRoot "scripts/guest"
$HostSshDir       = Join-Path $HOME ".ssh"

function Write-Step { param([string]$Msg) Write-Host "[INFO] $Msg" -ForegroundColor Cyan }
function Write-Success { param([string]$Msg) Write-Host "[SUCCESS] $Msg" -ForegroundColor Green }
function Write-WarnMsg { param([string]$Msg) Write-Host "[WARN] $Msg" -ForegroundColor Yellow }
function Write-ErrorMsg { param([string]$Msg) Write-Host "[ERROR] $Msg" -ForegroundColor Red }

function Assert-VmConnectivity {
    Write-Step "Checking VM connectivity on ${VmHost}:${VmPort}..."
    $tcp = New-Object System.Net.Sockets.TcpClient
    try {
        $iar = $tcp.BeginConnect($VmHost, $VmPort, $null, $null)
        $success = $iar.AsyncWaitHandle.WaitOne(3000, $false)
        if (-not $success) {
            Write-ErrorMsg "Cannot connect to ${VmHost}:${VmPort}. Is the VM running?"
            exit 1
        }
        $tcp.EndConnect($iar)
        Write-Success "Port $VmPort is reachable."
    }
    finally {
        $tcp.Close()
    }
}

function Sync-SshKeysAndConfig {
    Write-Step "Synchronizing host SSH keys and configuration to Windows Core..."
    $stagingDir = Join-Path ([System.IO.Path]::GetTempPath()) "ssh_sync_$([System.Guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $stagingDir -Force | Out-Null

    try {
        # Combine public keys
        $authKeys = Join-Path $stagingDir "authorized_keys"
        $pubFiles = Get-ChildItem -Path $HostSshDir -Filter "*.pub" -File -ErrorAction SilentlyContinue
        foreach ($pub in $pubFiles) {
            Get-Content $pub.FullName | Out-File -FilePath $authKeys -Append -Encoding ascii
        }

        # Copy private keys, configs, and known_hosts
        foreach ($keyfile in @('id_ed25519', 'id_ed25519.pub', 'google_compute_engine', 'google_compute_engine.pub', 'config', 'known_hosts')) {
            $src = Join-Path $HostSshDir $keyfile
            if (Test-Path $src) {
                Copy-Item -Path $src -Destination (Join-Path $stagingDir $keyfile) -Force
            }
        }

        # Transfer files via SCP
        Write-Step "Deploying SSH files to C:\Users\${VmUser}\.ssh..."
        $sshOpts = @("-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null", "-P", "$VmPort")
        
        & ssh -p $VmPort -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${VmUser}@${VmHost}" "powershell -Command `"New-Item -ItemType Directory -Path 'C:\Users\${VmUser}\.ssh' -Force; New-Item -ItemType Directory -Path 'C:\ProgramData\ssh' -Force`""

        foreach ($item in (Get-ChildItem -Path $stagingDir -File)) {
            & scp @sshOpts $item.FullName "${VmUser}@${VmHost}:C:/Users/${VmUser}/.ssh/$($item.Name)"
        }

        # Set ACLs
        Write-Step "Configuring Windows ACLs on authorized_keys..."
        $aclCmd = "powershell -Command `"
            Copy-Item -Path 'C:\Users\${VmUser}\.ssh\authorized_keys' -Destination 'C:\ProgramData\ssh\administrators_authorized_keys' -Force -ErrorAction SilentlyContinue;
            icacls 'C:\ProgramData\ssh\administrators_authorized_keys' /inheritance:r /grant 'NT AUTHORITY\SYSTEM:(F)' /grant 'BUILTIN\Administrators:(F)';
            icacls 'C:\Users\${VmUser}\.ssh' /inheritance:r /grant '${VmUser}:(OI)(CI)(F)' /grant 'NT AUTHORITY\SYSTEM:(OI)(CI)(F)';
            Get-ChildItem 'C:\Users\${VmUser}\.ssh' | ForEach-Object { icacls `$_.FullName /inheritance:r /grant '${VmUser}:(F)' /grant 'NT AUTHORITY\SYSTEM:(F)' }
        `""
        & ssh -p $VmPort -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${VmUser}@${VmHost}" $aclCmd
        Write-Success "SSH keys and configurations synchronized with strict Windows ACLs."
    }
    finally {
        if (Test-Path $stagingDir) { Remove-Item -Path $stagingDir -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

function Deploy-GuestScriptsAndTools {
    Write-Step "Deploying and running guest toolchain & agent scripts..."
    $sshOpts = @("-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null", "-p", "$VmPort")
    $scpOpts = @("-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null", "-P", "$VmPort")

    & ssh @sshOpts "${VmUser}@${VmHost}" "powershell -Command `"New-Item -ItemType Directory -Path 'C:\Provisioning\scripts' -Force`""

    foreach ($script in (Get-ChildItem -Path $GuestScriptsDir -Filter "*.ps1" -File)) {
        Write-Step "Uploading $($script.Name)..."
        & scp @scpOpts $script.FullName "${VmUser}@${VmHost}:C:/Provisioning/scripts/$($script.Name)"
    }

    Write-Step "Executing Specialize.ps1..."
    & ssh @sshOpts "${VmUser}@${VmHost}" "powershell -ExecutionPolicy Bypass -File 'C:\Provisioning\scripts\Specialize.ps1'"

    Write-Step "Executing Install-Tools.ps1..."
    & ssh @sshOpts "${VmUser}@${VmHost}" "powershell -ExecutionPolicy Bypass -File 'C:\Provisioning\scripts\Install-Tools.ps1'"

    Write-Step "Executing Setup-Agents.ps1..."
    & ssh @sshOpts "${VmUser}@${VmHost}" "powershell -ExecutionPolicy Bypass -File 'C:\Provisioning\scripts\Setup-Agents.ps1'"

    Write-Success "Guest provisioning scripts executed successfully."
}

function Verify-RemoteEnvironment {
    Write-Step "Verifying remote Windows Core environment and Claude CLI..."
    $sshOpts = @("-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null", "-p", "$VmPort")
    & ssh @sshOpts "${VmUser}@${VmHost}" "powershell -Command `"
        Write-Host '--- Environment Info ---';
        whoami;
        hostname;
        Write-Host '--- Installed Tools ---';
        git --version;
        gh --version;
        node -v;
        npm -v;
        python --version;
        claude --version;
    `""
    Write-Success "Remote provisioning and Claude CLI verification complete."
}

function Main {
    Write-Host "=============================================================================="
    Write-Host "  Windows Core Headless Host - Remote Provisioning (PowerShell 7)"
    Write-Host "=============================================================================="
    Assert-VmConnectivity
    Sync-SshKeysAndConfig
    Deploy-GuestScriptsAndTools
    Verify-RemoteEnvironment
}

Main
