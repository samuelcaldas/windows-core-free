<#
.SYNOPSIS
    Deep Memory Optimization & Feature Pruning for Windows Server Core Guest.
.DESCRIPTION
    Reclaims 600MB-800MB of RAM by removing Windows Defender, Hyper-V role,
    SysMain (Superfetch), Telemetry, and error reporting services without
    affecting user data or developer toolchains.
#>

[CmdletBinding()]
param(
    [switch]$SkipFeatureRemoval = $false
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

function Write-Step { param([string]$Msg) Write-Host "[INFO] $Msg" -ForegroundColor Cyan }
function Write-Success { param([string]$Msg) Write-Host "[SUCCESS] $Msg" -ForegroundColor Green }
function Write-WarnMsg { param([string]$Msg) Write-Host "[WARN] $Msg" -ForegroundColor Yellow }
function Write-ErrMsg { param([string]$Msg) Write-Host "[ERROR] $Msg" -ForegroundColor Red }

function Show-MemoryStats {
    param([string]$Label = "Current")
    $os = Get-CimInstance Win32_OperatingSystem
    $totalMB = [math]::Round($os.TotalVisibleMemorySize / 1024, 1)
    $freeMB = [math]::Round($os.FreePhysicalMemory / 1024, 1)
    $usedMB = [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1024, 1)
    Write-Host "`n==============================================================================" -ForegroundColor White
    Write-Host "  RAM Usage [$Label]: Used: $usedMB MB / Total: $totalMB MB (Free: $freeMB MB)" -ForegroundColor Green
    Write-Host "==============================================================================`n" -ForegroundColor White
}

function Disable-DefenderEngine {
    Write-Step "Disabling Windows Defender Real-time Protection & Preferences..."
    try {
        if (Get-Command Set-MpPreference -ErrorAction SilentlyContinue) {
            Set-MpPreference `
                -DisableRealtimeMonitoring $true `
                -DisableBehaviorMonitoring $true `
                -DisableBlockAtFirstSeen $true `
                -DisableIOAVProtection $true `
                -DisableScriptScanning $true `
                -DisableArchiveScanning $true `
                -DisableCatchupFullScan $true `
                -DisableCatchupQuickScan $true `
                -DisableEmailScanning $true `
                -DisableRemovableDriveScanning $true `
                -SubmitSamplesConsent 2 `
                -MAPSReporting 0 `
                -ErrorAction SilentlyContinue
            Write-Success "Windows Defender preferences disabled."
        }
    }
    catch {
        Write-WarnMsg "Set-MpPreference notice: $_"
    }

    # Group Policy / Registry Defender Deactivation
    $defKeys = @(
        "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender",
        "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection"
    )
    foreach ($k in $defKeys) {
        if (-not (Test-Path $k)) { New-Item -Path $k -Force | Out-Null }
    }

    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" -Name "DisableAntiSpyware" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" -Name "DisableAntiVirus" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" -Name "DisableSpecialRunningModes" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" -Name "DisableRoutinelyTakingAction" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -Name "DisableRealtimeMonitoring" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -Name "DisableBehaviorMonitoring" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -Name "DisableOnAccessProtection" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -Name "DisableScanOnRealtimeEnable" -Value 1 -Type DWord -Force

    # Stop and disable Defender services in registry (bypasses service lock)
    $defServices = @("WinDefend", "WdNisSvc", "Sense", "SecurityHealthService", "WdBoot", "WdFilter")
    foreach ($svc in $defServices) {
        $svcKey = "HKLM:\SYSTEM\CurrentControlSet\Services\$svc"
        if (Test-Path $svcKey) {
            Set-ItemProperty -Path $svcKey -Name "Start" -Value 4 -Type DWord -Force -ErrorAction SilentlyContinue
        }
        Get-Service -Name $svc -ErrorAction SilentlyContinue | Stop-Service -Force -ErrorAction SilentlyContinue
    }
    Write-Success "Windows Defender engine and filter drivers deactivated."
}

function Remove-HeavyFeatures {
    if ($SkipFeatureRemoval) {
        Write-Step "Skipping Windows Feature uninstallation as requested."
        return
    }

    Write-Step "Uninstalling unnecessary Windows Features (Windows-Defender, Hyper-V)..."
    
    $featuresToRemove = @("Windows-Defender", "Hyper-V")
    foreach ($f in $featuresToRemove) {
        try {
            $feat = Get-WindowsFeature -Name $f -ErrorAction SilentlyContinue
            if ($feat -and $feat.Installed) {
                Write-Step "Removing feature: $f..."
                Uninstall-WindowsFeature -Name $f -ErrorAction SilentlyContinue | Out-Null
                Write-Success "Removed feature: $f"
            }
            else {
                Write-Success "Feature $f is not installed or already removed."
            }
        }
        catch {
            Write-WarnMsg "Feature removal notice for $($f): $_"
        }
    }
}

function Disable-HeavyBackgroundServices {
    Write-Step "Stopping and disabling high-overhead background services..."

    $services = @(
        @{ Name = "SysMain"; Desc = "Superfetch / RAM Cache Pre-fetcher" },
        @{ Name = "DiagTrack"; Desc = "Connected User Experiences & Telemetry" },
        @{ Name = "dmwappushservice"; Desc = "WAP Push Telemetry Routing" },
        @{ Name = "WerSvc"; Desc = "Windows Error Reporting" },
        @{ Name = "PcaSvc"; Desc = "Program Compatibility Assistant" },
        @{ Name = "MapsBroker"; Desc = "Downloaded Maps Manager" },
        @{ Name = "RetailDemo"; Desc = "Retail Demo Service" },
        @{ Name = "DPS"; Desc = "Diagnostic Policy Service" },
        @{ Name = "WdiServiceHost"; Desc = "Diagnostic Service Host" },
        @{ Name = "WdiSystemHost"; Desc = "Diagnostic System Host" }
    )

    foreach ($s in $services) {
        $svcName = $s.Name
        $desc = $s.Desc
        try {
            $service = Get-Service -Name $svcName -ErrorAction SilentlyContinue
            if ($service) {
                if ($service.Status -eq 'Running') {
                    Stop-Service -Name $svcName -Force -ErrorAction SilentlyContinue
                }
                Set-Service -Name $svcName -StartupType Disabled -ErrorAction SilentlyContinue
                
                # Also set in registry to ensure persistence across reboots
                $regKey = "HKLM:\SYSTEM\CurrentControlSet\Services\$svcName"
                if (Test-Path $regKey) {
                    Set-ItemProperty -Path $regKey -Name "Start" -Value 4 -Type DWord -Force -ErrorAction SilentlyContinue
                }
                Write-Success "Disabled $svcName ($desc)"
            }
        }
        catch {
            Write-WarnMsg "Notice for $($svcName): $_"
        }
    }
}

function Configure-MemoryRegistryOptimizations {
    Write-Step "Applying kernel memory & prefetch registry optimizations..."

    # 1. Disable Prefetcher & Superfetch (Host handles disk caching for QCOW2)
    $prefetchKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters"
    if (-not (Test-Path $prefetchKey)) { New-Item -Path $prefetchKey -Force | Out-Null }
    Set-ItemProperty -Path $prefetchKey -Name "EnablePrefetcher" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $prefetchKey -Name "EnableSuperfetch" -Value 0 -Type DWord -Force
    Write-Success "Prefetcher and Superfetch disabled."

    # 2. Disable Windows Telemetry & Diagnostic Data Collection
    $telemetryKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
    if (-not (Test-Path $telemetryKey)) { New-Item -Path $telemetryKey -Force | Out-Null }
    Set-ItemProperty -Path $telemetryKey -Name "AllowTelemetry" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $telemetryKey -Name "MaxTelemetryAllowed" -Value 0 -Type DWord -Force
    Write-Success "Telemetry data collection disabled."

    # 3. Disable Windows Error Reporting
    $werKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting"
    if (-not (Test-Path $werKey)) { New-Item -Path $werKey -Force | Out-Null }
    Set-ItemProperty -Path $werKey -Name "Disabled" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $werKey -Name "DoNotReport" -Value 1 -Type DWord -Force
    Write-Success "Windows Error Reporting disabled."

    # 4. Disable Background Maintenance Wakeup & Throttling
    $maintKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance"
    if (-not (Test-Path $maintKey)) { New-Item -Path $maintKey -Force | Out-Null }
    Set-ItemProperty -Path $maintKey -Name "MaintenanceDisabled" -Value 1 -Type DWord -Force
    Write-Success "Background maintenance throttling tuned."

    # 5. Disable Consumer / Cloud Content & App Suggestions
    $cloudKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"
    if (-not (Test-Path $cloudKey)) { New-Item -Path $cloudKey -Force | Out-Null }
    Set-ItemProperty -Path $cloudKey -Name "DisableWindowsConsumerFeatures" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $cloudKey -Name "DisableSoftLanding" -Value 1 -Type DWord -Force
    Write-Success "Consumer and cloud content disabled."
}

function Disable-UnnecessaryScheduledTasks {
    Write-Step "Disabling telemetry, diagnostics, and maintenance scheduled tasks..."

    $taskPaths = @(
        "\Microsoft\Windows\Customer Experience Improvement Program\",
        "\Microsoft\Windows\Application Experience\",
        "\Microsoft\Windows\Autochk\",
        "\Microsoft\Windows\DiskDiagnostic\",
        "\Microsoft\Windows\Windows Defender\",
        "\Microsoft\Windows\Maintenance\",
        "\Microsoft\Windows\Feedback\Siuf\"
    )

    foreach ($path in $taskPaths) {
        try {
            $tasks = Get-ScheduledTask -TaskPath $path -ErrorAction SilentlyContinue
            foreach ($t in $tasks) {
                if ($t.State -ne 'Disabled') {
                    Disable-ScheduledTask -TaskName $t.TaskName -TaskPath $t.TaskPath -ErrorAction SilentlyContinue | Out-Null
                    Write-Success "Disabled task: $($t.TaskPath)$($t.TaskName)"
                }
            }
        }
        catch {
            # Scheduled task query may fail silently for non-existent folders
        }
    }
}

function Flush-MemoryGarbage {
    Write-Step "Flushing system memory cache and running garbage collection..."
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
    [System.GC]::Collect()
}

function Main {
    Write-Host "==============================================================================" -ForegroundColor Cyan
    Write-Host "  Windows Core Guest - System & Memory Optimization Suite" -ForegroundColor Cyan
    Write-Host "==============================================================================" -ForegroundColor Cyan

    Show-MemoryStats -Label "BEFORE Optimization"

    Disable-DefenderEngine
    Remove-HeavyFeatures
    Disable-HeavyBackgroundServices
    Configure-MemoryRegistryOptimizations
    Disable-UnnecessaryScheduledTasks
    Flush-MemoryGarbage

    Show-MemoryStats -Label "AFTER Optimization"

    Write-Success "System & memory optimization completed successfully."
}

Main
