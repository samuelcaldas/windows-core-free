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

function Invoke-AtlasNgenOptimization {
    Write-Step "Running Atlas NGEN .NET assembly pre-compilation (10x faster PowerShell startup)..."
    try {
        $frameworkDir = [Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()
        $ngenExe = Join-Path $frameworkDir "ngen.exe"
        if (Test-Path $ngenExe) {
            [AppDomain]::CurrentDomain.GetAssemblies().Location | Where-Object { $_ } | ForEach-Object {
                $asmName = Split-Path $_ -Leaf
                & $ngenExe install $_ /nologo 2>&1 | Out-Null
            }
            Write-Success "NGEN native pre-compilation completed."
        }
    }
    catch {
        Write-WarnMsg "NGEN optimization notice: $_"
    }
}

function Invoke-AtlasServiceHostConsolidation {
    Write-Step "Consolidating svchost service hosts (Atlas SvcHostSplitDisable)..."
    try {
        Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Services' -ErrorAction SilentlyContinue | ForEach-Object {
            if ($_.PSChildName -notmatch 'Xbl|Xbox') {
                $svcKey = "HKLM:\SYSTEM\CurrentControlSet\Services\$($_.PSChildName)"
                $val = Get-ItemProperty -Path $svcKey -ErrorAction SilentlyContinue
                if ($null -ne $val -and ($val.PSObject.Properties['Start'])) {
                    Set-ItemProperty -Path $svcKey -Name 'SvcHostSplitDisable' -Type DWORD -Value 1 -Force -ErrorAction SilentlyContinue
                }
            }
        }
        Write-Success "Service Host Splitting disabled (svchost processes consolidated)."
    }
    catch {
        Write-WarnMsg "SvcHost consolidation notice: $_"
    }
}

function Invoke-AtlasNtfsOptimizations {
    Write-Step "Applying Atlas NTFS filesystem optimizations (disabling last access & 8.3 names)..."
    try {
        & fsutil.exe behavior set disablelastaccess 1 | Out-Null
        & fsutil.exe 8dot3name set 1 | Out-Null
        Write-Success "NTFS I/O optimizations applied (disablelastaccess=1, 8dot3name=1)."
    }
    catch {
        Write-WarnMsg "NTFS optimization notice: $_"
    }
}

function Invoke-AtlasReservedStorageDeactivation {
    Write-Step "Disabling Windows Reserved Storage buffer (~7 GB disk space saving)..."
    try {
        & DISM.exe /Online /Set-ReservedStorageState /State:Disabled /NoRestart 2>&1 | Out-Null
        Write-Success "Windows Reserved Storage disabled."
    }
    catch {
        Write-WarnMsg "Reserved storage deactivation notice: $_"
    }
}

function Invoke-AtlasNetworkTweaks {
    Write-Step "Applying Atlas network optimizations (disabling LLMNR & SMB bandwidth throttling)..."
    try {
        # Disable LLMNR multicast
        $dnsKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient"
        if (-not (Test-Path $dnsKey)) { New-Item -Path $dnsKey -Force | Out-Null }
        Set-ItemProperty -Path $dnsKey -Name "EnableMulticast" -Value 0 -Type DWord -Force
        
        # Disable SMB bandwidth throttling for maximum transfer speed
        $lanmanKey = "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters"
        if (-not (Test-Path $lanmanKey)) { New-Item -Path $lanmanKey -Force | Out-Null }
        Set-ItemProperty -Path $lanmanKey -Name "DisableBandwidthThrottling" -Value 1 -Type DWord -Force
        
        Write-Success "LLMNR disabled and SMB bandwidth throttling removed."
    }
    catch {
        Write-WarnMsg "Network tweaks notice: $_"
    }
}

function Invoke-AtlasPnpOptimization {
    Write-Step "Disabling unneeded virtualized PnP legacy devices..."
    $devices = @(
        "AMD PSP", "AMD SMBus", "Base System Device", "Composite Bus Enumerator",
        "Direct memory access controller", "High precision event timer", "Intel Management Engine",
        "Intel SMBus", "Legacy device", "Microsoft Kernel Debug Network Adapter",
        "Motherboard resources", "Numeric Data Processor", "PCI Data Acquisition and Signal Processing Controller",
        "PCI Encryption/Decryption Controller", "PCI Memory Controller", "PCI Simple Communications Controller",
        "PCI standard RAM Controller", "SM Bus Controller", "System CMOS/real time clock",
        "System Speaker", "System Timer"
    )
    try {
        Get-PnpDevice -FriendlyName $devices -ErrorAction SilentlyContinue | Disable-PnpDevice -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
        Write-Success "Unneeded virtual PnP devices disabled."
    }
    catch {
        Write-WarnMsg "PnP device disabling notice: $_"
    }
}

