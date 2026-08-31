<#
.SYNOPSIS
    Guest Script: ReactShell Desktop Environment & File Manager Installation.
.DESCRIPTION
    Non-destructive installation on Windows Server Core:
    - Installs ReactShell (react-shell.exe) as the default primary logon shell with taskbar, start menu, system tray, and wallpaper.
    - Installs ReactFM (react-fm.exe) as the default standalone file manager and links C:\Windows\explorer.exe.
    - Preserves WinXShell and Explorer++ as optional alternative providers.
    - Disables auto-startup of cmd.exe / sconfig.cmd on logon.
    - Creates desktop shortcuts for File Explorer, Command Prompt, PowerShell 7, sconfig, and Claude CLI.
#>
[CmdletBinding()]
param(
    [string]$SourceDir = "C:\Provisioning\packages",
    [ValidateSet('ReactShell', 'WinXShell', 'None')][string]$ShellProvider = 'ReactShell',
    [ValidateSet('ReactFM', 'ExplorerPlusPlus', 'None')][string]$FileManager = 'ReactFM'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Write-Step { param([string]$Msg) Write-Host "[INFO] $Msg" -ForegroundColor Cyan }
function Write-Success { param([string]$Msg) Write-Host "[SUCCESS] $Msg" -ForegroundColor Green }
function Write-WarnMsg { param([string]$Msg) Write-Host "[WARN] $Msg" -ForegroundColor Yellow }
function Write-ErrMsg { param([string]$Msg) Write-Host "[ERROR] $Msg" -ForegroundColor Red }

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

function Install-ReactFileManager {
    Write-Step "Installing ReactShell File Manager (react-fm.exe)..."
    $targetDir = "C:\Program Files\ReactShell"
    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }

    $fmExe = "$targetDir\react-fm.exe"
    if (-not (Test-Path $fmExe)) {
        $zipFile = Join-Path $SourceDir "reactshell_x64.zip"
        if (-not (Test-Path $zipFile)) {
            foreach ($letter in 'DEFGHIJKLMNOPQRSTUVWXYZ'.ToCharArray()) {
                $cand = "${letter}:\reactshell_x64.zip"
                if (Test-Path $cand) { $zipFile = $cand; break }
                $cand = "${letter}:\packages\reactshell_x64.zip"
                if (Test-Path $cand) { $zipFile = $cand; break }
            }
        }

        if (Test-Path $zipFile) {
            Write-Step "Extracting ReactShell FM from $zipFile..."
            Expand-Archive -Path $zipFile -DestinationPath $targetDir -Force
            Write-Success "ReactShell FM extracted to $targetDir."
        }
        else {
            Write-WarnMsg "ReactShell archive not found in packages."
            return
        }
    }
    else {
        Write-Success "ReactShell FM is already installed in $targetDir."
    }

    # Link C:\Windows\explorer.exe to react-fm.exe
    $winExplorer = "$env:WINDIR\explorer.exe"
    try {
        if (Test-Path $winExplorer) {
            Remove-Item $winExplorer -Force -ErrorAction SilentlyContinue
        }
        New-Item -ItemType HardLink -Path $winExplorer -Target $fmExe -Force | Out-Null
        Write-Success "Linked $winExplorer to $fmExe (HardLink)."
    }
    catch {
        Write-WarnMsg "HardLink failed, attempting copy fallback: $_"
        Copy-Item -Path $fmExe -Destination $winExplorer -Force
        Write-Success "Copied react-fm.exe to $winExplorer."
    }

    # Register ReactFM as default system file manager in Registry
    Write-Step "Registering ReactFM as default system file explorer in Registry..."
    $classesBase = "HKLM:\SOFTWARE\Classes"
    $regAssociations = @(
        "$classesBase\Folder\shell\open\command",
        "$classesBase\Directory\shell\open\command",
        "$classesBase\Drive\shell\open\command"
    )
    foreach ($regKey in $regAssociations) {
        if (-not (Test-Path $regKey)) {
            New-Item -Path $regKey -Force | Out-Null
        }
        Set-ItemProperty -Path $regKey -Name "(Default)" -Value "`"$fmExe`" `"%1`"" -Force
    }
    Write-Success "ReactFM registered as default file manager in registry."

    # Add to Machine PATH
    $currPath = [System.Environment]::GetEnvironmentVariable('Path', [System.EnvironmentVariableTarget]::Machine)
    if ($currPath -notlike "*$targetDir*") {
        [System.Environment]::SetEnvironmentVariable('Path', "$targetDir;$currPath", [System.EnvironmentVariableTarget]::Machine)
        $env:Path = "$targetDir;$env:Path"
    }
}

