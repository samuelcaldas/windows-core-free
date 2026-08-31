<#
.SYNOPSIS
    sconfig Module: OpenSSH Server & Remote Access Dashboard.
.DESCRIPTION
    Provides an interactive terminal dashboard to manage OpenSSH, WinRM, and Remote Desktop (RDP).
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'SilentlyContinue'

function Write-Header {
    Clear-Host
    Write-Host "============================================================================" -ForegroundColor Cyan
    Write-Host "              OpenSSH Server & Remote Access Dashboard                      " -ForegroundColor White
    Write-Host "============================================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Show-Status {
    $sshService = Get-Service -Name "sshd" -ErrorAction SilentlyContinue
    $sshStatus = if ($sshService -and $sshService.Status -eq 'Running') { "[RUNNING]" } else { "[STOPPED]" }
    $sshColor = if ($sshService -and $sshService.Status -eq 'Running') { "Green" } else { "Red" }

    $rdpReg = (Get-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -ErrorAction SilentlyContinue).fDenyTSConnections
    $rdpStatus = if ($rdpReg -eq 0) { "[ENABLED]" } else { "[DISABLED]" }
    $rdpColor = if ($rdpReg -eq 0) { "Green" } else { "Yellow" }

    $winrmService = Get-Service -Name "WinRM" -ErrorAction SilentlyContinue
    $winrmStatus = if ($winrmService -and $winrmService.Status -eq 'Running') { "[RUNNING]" } else { "[STOPPED]" }
    $winrmColor = if ($winrmService -and $winrmService.Status -eq 'Running') { "Green" } else { "Yellow" }

    $adminKeys = "C:\ProgramData\ssh\administrators_authorized_keys"
    $keyCount = 0
    if (Test-Path $adminKeys) {
        $keyCount = (Get-Content $adminKeys | Where-Object { $_.Trim() -and -not $_.StartsWith('#') }).Count
    }

    Write-Host "  Service Status:" -ForegroundColor Yellow
    Write-Host -NoNewline "    • OpenSSH Server (sshd):     "
    Write-Host "$sshStatus" -ForegroundColor $sshColor
    Write-Host -NoNewline "    • Remote Desktop (RDP):      "
    Write-Host "$rdpStatus" -ForegroundColor $rdpColor
    Write-Host -NoNewline "    • PowerShell Remoting/WinRM: "
    Write-Host "$winrmStatus" -ForegroundColor $winrmColor
    Write-Host ""

    Write-Host "  Configuration & Keys:" -ForegroundColor Yellow
    Write-Host "    • SSH Port:                  22 (Forwarded from Host 2222)"
    Write-Host "    • Default SSH Shell:         C:\Program Files\PowerShell\7\pwsh.exe"
    Write-Host "    • Admin Authorized Keys:     $keyCount key(s) registered"
    Write-Host "    • Keys File:                 $adminKeys"
    Write-Host ""
}

function Main-Menu {
    while ($true) {
        Write-Header
        Show-Status

        Write-Host "  Actions:" -ForegroundColor Cyan
        Write-Host "    1) Restart OpenSSH Server Service"
        Write-Host "    2) View Registered Authorized SSH Keys"
        Write-Host "    3) Toggle Remote Desktop (RDP)"
        Write-Host "    4) Restart WinRM Service"
        Write-Host "    5) Return to Server Control Center"
        Write-Host ""

        $choice = Read-Host "  Enter selection (1-5)"
        if ($null -eq $choice) { return }
        switch ($choice) {
            "1" {
                Write-Host "`n  Restarting sshd service..." -ForegroundColor Cyan
                Restart-Service -Name "sshd" -Force -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 1
            }
            "2" {
                $adminKeys = "C:\ProgramData\ssh\administrators_authorized_keys"
                Write-Host "`n  === Authorized Public Keys ===" -ForegroundColor Cyan
                if (Test-Path $adminKeys) {
                    Get-Content $adminKeys | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
                } else {
                    Write-Host "    No keys file found at $adminKeys" -ForegroundColor Yellow
                }
                Write-Host ""
                Read-Host "  Press Enter to continue"
            }
            "3" {
                $rdpReg = (Get-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -ErrorAction SilentlyContinue).fDenyTSConnections
                $newVal = if ($rdpReg -eq 0) { 1 } else { 0 }
                Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value $newVal -Force
                $action = if ($newVal -eq 0) { "Enabled" } else { "Disabled" }
                Write-Host "`n  Remote Desktop is now $action." -ForegroundColor Green
                Start-Sleep -Seconds 1
            }
            "4" {
                Write-Host "`n  Restarting WinRM service..." -ForegroundColor Cyan
                Restart-Service -Name "WinRM" -Force -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 1
            }
            "5" { return }
            default { Start-Sleep -Milliseconds 300 }
        }
    }
}

Main-Menu
