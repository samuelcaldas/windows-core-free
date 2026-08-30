<#
.SYNOPSIS
    Guest Script: WinXShell Desktop Environment & Explorer++ Installation.
.DESCRIPTION
    Non-destructive installation on Windows Server Core:
    - Installs WinXShell as the primary logon shell with taskbar, start menu, system tray, and wallpaper.
    - Installs Explorer++ tabbed file manager.
    - Disables auto-startup of cmd.exe / sconfig.cmd on logon.
    - Creates desktop shortcuts for Command Prompt, PowerShell 7, Explorer++, sconfig, and Claude CLI.
#>
[CmdletBinding()]
param(
    [string]$SourceDir = "C:\Provisioning\packages"
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Write-Step { param([string]$Msg) Write-Host "[INFO] $Msg" -ForegroundColor Cyan }
function Write-Success { param([string]$Msg) Write-Host "[SUCCESS] $Msg" -ForegroundColor Green }
function Write-WarnMsg { param([string]$Msg) Write-Host "[WARN] $Msg" -ForegroundColor Yellow }

function Create-DesktopShortcut {
    param(
        [string]$ShortcutPath,
        [string]$TargetPath,
        [string]$Arguments = "",
        [string]$WorkingDirectory = "",
        [string]$IconLocation = "",
        [string]$Description = ""
    )

    try {
        $dir = Split-Path -Path $ShortcutPath -Parent
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }

        $wshShell = New-Object -ComObject WScript.Shell
        $shortcut = $wshShell.CreateShortcut($ShortcutPath)
        $shortcut.TargetPath = $TargetPath
        if ($Arguments) { $shortcut.Arguments = $Arguments }
        if ($WorkingDirectory) {
            $shortcut.WorkingDirectory = $WorkingDirectory
        }
        else {
            $shortcut.WorkingDirectory = Split-Path -Path $TargetPath -Parent
        }
        if ($IconLocation) { $shortcut.IconLocation = $IconLocation }
        if ($Description) { $shortcut.Description = $Description }
        $shortcut.Save()
        Write-Success "Created shortcut: $(Split-Path $ShortcutPath -Leaf)"
    }
    catch {
        Write-WarnMsg "Failed to create shortcut $ShortcutPath : $_"
    }
}

function Install-ExplorerPlusPlus {
    Write-Step "Installing Explorer++ tabbed file manager..."
    $targetDir = "C:\Program Files\Explorer++"
    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }

    $zipFile = Join-Path $SourceDir "explorerpp_x64.zip"
    if (-not (Test-Path $zipFile)) {
        # Check attached drive letters
        foreach ($letter in 'DEFGHIJKLMNOPQRSTUVWXYZ'.ToCharArray()) {
            $cand = "${letter}:\explorerpp_x64.zip"
            if (Test-Path $cand) { $zipFile = $cand; break }
            $cand = "${letter}:\packages\explorerpp_x64.zip"
            if (Test-Path $cand) { $zipFile = $cand; break }
        }
    }

    if (Test-Path $zipFile) {
        Write-Step "Extracting Explorer++ from $zipFile..."
        Expand-Archive -Path $zipFile -DestinationPath $targetDir -Force
        Write-Success "Explorer++ installed to $targetDir."
    }
    elseif (-not (Test-Path "$targetDir\Explorer++.exe")) {
        Write-Step "Downloading Explorer++ 64-bit..."
        $url = "https://github.com/derceg/explorerplusplus/releases/download/version-1.4.0/explorerpp_x64.zip"
        $tempZip = "$env:TEMP\explorerpp_x64.zip"
        $curl = "$env:WINDIR\System32\curl.exe"
        if (Test-Path $curl) {
            & $curl -fSL "$url" -o "$tempZip"
        }
        else {
            (New-Object System.Net.WebClient).DownloadFile($url, $tempZip)
        }
        Expand-Archive -Path $tempZip -DestinationPath $targetDir -Force
        Write-Success "Explorer++ downloaded and installed to $targetDir."
    }

    # Add to Machine PATH
    $currPath = [System.Environment]::GetEnvironmentVariable('Path', [System.EnvironmentVariableTarget]::Machine)
    if ($currPath -notlike "*$targetDir*") {
        [System.Environment]::SetEnvironmentVariable('Path', "$targetDir;$currPath", [System.EnvironmentVariableTarget]::Machine)
        $env:Path = "$targetDir;$env:Path"
    }
}

