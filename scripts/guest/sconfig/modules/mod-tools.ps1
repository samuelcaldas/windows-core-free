<#
.SYNOPSIS
    sconfig Module: Developer Toolchains & Distro App Store.
.DESCRIPTION
    Audits installed toolchains and provides an interactive launcher for the Ninite App Store.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'SilentlyContinue'

function Write-Header {
    Clear-Host
    Write-Host "============================================================================" -ForegroundColor Cyan
    Write-Host "              Developer Toolchains & Distro App Store                       " -ForegroundColor White
    Write-Host "============================================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Show-Status {
    $dotnetVer = try { (& dotnet.exe --version 2>$null | Select-Object -First 1).Trim() } catch { "Not Installed" }
    $pwshVer   = try { (& pwsh.exe --version 2>$null | Select-Object -First 1).Trim() } catch { "Not Installed" }
    $pyVer     = try { (& python.exe --version 2>$null | Select-Object -First 1).Trim() } catch { "Not Installed" }
    $nodeVer   = try { (& node.exe -v 2>$null | Select-Object -First 1).Trim() } catch { "Not Installed" }
    $gitVer    = try { (& git.exe --version 2>$null | Select-Object -First 1).Trim() } catch { "Not Installed" }
    $ghVer     = try { (& gh.exe --version 2>$null | Select-Object -First 1).Trim() } catch { "Not Installed" }
    $dockerVer = try { (& docker.exe --version 2>$null | Select-Object -First 1).Trim() } catch { "Not Installed" }

    if (-not $dotnetVer) { $dotnetVer = "Not Installed" }
    if (-not $pwshVer)   { $pwshVer = "Not Installed" }
    if (-not $pyVer)     { $pyVer = "Not Installed" }
    if (-not $nodeVer)   { $nodeVer = "Not Installed" }
    if (-not $gitVer)    { $gitVer = "Not Installed" }
    if (-not $ghVer)     { $ghVer = "Not Installed" }
    if (-not $dockerVer) { $dockerVer = "Not Installed" }

    $agyService = Get-ScheduledTask -TaskName "Antigravity Daemon" -ErrorAction SilentlyContinue
    $agyStatus = if ($agyService) { "Registered (Scheduled Task at Boot)" } else { "Not Configured" }

    Write-Host "  Installed Runtimes & Toolchains:" -ForegroundColor Yellow
    Write-Host "    • .NET SDK:             $dotnetVer"
    Write-Host "    • PowerShell Core:      $pwshVer"
    Write-Host "    • Python:               $pyVer"
    Write-Host "    • Node.js:              $nodeVer"
    Write-Host "    • Git for Windows:      $gitVer"
    Write-Host "    • GitHub CLI (gh):      $ghVer"
    Write-Host "    • Docker CLI:           $dockerVer"
    Write-Host "    • Antigravity Daemon:   $agyStatus"
    Write-Host ""
}

function Main-Menu {
    while ($true) {
        Write-Header
        Show-Status

        Write-Host "  Actions:" -ForegroundColor Cyan
        Write-Host "    1) Launch Interactive Ninite App Store (TUI)"
        Write-Host "    2) Re-run Toolchain Setup / Updater (Install-Tools.ps1)"
        Write-Host "    3) Return to Server Control Center"
        Write-Host ""

        $choice = Read-Host "  Enter selection (1-3)"
        if ($null -eq $choice) { return }

        switch ($choice) {
            "1" {
                $niniteScript = "C:\Provisioning\scripts\Install-NiniteApps.ps1"
                if (Test-Path $niniteScript) {
                    & $niniteScript
                } else {
                    Write-Host "`n  Ninite script not found at $niniteScript" -ForegroundColor Red
                    Start-Sleep -Seconds 2
                }
            }
            "2" {
                $toolsScript = "C:\Provisioning\scripts\Install-Tools.ps1"
                if (Test-Path $toolsScript) {
                    & $toolsScript
                    Write-Host "`n  Press Enter to continue..."
                    Read-Host
                } else {
                    Write-Host "`n  Toolchain script not found at $toolsScript" -ForegroundColor Red
                    Start-Sleep -Seconds 2
                }
            }
            "3" { return }
            default { return }
        }
    }
}

Main-Menu
