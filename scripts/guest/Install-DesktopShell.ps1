<#
.SYNOPSIS
    Guest Script: Desktop Environment & File Manager Installation for Windows CoreOS (WCOS).
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
    [ValidateSet('WinXShell', 'ReactShell', 'None')][string]$ShellProvider = 'WinXShell',
    [ValidateSet('WinFile', 'ReactFM', 'ExplorerPlusPlus', 'None')][string]$FileManager = 'WinFile'
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
        Write-Step "Terminating any running ReactShell processes for update..."
        Stop-Process -Name "react-shell", "react-fm", "explorer" -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 500

        Write-Step "Extracting ReactShell binaries from $zipFile..."
        Expand-Archive -Path $zipFile -DestinationPath $targetDir -Force
        Write-Success "ReactShell extracted to $targetDir."
    }
    elseif (-not (Test-Path $fmExe)) {
        Write-WarnMsg "ReactShell archive not found in packages."
        return
    }

    # 1. System-wide File Replacements (C:\Windows, System32, SysWOW64, ReactShell)
    $systemTargets = @(
        "$env:WINDIR\explorer.exe",
        "$env:WINDIR\System32\explorer.exe",
        "$targetDir\explorer.exe"
    )
    $sysWow64 = "$env:WINDIR\SysWOW64"
    if (Test-Path $sysWow64) {
        $systemTargets += "$sysWow64\explorer.exe"
    }

    foreach ($sysTarget in $systemTargets) {
        try {
            if (Test-Path $sysTarget) {
                Remove-Item $sysTarget -Force -ErrorAction SilentlyContinue
            }
            New-Item -ItemType HardLink -Path $sysTarget -Target $fmExe -Force | Out-Null
            Write-Success "Linked $sysTarget -> $fmExe (HardLink)."
        }
        catch {
            Copy-Item -Path $fmExe -Destination $sysTarget -Force
            Write-Success "Copied $fmExe -> $sysTarget."
        }
    }

    # 2. Register ReactFM as default system file manager in Registry (64-bit and WOW64)
    Write-Step "Registering ReactFM as default system file explorer in Registry..."
    $regAssociations = @(
        "HKLM:\SOFTWARE\Classes\Folder\shell\open\command",
        "HKLM:\SOFTWARE\Classes\Directory\shell\open\command",
        "HKLM:\SOFTWARE\Classes\Drive\shell\open\command",
        "HKLM:\SOFTWARE\Classes\Directory\Background\shell\open\command",
        "HKLM:\SOFTWARE\WOW6432Node\Classes\Folder\shell\open\command",
        "HKLM:\SOFTWARE\WOW6432Node\Classes\Directory\shell\open\command",
        "HKLM:\SOFTWARE\WOW6432Node\Classes\Drive\shell\open\command",
        "HKLM:\SOFTWARE\WOW6432Node\Classes\Directory\Background\shell\open\command"
    )
    foreach ($regKey in $regAssociations) {
        if (-not (Test-Path $regKey)) {
            New-Item -Path $regKey -Force | Out-Null
        }
        Set-ItemProperty -Path $regKey -Name "(Default)" -Value "`"$fmExe`" `"%1`"" -Force
    }

    # 3. Register App Paths for explorer.exe, react-fm.exe, react-shell.exe (64-bit and WOW64)
    Write-Step "Registering App Paths for explorer.exe in Registry..."
    $appPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\explorer.exe",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\explorer.exe"
    )
    foreach ($apKey in $appPaths) {
        if (-not (Test-Path $apKey)) {
            New-Item -Path $apKey -Force | Out-Null
        }
        Set-ItemProperty -Path $apKey -Name "(Default)" -Value "$env:WINDIR\explorer.exe" -Force
        Set-ItemProperty -Path $apKey -Name "Path" -Value "$targetDir;$env:WINDIR;$env:WINDIR\System32" -Force
    }

    $rsAppPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\react-fm.exe",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\react-shell.exe"
    )
    foreach ($apKey in $rsAppPaths) {
        if (-not (Test-Path $apKey)) {
            New-Item -Path $apKey -Force | Out-Null
        }
        $targetBin = if ($apKey -like "*react-fm*") { "$targetDir\react-fm.exe" } else { "$targetDir\react-shell.exe" }
        Set-ItemProperty -Path $apKey -Name "(Default)" -Value $targetBin -Force
        Set-ItemProperty -Path $apKey -Name "Path" -Value $targetDir -Force
    }
    Write-Success "ReactFM registered across system paths and registry."

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
        Write-Step "Terminating any running ReactShell processes for update..."
        Stop-Process -Name "react-shell", "react-fm" -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 500

        Write-Step "Extracting ReactShell from $zipFile..."
        Expand-Archive -Path $zipFile -DestinationPath $targetDir -Force
        Write-Success "ReactShell extracted to $targetDir."
    }
    elseif (-not (Test-Path $shellExe)) {
        Write-WarnMsg "ReactShell archive not found in packages or attached drives."
        return
    }

    # Configure Winlogon Shell (64-bit and WOW64)
    Write-Step "Setting ReactShell as the primary logon shell..."
    $winlogonKeys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows NT\CurrentVersion\Winlogon"
    )
    foreach ($wKey in $winlogonKeys) {
        if (Test-Path $wKey) {
            Set-ItemProperty -Path $wKey -Name "Shell" -Value "$shellExe" -Type String -Force
        }
    }
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