function Install-WinXShell {
    Write-Step "Installing WinXShell desktop environment..."
    $targetDir = "C:\Program Files\WinXShell"
    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }

    $zipFile = Join-Path $SourceDir "winxshell_x64.zip"
    if (-not (Test-Path $zipFile)) {
        # Check attached drive letters
        foreach ($letter in 'DEFGHIJKLMNOPQRSTUVWXYZ'.ToCharArray()) {
            $cand = "${letter}:\winxshell_x64.zip"
            if (Test-Path $cand) { $zipFile = $cand; break }
            $cand = "${letter}:\packages\winxshell_x64.zip"
            if (Test-Path $cand) { $zipFile = $cand; break }
        }
    }

    if (Test-Path $zipFile) {
        Write-Step "Extracting WinXShell from $zipFile..."
        Expand-Archive -Path $zipFile -DestinationPath $targetDir -Force
        Write-Success "WinXShell installed to $targetDir."
    }

    $exePath = "$targetDir\WinXShell.exe"
    if (-not (Test-Path $exePath)) {
        if (Test-Path "$targetDir\WinXShell_x64.exe") {
            Copy-Item -Path "$targetDir\WinXShell_x64.exe" -Destination $exePath -Force
        }
    }

    # Configure Winlogon Shell
    Write-Step "Setting WinXShell as the primary logon shell..."
    $winlogonKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
    Set-ItemProperty -Path $winlogonKey -Name "Shell" -Value "$targetDir\WinXShell.exe -winpe" -Type String -Force
    Write-Success "Winlogon Shell configured: $targetDir\WinXShell.exe -winpe"

    # Remove sconfig and alternate shell auto-start cmd windows
    Write-Step "Disabling automatic cmd.exe and sconfig.cmd startup on logon..."
    $runKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
    if (Get-ItemProperty -Path $runKey -Name "sconfig" -ErrorAction SilentlyContinue) {
        Remove-ItemProperty -Path $runKey -Name "sconfig" -Force -ErrorAction SilentlyContinue
        Write-Success "Removed automatic sconfig.cmd from Run registry key."
    }

    $altShellKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\AlternateShells\AvailableShells"
    if (Test-Path $altShellKey) {
        Remove-ItemProperty -Path $altShellKey -Name "30000" -Force -ErrorAction SilentlyContinue
        Write-Success "Disabled AlternateShells cmd.exe fallback."
    }

    # Add to Machine PATH
    $currPath = [System.Environment]::GetEnvironmentVariable('Path', [System.EnvironmentVariableTarget]::Machine)
    if ($currPath -notlike "*$targetDir*") {
        [System.Environment]::SetEnvironmentVariable('Path', "$targetDir;$currPath", [System.EnvironmentVariableTarget]::Machine)
        $env:Path = "$targetDir;$env:Path"
    }
}

function Deploy-DesktopShortcuts {
    Write-Step "Creating desktop shortcuts for user and public profiles..."
    $desktopDirs = @(
        "C:\Users\Public\Desktop",
        "C:\Users\samuelcaldas\Desktop",
        "C:\Users\Administrator\Desktop"
    )

    $cmdExe   = "$env:WINDIR\System32\cmd.exe"
    $pwsh7Exe = "C:\Program Files\PowerShell\7\pwsh.exe"
    $expExe   = "C:\Program Files\Explorer++\Explorer++.exe"
    $sconfig  = "$env:WINDIR\System32\sconfig.cmd"

    foreach ($dir in $desktopDirs) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }

        # 1. Command Prompt
        Create-DesktopShortcut `
            -ShortcutPath "$dir\Command Prompt.lnk" `
            -TargetPath $cmdExe `
            -WorkingDirectory "$env:SystemDrive\Users\samuelcaldas" `
            -Description "Windows Command Prompt"

        # 2. PowerShell 7
        if (Test-Path $pwsh7Exe) {
            Create-DesktopShortcut `
                -ShortcutPath "$dir\PowerShell 7.lnk" `
                -TargetPath $pwsh7Exe `
                -WorkingDirectory "$env:SystemDrive\Users\samuelcaldas" `
                -Description "PowerShell 7 (pwsh)"
        }
        else {
            Create-DesktopShortcut `
                -ShortcutPath "$dir\Windows PowerShell.lnk" `
                -TargetPath "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" `
                -WorkingDirectory "$env:SystemDrive\Users\samuelcaldas" `
                -Description "Windows PowerShell"
        }

        # 3. Explorer++
        if (Test-Path $expExe) {
            Create-DesktopShortcut `
                -ShortcutPath "$dir\Explorer++.lnk" `
                -TargetPath $expExe `
                -WorkingDirectory "C:\Program Files\Explorer++" `
                -Description "Explorer++ File Manager"
        }

        # 4. Server Configuration (sconfig)
        if (Test-Path $sconfig) {
            Create-DesktopShortcut `
                -ShortcutPath "$dir\Server Configuration (sconfig).lnk" `
                -TargetPath $cmdExe `
                -Arguments "/k `"$sconfig`"" `
                -Description "Windows Server Configuration Utility"
        }

        # 5. Claude Code CLI
        $claudeTarget = if (Test-Path $pwsh7Exe) { $pwsh7Exe } else { $cmdExe }
        $claudeArgs   = if (Test-Path $pwsh7Exe) { "-NoExit -Command `"claude`"" } else { "/k claude" }
        Create-DesktopShortcut `
            -ShortcutPath "$dir\Claude Code CLI.lnk" `
            -TargetPath $claudeTarget `
            -Arguments $claudeArgs `
            -WorkingDirectory "$env:SystemDrive\Users\samuelcaldas" `
            -Description "Anthropic Claude Code CLI"
    }

    Write-Success "Desktop shortcuts deployed successfully."
}

function Main {
    Write-Host "=============================================================================="
    Write-Host "  Windows Core Guest - Desktop Shell (WinXShell & Explorer++) Installer"
    Write-Host "=============================================================================="
    Install-ExplorerPlusPlus
    Install-WinXShell
    Deploy-DesktopShortcuts
    Write-Success "WinXShell and Explorer++ desktop setup completed successfully."
}

Main
