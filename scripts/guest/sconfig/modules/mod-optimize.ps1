<#
.SYNOPSIS
    sconfig Module: System Performance & Memory Pruning.
.DESCRIPTION
    Monitors RAM/CPU usage and triggers deep memory optimization / service tuning.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'SilentlyContinue'

function Write-Header {
    Clear-Host
    Write-Host "============================================================================" -ForegroundColor Cyan
    Write-Host "              System Performance & Memory Pruning                           " -ForegroundColor White
    Write-Host "============================================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Show-Stats {
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $totalMb = [math]::Round($os.TotalVisibleMemorySize / 1024, 0)
    $freeMb  = [math]::Round($os.FreePhysicalMemory / 1024, 0)
    $usedMb  = $totalMb - $freeMb
    $pctUsed = if ($totalMb -gt 0) { [math]::Round(($usedMb / $totalMb) * 100, 1) } else { 0 }

    $uptime = (Get-Date) - $os.LastBootUpTime
    $uptimeStr = "{0}d {1}h {2}m {3}s" -f $uptime.Days, $uptime.Hours, $uptime.Minutes, $uptime.Seconds

    $procCount = (Get-Process).Count
    $threads = (Get-Process | Measure-Object -Property Threads -Sum).Sum

    $ramColor = if ($pctUsed -lt 50) { "Green" } elseif ($pctUsed -lt 80) { "Yellow" } else { "Red" }

    Write-Host "  System Resource Usage:" -ForegroundColor Yellow
    Write-Host -NoNewline "    • Physical Memory (RAM):     "
    Write-Host "$usedMb MB / $totalMb MB ($pctUsed% used)" -ForegroundColor $ramColor
    Write-Host "    • Free Memory:               $freeMb MB"
    Write-Host "    • Running Processes:         $procCount"
    Write-Host "    • Active System Threads:     $threads"
    Write-Host "    • System Uptime:             $uptimeStr"
    Write-Host ""
}

function Main-Menu {
    while ($true) {
        Write-Header
        Show-Stats

        Write-Host "  Actions:" -ForegroundColor Cyan
        Write-Host "    1) Run Deep Memory Optimization & Service Pruning (Optimize-System.ps1)"
        Write-Host "    2) Refresh Performance Statistics"
        Write-Host "    3) Return to Server Control Center"
        Write-Host ""

        $choice = Read-Host "  Enter selection (1-3)"
        if ($null -eq $choice) { return }
        switch ($choice) {
            "1" {
                $optScript = "C:\Provisioning\scripts\Optimize-System.ps1"
                if (Test-Path $optScript) {
                    Write-Host "`n  Executing Optimize-System.ps1..." -ForegroundColor Cyan
                    & $optScript
                    Write-Host "`n  Optimization complete. Press Enter to continue..."
                    Read-Host
                } else {
                    Write-Host "`n  Script not found at $optScript" -ForegroundColor Red
                    Start-Sleep -Seconds 2
                }
            }
            "2" {
                # Just loop and refresh
            }
            "3" { return }
            default { Start-Sleep -Milliseconds 300 }
        }
    }
}

Main-Menu