function Install-WinFile {
    Write-Step "Installing Microsoft File Manager (Winfile.exe)..."
    $targetDir = "C:\Program Files\WinFile"
    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }

    $winfileExe = "$targetDir\Winfile.exe"
    $zipFile = Join-Path $SourceDir "winfile_x64.zip"
    if (-not (Test-Path $zipFile)) {
        foreach ($letter in 'DEFGHIJKLMNOPQRSTUVWXYZ'.ToCharArray()) {
            $cand = "${letter}:\winfile_x64.zip"
            if (Test-Path $cand) { $zipFile = $cand; break }
            $cand = "${letter}:\packages\winfile_x64.zip"
            if (Test-Path $cand) { $zipFile = $cand; break }
        }
    }

    if (Test-Path $zipFile) {
        Write-Step "Extracting WinFile from $zipFile..."
        Expand-Archive -Path $zipFile -DestinationPath $targetDir -Force
        Write-Success "WinFile extracted to $targetDir."
    }
    elseif (-not (Test-Path $winfileExe)) {
        Write-WarnMsg "WinFile package not found in packages or attached drives."
        return
    }

    # 1. System-wide File Replacements (C:\Windows, System32, SysWOW64, WinFile)
    $systemTargets = @(
        "$env:WINDIR\explorer.exe",
        "$env:WINDIR\System32\explorer.exe",
        "$targetDir\explorer.exe"
    )
    $sysWow64 = "$env:WINDIR\SysWOW64"
    if (Test-Path $sysWow64) {
        $systemTargets += "$sysWow64\explorer.exe"
    }

    foreach ($sysTarget in $systemTargets) {
        try {
            if (Test-Path $sysTarget) {
                Remove-Item $sysTarget -Force -ErrorAction SilentlyContinue
            }
            New-Item -ItemType HardLink -Path $sysTarget -Target $winfileExe -Force | Out-Null
            Write-Success "Linked $sysTarget -> $winfileExe (HardLink)."
        }
        catch {
            Copy-Item -Path $winfileExe -Destination $sysTarget -Force
            Write-Success "Copied $winfileExe -> $sysTarget."
        }
    }

    # 2. Register WinFile as default system file manager in Registry (64-bit and WOW64)
    Write-Step "Registering WinFile as default file manager in Registry..."
    $regAssociations = @(
        "HKLM:\SOFTWARE\Classes\Folder\shell\open\command",
        "HKLM:\SOFTWARE\Classes\Directory\shell\open\command",
        "HKLM:\SOFTWARE\Classes\Drive\shell\open\command",
        "HKLM:\SOFTWARE\Classes\Directory\Background\shell\open\command",
        "HKLM:\SOFTWARE\WOW6432Node\Classes\Folder\shell\open\command",
        "HKLM:\SOFTWARE\WOW6432Node\Classes\Directory\shell\open\command",
        "HKLM:\SOFTWARE\WOW6432Node\Classes\Drive\shell\open\command",
        "HKLM:\SOFTWARE\WOW6432Node\Classes\Directory\Background\shell\open\command"
    )
    foreach ($regKey in $regAssociations) {
        if (-not (Test-Path $regKey)) {
            New-Item -Path $regKey -Force | Out-Null
        }
        Set-ItemProperty -Path $regKey -Name "(Default)" -Value "`"$winfileExe`" `"%1`"" -Force
    }

    # 3. Register App Paths for explorer.exe and winfile.exe (64-bit and WOW64)
    $appPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\explorer.exe",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\explorer.exe",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\winfile.exe",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\winfile.exe"
    )
    foreach ($apKey in $appPaths) {
        if (-not (Test-Path $apKey)) {
            New-Item -Path $apKey -Force | Out-Null
        }
        $targetBin = if ($apKey -like "*explorer*") { "$env:WINDIR\explorer.exe" } else { $winfileExe }
        Set-ItemProperty -Path $apKey -Name "(Default)" -Value $targetBin -Force
        Set-ItemProperty -Path $apKey -Name "Path" -Value "$targetDir;$env:WINDIR;$env:WINDIR\System32" -Force
    }
    Write-Success "WinFile registered across system paths and registry."

    # Add to Machine PATH
    $currPath = [System.Environment]::GetEnvironmentVariable('Path', [System.EnvironmentVariableTarget]::Machine)
    if ($currPath -notlike "*$targetDir*") {
        [System.Environment]::SetEnvironmentVariable('Path', "$targetDir;$currPath", [System.EnvironmentVariableTarget]::Machine)
        $env:Path = "$targetDir;$env:Path"
    }
}