function Install-ReactShell {
    Write-Step "Installing ReactShell desktop shell (react-shell.exe)..."
    $targetDir = "C:\Program Files\ReactShell"
    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }

    $shellExe = "$targetDir\react-shell.exe"
    if (-not (Test-Path $shellExe)) {
        $zipFile = Join-Path $SourceDir "reactshell_x64.zip"
        if (-not (Test-Path $zipFile)) {
            foreach ($letter in 'DEFGHIJKLMNOPQRSTUVWXYZ'.ToCharArray()) {
                $cand = "${letter}:\reactshell_x64.zip"
                if (Test-Path $cand) { $zipFile = $cand; break }
                $cand = "${letter}:\packages\reactshell_x64.zip"
                if (Test-Path $cand) { $zipFile = $cand; break }
            }
        }

        if (Test-Path $zipFile) {
            Write-Step "Extracting ReactShell from $zipFile..."
            Expand-Archive -Path $zipFile -DestinationPath $targetDir -Force
            Write-Success "ReactShell extracted to $targetDir."
        }
        else {
            Write-WarnMsg "ReactShell archive not found in packages or attached drives."
            return
        }
    }
    else {
        Write-Success "ReactShell is already installed in $targetDir."
    }

    # Configure Winlogon Shell
    Write-Step "Setting ReactShell as the primary logon shell..."
    $winlogonKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
    Set-ItemProperty -Path $winlogonKey -Name "Shell" -Value "$shellExe" -Type String -Force
    Write-Success "Winlogon Shell configured: $shellExe"

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

function Install-ExplorerPlusPlus {
    Write-Step "Installing Explorer++ tabbed file manager (optional)..."
    $targetDir = "C:\Program Files\Explorer++"
    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }

    if (-not (Test-Path "$targetDir\Explorer++.exe")) {
        $zipFile = Join-Path $SourceDir "explorerpp_x64.zip"
        if (-not (Test-Path $zipFile)) {
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
    }
    else {
        Write-Success "Explorer++ is already installed in $targetDir."
    }

    # Deploy pre-configured portable config.xml
    $configSrc = Join-Path $SourceDir "config.xml"
    if (-not (Test-Path $configSrc)) {
        foreach ($letter in 'DEFGHIJKLMNOPQRSTUVWXYZ'.ToCharArray()) {
            $cand = "${letter}:\packages\config.xml"
            if (Test-Path $cand) { $configSrc = $cand; break }
            $cand = "${letter}:\config.xml"
            if (Test-Path $cand) { $configSrc = $cand; break }
        }
    }
    if (Test-Path $configSrc) {
        Copy-Item -Path $configSrc -Destination "$targetDir\config.xml" -Force
        Write-Success "Deployed pre-configured Explorer++ portable config.xml."
    }

    # Link C:\Windows\explorer.exe to Explorer++.exe
    $winExplorer = "$env:WINDIR\explorer.exe"
    try {
        if (Test-Path $winExplorer) {
            Remove-Item $winExplorer -Force -ErrorAction SilentlyContinue
        }
        New-Item -ItemType HardLink -Path $winExplorer -Target "$targetDir\Explorer++.exe" -Force | Out-Null
        Write-Success "Linked $winExplorer to $targetDir\Explorer++.exe (HardLink)."
    }
    catch {
        Write-WarnMsg "HardLink failed, attempting copy fallback: $_"
        Copy-Item -Path "$targetDir\Explorer++.exe" -Destination $winExplorer -Force
        Write-Success "Copied Explorer++.exe to $winExplorer."
    }

    # Register Explorer++ as default system file manager in Registry
    Write-Step "Registering Explorer++ as default system file explorer..."
    $classesBase = "HKLM:\SOFTWARE\Classes"
    $regAssociations = @(
        "$classesBase\Folder\shell\open\command",
        "$classesBase\Directory\shell\open\command",
        "$classesBase\Drive\shell\open\command"
    )
    foreach ($regKey in $regAssociations) {
        if (-not (Test-Path $regKey)) {
            New-Item -Path $regKey -Force | Out-Null
        }
        Set-ItemProperty -Path $regKey -Name "(Default)" -Value "`"$targetDir\Explorer++.exe`" `"%1`"" -Force
    }
    Write-Success "Explorer++ registered as default file manager in registry."

    # Add to Machine PATH
    $currPath = [System.Environment]::GetEnvironmentVariable('Path', [System.EnvironmentVariableTarget]::Machine)
    if ($currPath -notlike "*$targetDir*") {
        [System.Environment]::SetEnvironmentVariable('Path', "$targetDir;$currPath", [System.EnvironmentVariableTarget]::Machine)
        $env:Path = "$targetDir;$env:Path"
    }
}