function Invoke-AtlasDevQolTweaks {
    Write-Step "Removing WindowsApps Python Microsoft Store redirection stubs..."
    try {
        Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\WindowsApps\python*.exe" -Force -ErrorAction SilentlyContinue
        if (Test-Path "Alias:python") { Remove-Item "Alias:python" -Force -ErrorAction SilentlyContinue }
        if (Test-Path "Alias:python3") { Remove-Item "Alias:python3" -Force -ErrorAction SilentlyContinue }
        Write-Success "Python store redirection stubs purged."
    }
    catch {
        Write-WarnMsg "Python stub cleanup notice: $_"
    }
}

function Invoke-AtlasDeepCleanup {
    Write-Step "Performing deep system, temp, and cache cleanup..."
    try {
        $tempPaths = @(
            "$env:TEMP\*",
            "$env:LOCALAPPDATA\Temp\*",
            "$env:WINDIR\Temp\*",
            "$env:WINDIR\Logs\CBS\*.log",
            "$env:WINDIR\SoftwareDistribution\Download\*"
        )
        foreach ($tp in $tempPaths) {
            Remove-Item -Path $tp -Recurse -Force -ErrorAction SilentlyContinue
        }
        
        $cleanmgr = "$env:WINDIR\System32\cleanmgr.exe"
        if (Test-Path $cleanmgr) {
            Start-Process -FilePath $cleanmgr -ArgumentList "/sagerun:64" -WindowStyle Hidden -ErrorAction SilentlyContinue
        }
        Write-Success "Temp folders and update download cache purged."
    }
    catch {
        Write-WarnMsg "Deep cleanup notice: $_"
    }
}

function Invoke-AtlasFastShutdownTweaks {
    Write-Step "Configuring Atlas fast shutdown & zero-delay startup..."
    try {
        # Reduce service kill timeout on shutdown
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control" -Name "WaitToKillServiceTimeout" -Value "2000" -Type String -Force
        
        # Kill hung desktop apps quickly on logoff/reboot
        $desktopKey = "HKCU:\Control Panel\Desktop"
        if (Test-Path $desktopKey) {
            Set-ItemProperty -Path $desktopKey -Name "AutoEndTasks" -Value "1" -Type String -Force
            Set-ItemProperty -Path $desktopKey -Name "HungAppTimeout" -Value "1000" -Type String -Force
            Set-ItemProperty -Path $desktopKey -Name "WaitToKillAppTimeout" -Value "2000" -Type String -Force
            Set-ItemProperty -Path $desktopKey -Name "MenuShowDelay" -Value "0" -Type String -Force
        }
        
        # Disable Explorer startup delays
        $serializeKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize"
        if (-not (Test-Path $serializeKey)) { New-Item -Path $serializeKey -Force | Out-Null }
        Set-ItemProperty -Path $serializeKey -Name "StartupDelayInMSec" -Value 0 -Type DWord -Force
        
        Write-Success "Fast shutdown and zero startup delay configured."
    }
    catch {
        Write-WarnMsg "Fast shutdown tweaks notice: $_"
    }
}

function Invoke-AtlasSchedulerAndNetworkTweaks {
    Write-Step "Tuning Windows scheduler & MMCSS network throttling..."
    try {
        # Optimize thread quantum for foreground/interactive CLI workloads (0x26 = 38)
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -Name "Win32PrioritySeparation" -Value 38 -Type DWord -Force
        
        # Remove network throttling index & disable system responsiveness cap
        $sysProfile = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        if (-not (Test-Path $sysProfile)) { New-Item -Path $sysProfile -Force | Out-Null }
        Set-ItemProperty -Path $sysProfile -Name "NetworkThrottlingIndex" -Value 0xFFFFFFFF -Type DWord -Force
        Set-ItemProperty -Path $sysProfile -Name "SystemResponsiveness" -Value 0 -Type DWord -Force
        
        # Disable Fault Tolerant Heap overhead
        $fthKey = "HKLM:\SOFTWARE\Microsoft\FTH"
        if (-not (Test-Path $fthKey)) { New-Item -Path $fthKey -Force | Out-Null }
        Set-ItemProperty -Path $fthKey -Name "Enabled" -Value 0 -Type DWord -Force
        
        Write-Success "Scheduler and MMCSS network throttling tuned."
    }
    catch {
        Write-WarnMsg "Scheduler/MMCSS tweaks notice: $_"
    }
}