function Install-WinXShell {
    Write-Step "Installing WinXShell desktop environment (default shell)..."
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

    # Configure Winlogon Shell (64-bit and WOW64)
    Write-Step "Setting WinXShell as the primary logon shell..."
    $winlogonKeys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows NT\CurrentVersion\Winlogon"
    )
    foreach ($wKey in $winlogonKeys) {
        if (Test-Path $wKey) {
            Set-ItemProperty -Path $wKey -Name "Shell" -Value "$targetDir\WinXShell.exe -winpe" -Type String -Force
        }
    }
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

function Deploy-DistroBranding {
    Write-Step "Deploying Windows Core Developer Edition branding & wallpaper..."
    $wallpaperDir = "C:\Windows\Web\Wallpaper\WindowsCore"
    if (-not (Test-Path $wallpaperDir)) {
        New-Item -ItemType Directory -Path $wallpaperDir -Force | Out-Null
    }

    # Search for wallpaper files in SourceDir or attached drives
    $wpJpg = Join-Path $SourceDir "wallpaper.jpg"
    $wpBmp = Join-Path $SourceDir "wallpaper.bmp"
    $oemBmp = Join-Path $SourceDir "oemlogo.bmp"

    if (-not (Test-Path $wpJpg)) {
        foreach ($letter in 'DEFGHIJKLMNOPQRSTUVWXYZ'.ToCharArray()) {
            $cand = "${letter}:\packages\wallpaper.jpg"
            if (Test-Path $cand) { $wpJpg = $cand; break }
            $cand = "${letter}:\wallpaper.jpg"
            if (Test-Path $cand) { $wpJpg = $cand; break }
            $cand = "${letter}:\config\wallpaper\wallpaper.jpg"
            if (Test-Path $cand) { $wpJpg = $cand; break }
        }
    }
    if (-not (Test-Path $wpBmp)) {
        foreach ($letter in 'DEFGHIJKLMNOPQRSTUVWXYZ'.ToCharArray()) {
            $cand = "${letter}:\packages\wallpaper.bmp"
            if (Test-Path $cand) { $wpBmp = $cand; break }
            $cand = "${letter}:\wallpaper.bmp"
            if (Test-Path $cand) { $wpBmp = $cand; break }
            $cand = "${letter}:\config\wallpaper\wallpaper.bmp"
            if (Test-Path $cand) { $wpBmp = $cand; break }
        }
    }
    if (-not (Test-Path $oemBmp)) {
        foreach ($letter in 'DEFGHIJKLMNOPQRSTUVWXYZ'.ToCharArray()) {
            $cand = "${letter}:\packages\oemlogo.bmp"
            if (Test-Path $cand) { $oemBmp = $cand; break }
            $cand = "${letter}:\oemlogo.bmp"
            if (Test-Path $cand) { $oemBmp = $cand; break }
            $cand = "${letter}:\config\wallpaper\oemlogo.bmp"
            if (Test-Path $cand) { $oemBmp = $cand; break }
        }
    }

    if (Test-Path $wpJpg) {
        Copy-Item -Path $wpJpg -Destination "$wallpaperDir\wallpaper.jpg" -Force
        Write-Success "Deployed wallpaper.jpg to $wallpaperDir."
    }
    if (Test-Path $wpBmp) {
        Copy-Item -Path $wpBmp -Destination "$wallpaperDir\wallpaper.bmp" -Force
        Write-Success "Deployed wallpaper.bmp to $wallpaperDir."
    }
    if (Test-Path $oemBmp) {
        Copy-Item -Path $oemBmp -Destination "$env:WINDIR\System32\oemlogo.bmp" -Force
        Write-Success "Deployed oemlogo.bmp to System32."
    }

    # Configure User Desktop Wallpaper Registry
    $desktopKey = "HKCU:\Control Panel\Desktop"
    if (Test-Path "$wallpaperDir\wallpaper.bmp") {
        Set-ItemProperty -Path $desktopKey -Name "Wallpaper" -Value "$wallpaperDir\wallpaper.bmp" -Force
    }
    elseif (Test-Path "$wallpaperDir\wallpaper.jpg") {
        Set-ItemProperty -Path $desktopKey -Name "Wallpaper" -Value "$wallpaperDir\wallpaper.jpg" -Force
    }
    Set-ItemProperty -Path $desktopKey -Name "WallpaperStyle" -Value "2" -Force
    Set-ItemProperty -Path $desktopKey -Name "TileWallpaper" -Value "0" -Force

    # Configure OEM Information Registry
    $oemKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation"
    if (-not (Test-Path $oemKey)) {
        New-Item -Path $oemKey -Force | Out-Null
    }
    Set-ItemProperty -Path $oemKey -Name "Manufacturer" -Value "Windows CoreOS (WCOS)" -Force
    Set-ItemProperty -Path $oemKey -Name "Model" -Value "Free Windows Server Core Distribution" -Force
    Set-ItemProperty -Path $oemKey -Name "SupportURL" -Value "https://github.com/samuelcaldas/windows-core-free" -Force
    if (Test-Path "$env:WINDIR\System32\oemlogo.bmp") {
        Set-ItemProperty -Path $oemKey -Name "Logo" -Value "$env:WINDIR\System32\oemlogo.bmp" -Force
    }
    Write-Success "OEM Information and wallpaper branding registered."
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
    $winfileExe  = "C:\Program Files\WinFile\Winfile.exe"
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

    # 3. File Explorer (ReactFM, Explorer++, or WinFile)
    if (Test-Path $reactFmExe) {
        Create-DesktopShortcut `
            -ShortcutPath "$publicDir\File Explorer.lnk" `
            -TargetPath $reactFmExe `
            -WorkingDirectory "C:\Program Files\ReactShell" `
            -Description "ReactShell File Explorer"
    }
    if (Test-Path $expExe) {
        Create-DesktopShortcut `
            -ShortcutPath "$publicDir\Explorer++.lnk" `
            -TargetPath $expExe `
            -WorkingDirectory "C:\Program Files\Explorer++" `
            -Description "Explorer++ File Manager"
    }
    if (Test-Path $winfileExe) {
        Create-DesktopShortcut `
            -ShortcutPath "$publicDir\File Manager (WinFile).lnk" `
            -TargetPath $winfileExe `
            -WorkingDirectory "C:\Program Files\WinFile" `
            -Description "Microsoft Windows File Manager"
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
    Write-Host "  Windows CoreOS (WCOS) Guest - Desktop Shell & File Explorer Installer"
    Write-Host "=============================================================================="

    # 1. Branding & Wallpaper
    Deploy-DistroBranding

    # 2. File Manager Provider
    if ($FileManager -eq 'ReactFM') {
        Install-ReactFileManager
    }
    elseif ($FileManager -eq 'ExplorerPlusPlus') {
        Install-ExplorerPlusPlus
    }
    elseif ($FileManager -eq 'WinFile') {
        Install-WinFile
    }

    # 3. Shell Provider
    if ($ShellProvider -eq 'ReactShell') {
        Install-ReactShell
    }
    elseif ($ShellProvider -eq 'WinXShell') {
        Install-WinXShell
    }

    # 4. Desktop Shortcuts
    Deploy-DesktopShortcuts

    Write-Success "Desktop Shell ($ShellProvider) and File Manager ($FileManager) deployed successfully."
}

Main