function Install-WinXShell {
    Write-Step "Installing WinXShell desktop environment (optional)..."
    $targetDir = "C:\Program Files\WinXShell"
    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }

    if (-not (Test-Path "$targetDir\WinXShell.exe")) {
        $zipFile = Join-Path $SourceDir "winxshell_x64.zip"
        if (-not (Test-Path $zipFile)) {
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
        elseif (-not (Test-Path "$targetDir\WinXShell.exe")) {
            Write-ErrMsg "WinXShell archive not found."
            return
        }

        $exePath = "$targetDir\WinXShell.exe"
        if (-not (Test-Path $exePath)) {
            if (Test-Path "$targetDir\WinXShell_x64.exe") {
                Copy-Item -Path "$targetDir\WinXShell_x64.exe" -Destination $exePath -Force
            }
        }
    }
    else {
        Write-Success "WinXShell is already installed in $targetDir."
    }

    # Deploy customized WinXShell.lua if provided
    $luaSrc = Join-Path $SourceDir "WinXShell.lua"
    if (-not (Test-Path $luaSrc)) {
        foreach ($letter in 'DEFGHIJKLMNOPQRSTUVWXYZ'.ToCharArray()) {
            $cand = "${letter}:\packages\WinXShell.lua"
            if (Test-Path $cand) { $luaSrc = $cand; break }
            $cand = "${letter}:\WinXShell.lua"
            if (Test-Path $cand) { $luaSrc = $cand; break }
        }
    }
    if (Test-Path $luaSrc) {
        Copy-Item -Path $luaSrc -Destination "$targetDir\WinXShell.lua" -Force
        Write-Success "Deployed customized WinXShell.lua."
    }

    # Apply Shell registry settings
    $regSrc = Join-Path $SourceDir "shell-settings.reg"
    if (-not (Test-Path $regSrc)) {
        foreach ($letter in 'DEFGHIJKLMNOPQRSTUVWXYZ'.ToCharArray()) {
            $cand = "${letter}:\packages\shell-settings.reg"
            if (Test-Path $cand) { $regSrc = $cand; break }
            $cand = "${letter}:\shell-settings.reg"
            if (Test-Path $cand) { $regSrc = $cand; break }
        }
    }
    if (Test-Path $regSrc) {
        & reg import "$regSrc"
        Write-Success "Applied customized shell and taskbar registry settings."
    }

    # Configure Winlogon Shell
    Write-Step "Setting WinXShell as the primary logon shell..."
    $winlogonKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
    Set-ItemProperty -Path $winlogonKey -Name "Shell" -Value "$targetDir\WinXShell.exe -winpe" -Type String -Force
    Write-Success "Winlogon Shell configured: $targetDir\WinXShell.exe -winpe"

    # Add to Machine PATH
    $currPath = [System.Environment]::GetEnvironmentVariable('Path', [System.EnvironmentVariableTarget]::Machine)
    if ($currPath -notlike "*$targetDir*") {
        [System.Environment]::SetEnvironmentVariable('Path', "$targetDir;$currPath", [System.EnvironmentVariableTarget]::Machine)
        $env:Path = "$targetDir;$env:Path"
    }
}

