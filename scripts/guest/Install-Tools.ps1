<#
.SYNOPSIS
    Guest Script: Installs developer toolchains (Git, Node.js LTS, Python 3, PowerShell 7, OmniGet).
.DESCRIPTION
    Automates silent downloading and installation of core developer runtimes and tools
    needed for Windows development and AI Agent execution, delegating to OmniGet.
#>
[CmdletBinding()]
param(
    [switch]$SkipDotNet,
    [switch]$SkipNode,
    [switch]$SkipGit,
    [switch]$SkipGh,
    [switch]$SkipGitea,
    [switch]$SkipPython,
    [switch]$SkipPwsh,
    [switch]$SkipDocker
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Write-Step { param([string]$Msg) Write-Host "[INFO] $Msg" -ForegroundColor Cyan }
function Write-Success { param([string]$Msg) Write-Host "[SUCCESS] $Msg" -ForegroundColor Green }
function Write-WarnMsg { param([string]$Msg) Write-Host "[WARN] $Msg" -ForegroundColor Yellow }

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$TempDir = "$env:TEMP\win_tools_installer"
if (-not (Test-Path $TempDir)) {
    New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
}

function Refresh-EnvironmentPath {
    $machinePath = [System.Environment]::GetEnvironmentVariable('Path', [System.EnvironmentVariableTarget]::Machine)
    $userPath    = [System.Environment]::GetEnvironmentVariable('Path', [System.EnvironmentVariableTarget]::User)
    $extraPaths  = @(
        'C:\Program Files\OmniGet\bin',
        'C:\Program Files\dotnet',
        'C:\Program Files\Docker',
        'C:\Program Files\Git\bin',
        'C:\Program Files\Git\cmd',
        'C:\Program Files\GitHub CLI',
        'C:\Program Files\Gitea CLI',
        'C:\Program Files\nodejs',
        "$env:APPDATA\npm",
        "$env:USERPROFILE\AppData\Roaming\npm",
        'C:\Program Files\PowerShell\7',
        'C:\Program Files\Python312',
        'C:\Program Files\Python312\Scripts'
    )
    $env:Path = ("$machinePath;$userPath;" + ($extraPaths -join ';')).Trim(';')
}

function Main {
    Write-Host "=============================================================================="
    Write-Host "  Windows Core Guest - Developer Toolchain Installer"
    Write-Host "=============================================================================="

    # 1. Deploy OmniGet Package Engine
    $installOmniGet = Join-Path $PSScriptRoot "Install-OmniGet.ps1"
    if (Test-Path $installOmniGet) {
        Write-Step "Deploying OmniGet Universal Package Engine..."
        & $installOmniGet -DeployOnly
    }

    # 2. Run DevStack Preset via OmniGet
    $omniExe = "C:\Program Files\OmniGet\src\OmniGet.ps1"
    if (Test-Path $omniExe) {
        Write-Step "Executing DevStack toolchain preset via OmniGet..."
        & pwsh.exe -ExecutionPolicy Bypass -File $omniExe -Preset DevStack -Silent
    }

    Refresh-EnvironmentPath

    # 3. Post-install Desktop Shell & Terminal setup
    $desktopShellScript = Join-Path $PSScriptRoot "Install-DesktopShell.ps1"
    if (Test-Path $desktopShellScript) {
        try {
            & $desktopShellScript
        }
        catch {
            Write-WarnMsg "Install-DesktopShell warning: $_"
        }
    }

    $terminalScript = Join-Path $PSScriptRoot "Install-WindowsTerminal.ps1"
    if (Test-Path $terminalScript) {
        try {
            & $terminalScript
        }
        catch {
            Write-WarnMsg "Install-WindowsTerminal warning: $_"
        }
    }

    $sconfigScript = Join-Path $PSScriptRoot "Install-SConfigPatch.ps1"
    if (Test-Path $sconfigScript) {
        try {
            & $sconfigScript
        }
        catch {
            Write-WarnMsg "Install-SConfigPatch warning: $_"
        }
    }

    Write-Success "Developer toolchains and OmniGet installed successfully."
}

Main
