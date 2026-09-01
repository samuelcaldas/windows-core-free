<#
.SYNOPSIS
    sconfig Module: Developer Toolchains & Distro App Store (OmniGet).
.DESCRIPTION
    Audits installed toolchains and provides an interactive launcher for OmniGet (og).
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'SilentlyContinue'

function Write-Header {
    Clear-Host
    Write-Host "============================================================================" -ForegroundColor Cyan
    Write-Host "         Developer Toolchains & Universal App Store (OmniGet)               " -ForegroundColor White
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
    $teaVer    = try { (& tea.exe --version 2>$null | Select-Object -First 1).Trim() } catch { "Not Installed" }
    $dockerVer = try { (& docker.exe --version 2>$null | Select-Object -First 1).Trim() } catch { "Not Installed" }
    $omniVer   = try { (& og.cmd -Version 2>$null | Select-Object -First 1).Trim() } catch { "Not Installed" }

    if (-not $dotnetVer) { $dotnetVer = "Not Installed" }
    if (-not $pwshVer)   { $pwshVer = "Not Installed" }
    if (-not $pyVer)     { $pyVer = "Not Installed" }
    if (-not $nodeVer)   { $nodeVer = "Not Installed" }
    if (-not $gitVer)    { $gitVer = "Not Installed" }
    if (-not $ghVer)     { $ghVer = "Not Installed" }
    if (-not $teaVer)    { $teaVer = "Not Installed" }
    if (-not $dockerVer) { $dockerVer = "Not Installed" }
    if (-not $omniVer)   { $omniVer = "Not Installed" }

    $agyService = Get-ScheduledTask -TaskName "AntigravityRemoteDaemon" -ErrorAction SilentlyContinue
    $agyStatus = if ($agyService) { "Registered (Scheduled Task at Boot)" } else { "Not Configured" }

    Write-Host "  Installed Runtimes & Toolchains:" -ForegroundColor Yellow
    Write-Host "    • OmniGet (og CLI):     $omniVer"
    Write-Host "    • .NET SDK:             $dotnetVer"
    Write-Host "    • PowerShell Core:      $pwshVer"
    Write-Host "    • Python:               $pyVer"
    Write-Host "    • Node.js:              $nodeVer"
    Write-Host "    • Git for Windows:      $gitVer"
    Write-Host "    • GitHub CLI (gh):      $ghVer"
    Write-Host "    • Gitea CLI (tea):      $teaVer"
    Write-Host "    • Docker CLI:           $dockerVer"
    Write-Host "    • Antigravity Daemon:   $agyStatus"
    Write-Host ""
}

function Main-Menu {
    while ($true) {
        Write-Header
        Show-Status

        Write-Host "  Actions:" -ForegroundColor Cyan
        Write-Host "    1) Launch Interactive Universal App Store (OmniGet TUI)"
        Write-Host "    2) Run Developer Toolchain Preset (og preset DevStack)"
        Write-Host "    3) Search Packages (og search)"
        Write-Host "    4) Return to Server Control Center"
        Write-Host ""

        $choice = Read-Host "  Enter selection (1-4)"
        if ($null -eq $choice) { return }

        switch ($choice) {
            "1" {
                $omniScript = "C:\Program Files\OmniGet\src\OmniGet.ps1"
                if (Test-Path $omniScript) {
                    & pwsh.exe -ExecutionPolicy Bypass -File $omniScript
                } elseif (Get-Command og.cmd -ErrorAction SilentlyContinue) {
                    & og.cmd
                } else {
                    $installScript = "C:\Provisioning\scripts\Install-OmniGet.ps1"
                    if (Test-Path $installScript) { & $installScript -Interactive }
                }
            }
            "2" {
                $omniScript = "C:\Program Files\OmniGet\src\OmniGet.ps1"
                if (Test-Path $omniScript) {
                    & pwsh.exe -ExecutionPolicy Bypass -File $omniScript -Preset DevStack -Silent
                    Write-Host "`n  Press Enter to continue..."
                    Read-Host
                }
            }
            "3" {
                $query = Read-Host "  Enter search query"
                if ($query) {
                    $omniScript = "C:\Program Files\OmniGet\src\OmniGet.ps1"
                    if (Test-Path $omniScript) {
                        & pwsh.exe -ExecutionPolicy Bypass -File $omniScript -Search $query
                        Write-Host "`n  Press Enter to continue..."
                        Read-Host
                    }
                }
            }
            "4" { return }
            default { return }
        }
    }
}

Main-Menu
