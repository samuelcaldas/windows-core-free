<#
.SYNOPSIS
    sconfig Module: Desktop Shell & File Manager Selector.
.DESCRIPTION
    Configures and switches between WinXShell, ReactShell, WinFile, Explorer++, and Terminal.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'SilentlyContinue'

function Write-Header {
    Clear-Host
    Write-Host "============================================================================" -ForegroundColor Cyan
    Write-Host "              Desktop Shell & File Manager Selector                         " -ForegroundColor White
    Write-Host "============================================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Get-CurrentShell {
    $userShell = (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "Shell" -ErrorAction SilentlyContinue).Shell
    $systemShell = (Get-ItemProperty -Path "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "Shell" -ErrorAction SilentlyContinue).Shell

    if ($userShell) { return $userShell }
    if ($systemShell) { return $systemShell }
    return "cmd.exe"
}

function Set-Shell {
    param([string]$ShellPath, [string]$DisplayName)
    Write-Host "`n  Setting default shell to: $DisplayName ($ShellPath)..." -ForegroundColor Cyan

    # Set both HKLM and HKCU Winlogon Shell
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "Shell" -Value $ShellPath -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "Shell" -Value $ShellPath -Force -ErrorAction SilentlyContinue

    Write-Host "  [SUCCESS] Default shell updated. Changes apply on next logon/restart." -ForegroundColor Green
    Start-Sleep -Seconds 2
}

function Main-Menu {
    while ($true) {
        Write-Header
        $currentShell = Get-CurrentShell
        Write-Host "  Current Active Shell: " -ForegroundColor Yellow -NoNewline
        Write-Host "$currentShell" -ForegroundColor White
        Write-Host ""

        Write-Host "  Available Shell Providers:" -ForegroundColor Cyan
        Write-Host "    1) WinXShell (Default - Modern Lightweight Desktop, Taskbar, Start Menu)"
        Write-Host "    2) ReactShell (Classic Win32 Desktop Shell & Taskbar)"
        Write-Host "    3) Windows Terminal (WezTerm / wt.exe Engine)"
        Write-Host "    4) PowerShell 7 Core Console (pwsh.exe)"
        Write-Host "    5) Windows Command Prompt (cmd.exe)"
        Write-Host ""
        Write-Host "  Standalone Launchers (Direct Open):" -ForegroundColor Cyan
        Write-Host "    6) Launch WinFile (Microsoft Windows File Manager)"
        Write-Host "    7) Launch Explorer++ (Tabbed Portable File Explorer)"
        Write-Host "    8) Launch WinXShell (Start Menu & Desktop)"
        Write-Host ""
        Write-Host "    9) Return to Server Control Center"
        Write-Host ""

        $choice = Read-Host "  Enter selection (1-9)"
        if ($null -eq $choice) { return }
        switch ($choice) {
            "1" { Set-Shell -ShellPath "C:\Program Files\WinXShell\WinXShell.exe -winx" -DisplayName "WinXShell Desktop" }
            "2" { Set-Shell -ShellPath "C:\Program Files\ReactShell\explorer.exe" -DisplayName "ReactShell" }
            "3" { Set-Shell -ShellPath "C:\Program Files\WindowsTerminal\wt.exe" -DisplayName "Windows Terminal" }
            "4" { Set-Shell -ShellPath "C:\Program Files\PowerShell\7\pwsh.exe" -DisplayName "PowerShell 7" }
            "5" { Set-Shell -ShellPath "cmd.exe" -DisplayName "Command Prompt" }
            "6" {
                Write-Host "`n  Launching WinFile..." -ForegroundColor Cyan
                Start-Process "C:\Program Files\WinFile\Winfile.exe" -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 1
            }
            "7" {
                Write-Host "`n  Launching Explorer++..." -ForegroundColor Cyan
                Start-Process "C:\Program Files\Explorer++\Explorer++.exe" -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 1
            }
            "8" {
                Write-Host "`n  Launching WinXShell..." -ForegroundColor Cyan
                Start-Process "C:\Program Files\WinXShell\WinXShell.exe" -ArgumentList "-winx" -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 1
            }
            "9" { return }
            default { Start-Sleep -Milliseconds 300 }
        }
    }
}

Main-Menu
