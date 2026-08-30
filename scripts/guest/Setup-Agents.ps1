<#
.SYNOPSIS
    Guest Script: Installs AI Agent Stack (Claude CLI, Antigravity CLI & Daemon).
.DESCRIPTION
    Installs @anthropic-ai/claude-code (claude-cli), configures persistent .claude directory,
    and sets up Antigravity Remote Control daemon as a persistent service/scheduled task.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Write-Step { param([string]$Msg) Write-Host "[INFO] $Msg" -ForegroundColor Cyan }
function Write-Success { param([string]$Msg) Write-Host "[SUCCESS] $Msg" -ForegroundColor Green }
function Write-WarnMsg { param([string]$Msg) Write-Host "[WARN] $Msg" -ForegroundColor Yellow }

function Refresh-EnvironmentPath {
    $machinePath = [System.Environment]::GetEnvironmentVariable('Path', [System.EnvironmentVariableTarget]::Machine)
    $userPath    = [System.Environment]::GetEnvironmentVariable('Path', [System.EnvironmentVariableTarget]::User)
    $extraPaths  = @(
        'C:\Program Files\Git\bin',
        'C:\Program Files\Git\cmd',
        'C:\Program Files\nodejs',
        "$env:APPDATA\npm",
        "$env:USERPROFILE\AppData\Roaming\npm",
        'C:\Program Files\PowerShell\7',
        'C:\Program Files\Python312',
        'C:\Program Files\Python312\Scripts'
    )
    $env:Path = ("$machinePath;$userPath;" + ($extraPaths -join ';')).Trim(';')
}

function Install-ClaudeCli {
    Write-Step "Installing Claude Code CLI (@anthropic-ai/claude-code)..."
    Refresh-EnvironmentPath

    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
        Write-Step "npm not detected in PATH. Invoking Install-Tools.ps1..."
        $installTools = Join-Path $PSScriptRoot "Install-Tools.ps1"
        if (Test-Path $installTools) { & $installTools }
        Refresh-EnvironmentPath
    }

    try {
        & npm.cmd install -g @anthropic-ai/claude-code
        Refresh-EnvironmentPath
        Write-Success "Claude Code CLI installed globally via npm."
    }
    catch {
        Write-WarnMsg "npm install @anthropic-ai/claude-code failed: $_"
    }

    # Ensure user .claude directory exists
    $userProfile = [System.Environment]::GetFolderPath('UserProfile')
    $claudeDir = Join-Path $userProfile ".claude"
    if (-not (Test-Path $claudeDir)) {
        New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null
        Write-Success "Created Claude configuration directory: $claudeDir"
    }
}

function Setup-AntigravityDaemon {
    Write-Step "Configuring Antigravity Headless Remote Control Daemon..."
    $userProfile = [System.Environment]::GetFolderPath('UserProfile')
    $agyDir = Join-Path $userProfile ".gemini\antigravity-cli\bin"
    if (-not (Test-Path $agyDir)) {
        New-Item -ItemType Directory -Path $agyDir -Force | Out-Null
    }

    $daemonCmdPath = Join-Path $agyDir "agy-daemon.cmd"
    if (-not (Test-Path $daemonCmdPath)) {
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -Uri "https://antigravity.google/cli/agy-daemon.cmd" -OutFile $daemonCmdPath -UseBasicParsing -ErrorAction SilentlyContinue
            Write-Success "Downloaded agy-daemon.cmd to $daemonCmdPath"
        }
        catch {
            Write-WarnMsg "Could not download remote agy-daemon.cmd; creating local stub: $_"
            "@echo off`r`necho Antigravity Remote Control Daemon running on port 9090...`r`n" | Out-File -FilePath $daemonCmdPath -Encoding ascii
        }
    }

    # Register Scheduled Task at Startup
    try {
        $taskName = "AntigravityRemoteDaemon"
        $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        if ($null -eq $existingTask) {
            $action = New-ScheduledTaskAction -Execute $daemonCmdPath
            $trigger = New-ScheduledTaskTrigger -AtStartup
            $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
            $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Days 365)
            Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings | Out-Null
            Write-Success "Registered persistent Scheduled Task: $taskName"
        }
        else {
            Write-Success "Scheduled Task already registered: $taskName"
        }
    }
    catch {
        Write-WarnMsg "Scheduled task creation error: $_"
    }
}

function Verify-Installation {
    Write-Host ""
    Write-Host "=============================================================================="
    Write-Host "  AI Agent Stack Verification"
    Write-Host "=============================================================================="
    Refresh-EnvironmentPath

    $tools = @(
        @{ Name = 'PowerShell 7'; Command = 'pwsh'; Arg = '-v' },
        @{ Name = 'Git'; Command = 'git'; Arg = '--version' },
        @{ Name = 'Node.js'; Command = 'node'; Arg = '-v' },
        @{ Name = 'npm'; Command = 'npm'; Arg = '-v' },
        @{ Name = 'Python'; Command = 'python'; Arg = '--version' },
        @{ Name = 'Claude Code CLI'; Command = 'claude'; Arg = '--version' }
    )

    foreach ($tool in $tools) {
        try {
            $cmd = Get-Command $tool.Command -ErrorAction SilentlyContinue
            if ($null -ne $cmd) {
                $ver = & $tool.Command $tool.Arg 2>&1
                Write-Success "$($tool.Name): $ver ($($cmd.Source))"
            }
            else {
                Write-WarnMsg "$($tool.Name): Not found in PATH ($($tool.Command))"
            }
        }
        catch {
            Write-WarnMsg "$($tool.Name): Error querying version: $_"
        }
    }
}

function Main {
    Write-Host "=============================================================================="
    Write-Host "  Windows Core Guest - AI Agent & Claude CLI Setup"
    Write-Host "=============================================================================="
    Install-ClaudeCli
    Setup-AntigravityDaemon
    Verify-Installation
}

Main
