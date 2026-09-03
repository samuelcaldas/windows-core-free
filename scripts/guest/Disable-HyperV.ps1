<#
.SYNOPSIS
    Guest Script: Deactivates Hyper-V hypervisor roles, services, and boot launch.
.DESCRIPTION
    Since Windows CoreOS (WCOS) operates as a virtualized guest on Linux KVM, nested Hyper-V
    roles and services are decommissioned to save RAM/CPU and prevent hypervisor conflicts.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Write-Step { param([string]$Msg) Write-Host "[INFO] $Msg" -ForegroundColor Cyan }
function Write-Success { param([string]$Msg) Write-Host "[SUCCESS] $Msg" -ForegroundColor Green }
function Write-WarnMsg { param([string]$Msg) Write-Host "[WARN] $Msg" -ForegroundColor Yellow }

function Disable-HyperVBootLaunch {
    Write-Step "Disabling hypervisor launch at boot via bcdedit..."
    try {
        & bcdedit.exe /set hypervisorlaunchtype off | Out-Null
        Write-Success "Hypervisor boot launch disabled (hypervisorlaunchtype=off)."
    }
    catch {
        Write-WarnMsg "Failed to update bcdedit: $_"
    }
}

function Disable-HyperVServices {
    Write-Step "Stopping and disabling Hyper-V background services..."
    $services = @(
        'vmms',
        'vmicvss',
        'vmicguestinterface',
        'vmicheartbeat',
        'vmickvpexchange',
        'vmicrdv',
        'vmicshutdown',
        'vmictimesync'
    )

    foreach ($svcName in $services) {
        $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
        if ($null -ne $svc) {
            try {
                if ($svc.Status -eq 'Running') {
                    Stop-Service -Name $svcName -Force -ErrorAction SilentlyContinue
                }
                Set-Service -Name $svcName -StartupType Disabled -ErrorAction SilentlyContinue
                Write-Success "Service disabled: $svcName"
            }
            catch {
                Write-WarnMsg "Could not disable service ${svcName}: $_"
            }
        }
    }
}

function Remove-HyperVRole {
    Write-Step "Checking Hyper-V optional features..."
    try {
        $feature = Get-WindowsOptionalFeature -Online -FeatureName 'Microsoft-Hyper-V-All' -ErrorAction SilentlyContinue
        if ($null -ne $feature -and $feature.State -eq 'Enabled') {
            Write-Step "Disabling Microsoft-Hyper-V-All feature..."
            Disable-WindowsOptionalFeature -Online -FeatureName 'Microsoft-Hyper-V-All' -NoRestart | Out-Null
            Write-Success "Microsoft-Hyper-V-All feature disabled."
        }
        else {
            Write-Success "Hyper-V feature is already disabled or not present."
        }
    }
    catch {
        Write-WarnMsg "Optional feature query/removal returned: $_"
    }
}

function Main {
    Write-Host "=============================================================================="
    Write-Host "  Windows Core Guest - Hyper-V Role Decommissioning"
    Write-Host "=============================================================================="
    Disable-HyperVBootLaunch
    Disable-HyperVServices
    Remove-HyperVRole
    Write-Success "Hyper-V role deactivation completed successfully."
}

Main