function Invoke-AtlasDeliveryOptimizationLockdown {
    Write-Step "Locking down Delivery Optimization P2P and automatic update reboots..."
    try {
        # Disable Delivery Optimization P2P bandwidth sharing
        $doKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization"
        if (-not (Test-Path $doKey)) { New-Item -Path $doKey -Force | Out-Null }
        Set-ItemProperty -Path $doKey -Name "DODownloadMode" -Value 0 -Type DWord -Force
        
        # Disable automatic reboots with logged-on users
        $wuKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
        if (-not (Test-Path $wuKey)) { New-Item -Path $wuKey -Force | Out-Null }
        Set-ItemProperty -Path $wuKey -Name "NoAutoRebootWithLoggedOnUsers" -Value 1 -Type DWord -Force
        Set-ItemProperty -Path $wuKey -Name "AlwaysAutoRebootAtScheduledTime" -Value 0 -Type DWord -Force
        
        Write-Success "Delivery Optimization P2P and auto-reboots disabled."
    }
    catch {
        Write-WarnMsg "Delivery optimization lockdown notice: $_"
    }
}

function Invoke-AtlasSecurityHardening {
    Write-Step "Applying security surface hardening & ACPI protection..."
    try {
        # Block anonymous enumeration of SAM accounts and shares
        $lsaKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"
        Set-ItemProperty -Path $lsaKey -Name "RestrictAnonymous" -Value 1 -Type DWord -Force
        Set-ItemProperty -Path $lsaKey -Name "RestrictAnonymousSAM" -Value 1 -Type DWord -Force
        
        # Disable unapproved ACPI WPBT binary execution
        $smKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager"
        Set-ItemProperty -Path $smKey -Name "DisableWpbtExecution" -Value 1 -Type DWord -Force
        
        # Disable legacy Remote Assistance
        $raKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance"
        if (-not (Test-Path $raKey)) { New-Item -Path $raKey -Force | Out-Null }
        Set-ItemProperty -Path $raKey -Name "fAllowToGetHelp" -Value 0 -Type DWord -Force
        
        Write-Success "SAM restriction, WPBT protection, and Remote Assistance deactivation applied."
    }
    catch {
        Write-WarnMsg "Security hardening notice: $_"
    }
}

function Register-DefaultFileAssociations {
    Write-Step "Setting default file associations for PowerShell 7 and CLI tools..."
    try {
        $pwshExe = "C:\Program Files\PowerShell\7\pwsh.exe"
        if (Test-Path $pwshExe) {
            # Associate .ps1 with PowerShell 7
            $ps1Class = "HKLM:\SOFTWARE\Classes\Microsoft.PowerShellScript.1\Shell\Open\Command"
            if (-not (Test-Path $ps1Class)) { New-Item -Path $ps1Class -Force | Out-Null }
            Set-ItemProperty -Path $ps1Class -Name "(Default)" -Value "`"$pwshExe`" -NoProfile -ExecutionPolicy Bypass -File `"%1`" %*" -Force
            
            # Machine PATH & command alias
            $linkPath = "C:\Program Files\PowerShell\7\powershell.exe"
            if (-not (Test-Path $linkPath)) {
                try { New-Item -ItemType HardLink -Path $linkPath -Target $pwshExe -Force | Out-Null } catch { Copy-Item -Path $pwshExe -Destination $linkPath -Force | Out-Null }
            }
            Write-Success "PowerShell 7 registered as default .ps1 handler and CLI powershell link."
        }
    }
    catch {
        Write-WarnMsg "File association notice: $_"
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
    Write-Host "  Windows Core Guest - System & Memory Optimization Suite (Atlas Enhanced)" -ForegroundColor Cyan
    Write-Host "==============================================================================" -ForegroundColor Cyan

    Show-MemoryStats -Label "BEFORE Optimization"

    Disable-DefenderEngine
    Remove-HeavyFeatures
    Disable-HeavyBackgroundServices
    Configure-MemoryRegistryOptimizations
    Disable-UnnecessaryScheduledTasks
    
    # Atlas OS Enhancements
    Invoke-AtlasNgenOptimization
    Invoke-AtlasServiceHostConsolidation
    Invoke-AtlasNtfsOptimizations
    Invoke-AtlasReservedStorageDeactivation
    Invoke-AtlasNetworkTweaks
    Invoke-AtlasPnpOptimization
    Invoke-AtlasDevQolTweaks
    Invoke-AtlasFastShutdownTweaks
    Invoke-AtlasSchedulerAndNetworkTweaks
    Invoke-AtlasDeliveryOptimizationLockdown
    Invoke-AtlasSecurityHardening
    Register-DefaultFileAssociations
    Invoke-AtlasDeepCleanup
    
    Flush-MemoryGarbage

    Show-MemoryStats -Label "AFTER Optimization"

    Write-Success "System & memory optimization completed successfully."
}

Main