function Deploy-DesktopShortcuts {
    Write-Step "Creating desktop shortcuts in Public Desktop..."
    $publicDir = "C:\Users\Public\Desktop"
    if (-not (Test-Path $publicDir)) {
        New-Item -ItemType Directory -Path $publicDir -Force | Out-Null
    }

    # Clean up duplicate shortcuts from individual user desktop directories
    $userDirs = @(
        "C:\Users\samuelcaldas\Desktop",
        "C:\Users\Administrator\Desktop"
    )
    $shortcutNames = @(
        "Command Prompt.lnk",
        "PowerShell 7.lnk",
        "Windows PowerShell.lnk",
        "File Explorer.lnk",
        "Explorer++.lnk",
        "Server Configuration (sconfig).lnk",
        "Claude Code CLI.lnk"
    )
    foreach ($uDir in $userDirs) {
        if (Test-Path $uDir) {
            foreach ($sName in $shortcutNames) {
                $dup = Join-Path $uDir $sName
                if (Test-Path $dup) {
                    Remove-Item -Path $dup -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }

    $cmdExe      = "$env:WINDIR\System32\cmd.exe"
    $pwsh7Exe    = "C:\Program Files\PowerShell\7\pwsh.exe"
    $reactFmExe  = "C:\Program Files\ReactShell\react-fm.exe"
    $expExe      = "C:\Program Files\Explorer++\Explorer++.exe"
    $sconfig     = "$env:WINDIR\System32\sconfig.cmd"

    # 1. Command Prompt
    Create-DesktopShortcut `
        -ShortcutPath "$publicDir\Command Prompt.lnk" `
        -TargetPath $cmdExe `
        -WorkingDirectory "$env:SystemDrive\Users\samuelcaldas" `
        -Description "Windows Command Prompt"

    # 2. PowerShell 7
    if (Test-Path $pwsh7Exe) {
        Create-DesktopShortcut `
            -ShortcutPath "$publicDir\PowerShell 7.lnk" `
            -TargetPath $pwsh7Exe `
            -WorkingDirectory "$env:SystemDrive\Users\samuelcaldas" `
            -Description "PowerShell 7 (pwsh)"
    }
    else {
        Create-DesktopShortcut `
            -ShortcutPath "$publicDir\Windows PowerShell.lnk" `
            -TargetPath "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" `
            -WorkingDirectory "$env:SystemDrive\Users\samuelcaldas" `
            -Description "Windows PowerShell"
    }

    # 3. File Explorer (ReactFM or Explorer++)
    if (Test-Path $reactFmExe) {
        Create-DesktopShortcut `
            -ShortcutPath "$publicDir\File Explorer.lnk" `
            -TargetPath $reactFmExe `
            -WorkingDirectory "C:\Program Files\ReactShell" `
            -Description "ReactShell File Explorer"
    }
    elseif (Test-Path $expExe) {
        Create-DesktopShortcut `
            -ShortcutPath "$publicDir\Explorer++.lnk" `
            -TargetPath $expExe `
            -WorkingDirectory "C:\Program Files\Explorer++" `
            -Description "Explorer++ File Manager"
    }

    # 4. Server Configuration (sconfig)
    if (Test-Path $sconfig) {
        Create-DesktopShortcut `
            -ShortcutPath "$publicDir\Server Configuration (sconfig).lnk" `
            -TargetPath $cmdExe `
            -Arguments "/k `"$sconfig`"" `
            -Description "Windows Server Configuration Utility"
    }

    # 5. Claude Code CLI
    $claudeTarget = if (Test-Path $pwsh7Exe) { $pwsh7Exe } else { $cmdExe }
    $claudeArgs   = if (Test-Path $pwsh7Exe) { "-NoExit -Command `"claude`"" } else { "/k claude" }
    Create-DesktopShortcut `
        -ShortcutPath "$publicDir\Claude Code CLI.lnk" `
        -TargetPath $claudeTarget `
        -Arguments $claudeArgs `
        -WorkingDirectory "$env:SystemDrive\Users\samuelcaldas" `
        -Description "Anthropic Claude Code CLI"

    Write-Success "Desktop shortcuts deployed successfully to Public Desktop."
}

function Main {
    Write-Host "=============================================================================="
    Write-Host "  Windows Core Guest - Desktop Shell & File Explorer Installer"
    Write-Host "=============================================================================="

    # 1. File Manager Provider
    if ($FileManager -eq 'ReactFM') {
        Install-ReactFileManager
    }
    elseif ($FileManager -eq 'ExplorerPlusPlus') {
        Install-ExplorerPlusPlus
    }

    # 2. Shell Provider
    if ($ShellProvider -eq 'ReactShell') {
        Install-ReactShell
    }
    elseif ($ShellProvider -eq 'WinXShell') {
        Install-WinXShell
    }

    # 3. Desktop Shortcuts
    Deploy-DesktopShortcuts

    Write-Success "Desktop Shell ($ShellProvider) and File Manager ($FileManager) deployed successfully."
}

Main
