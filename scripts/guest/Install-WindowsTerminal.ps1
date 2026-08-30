<#
.SYNOPSIS
    Guest Script: Windows Terminal (microsoft/terminal) Installation.
.DESCRIPTION
    Installs portable Windows Terminal on Windows Server Core:
    - Installs Visual C++ 2015-2022 Redistributable prerequisite.
    - Extracts 64-bit Windows Terminal release to C:\Program Files\WindowsTerminal.
    - Registers Cascadia Code and Cascadia Mono fonts.
    - Configures default multi-tab profiles (PowerShell 7 default + CMD).
    - Adds to system PATH and creates desktop shortcuts.
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

function Install-VCRedist {
    Write-Step "Checking Visual C++ 2015-2022 Redistributable..."
    $vcKey = "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\X64"
    if (Test-Path $vcKey) {
        $installed = Get-ItemPropertyValue -Path $vcKey -Name "Installed" -ErrorAction SilentlyContinue
        if ($installed -eq 1) {
            Write-Success "Visual C++ 2015-2022 Redistributable is already installed."
            return
        }
    }

    $vcExe = Join-Path $SourceDir "vc_redist.x64.exe"
    if (-not (Test-Path $vcExe)) {
        foreach ($letter in 'DEFGHIJKLMNOPQRSTUVWXYZ'.ToCharArray()) {
            $cand = "${letter}:\packages\vc_redist.x64.exe"
            if (Test-Path $cand) { $vcExe = $cand; break }
            $cand = "${letter}:\vc_redist.x64.exe"
            if (Test-Path $cand) { $vcExe = $cand; break }
        }
    }

    if (-not (Test-Path $vcExe)) {
        Write-Step "Downloading Visual C++ Redistributable..."
        $vcExe = "$env:TEMP\vc_redist.x64.exe"
        $url = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
        $curl = "$env:WINDIR\System32\curl.exe"
        if (Test-Path $curl) {
            & $curl -fSL "$url" -o "$vcExe"
        }
        else {
            (New-Object System.Net.WebClient).DownloadFile($url, $vcExe)
        }
    }

    Write-Step "Installing Visual C++ Redistributable silently..."
    Start-Process -FilePath $vcExe -ArgumentList "/install /quiet /norestart" -Wait
    Write-Success "Visual C++ Redistributable installed successfully."
}

function Install-Fonts {
    param([string]$TerminalDir)
    Write-Step "Registering Cascadia Code fonts in Windows..."
    $fontFiles = @("CascadiaCode.ttf", "CascadiaCodeItalic.ttf", "CascadiaMono.ttf", "CascadiaMonoItalic.ttf")
    $fontRegKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"

    foreach ($font in $fontFiles) {
        $srcFont = Join-Path $TerminalDir $font
        if (Test-Path $srcFont) {
            $dstFont = Join-Path "$env:WINDIR\Fonts" $font
            if (-not (Test-Path $dstFont)) {
                Copy-Item -Path $srcFont -Destination $dstFont -Force
            }
            $fontName = [System.IO.Path]::GetFileNameWithoutExtension($font) + " (TrueType)"
            Set-ItemProperty -Path $fontRegKey -Name $fontName -Value $font -Type String -Force
            Write-Success "Registered font: $font"
        }
    }
}

function Configure-TerminalSettings {
    param([string]$TerminalDir)
    Write-Step "Configuring Terminal profiles and WezTerm settings..."
    $pwshPath = "C:\Program Files\PowerShell\7\pwsh.exe"
    $defaultProg = if (Test-Path $pwshPath) { "C:\\Program Files\\PowerShell\\7\\pwsh.exe" } else { "powershell.exe" }

    $weztermConfig = @"
local wezterm = require 'wezterm'
local config = wezterm.config_builder()

config.default_prog = { '$defaultProg' }
config.color_scheme = 'OneDark (Gogh)'
config.font = wezterm.font('Cascadia Code')
config.font_size = 11.0
config.initial_cols = 120
config.initial_rows = 32
config.enable_tab_bar = true
config.hide_tab_bar_if_only_one_tab = false
config.use_fancy_tab_bar = true
config.window_background_opacity = 0.95

return config
"@

    $targetDirs = @(
        "$env:USERPROFILE",
        "C:\Users\samuelcaldas",
        "C:\Users\Administrator",
        $TerminalDir
    )

    foreach ($dir in $targetDirs) {
        try {
            if (-not (Test-Path $dir)) {
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
            }
            $cfgFile = Join-Path $dir ".wezterm.lua"
            $weztermConfig | Out-File -FilePath $cfgFile -Encoding utf8 -Force
            Write-Success "WezTerm configuration deployed to: $cfgFile"
        }
        catch {
            Write-WarnMsg "Could not write settings to $dir : $_"
        }
    }
}

function Install-TerminalPackage {
    Write-Step "Installing Terminal package..."
    $targetDir = "C:\Program Files\WindowsTerminal"
    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }

    $zipFile = Join-Path $SourceDir "terminal_x64.zip"
    if (-not (Test-Path $zipFile)) {
        foreach ($letter in 'DEFGHIJKLMNOPQRSTUVWXYZ'.ToCharArray()) {
            $cand = "${letter}:\packages\terminal_x64.zip"
            if (Test-Path $cand) { $zipFile = $cand; break }
            $cand = "${letter}:\terminal_x64.zip"
            if (Test-Path $cand) { $zipFile = $cand; break }
        }
    }

    $tempExtract = "$env:TEMP\wt_extract_$([System.Guid]::NewGuid().ToString('N'))"
    if (Test-Path $tempExtract) { Remove-Item -Path $tempExtract -Recurse -Force }
    New-Item -ItemType Directory -Path $tempExtract -Force | Out-Null

    try {
        if (Test-Path $zipFile) {
            Write-Step "Extracting Terminal from $zipFile..."
            Expand-Archive -Path $zipFile -DestinationPath $tempExtract -Force
        }
        elseif (-not (Test-Path "$targetDir\wezterm.exe")) {
            Write-Step "Downloading WezTerm portable release..."
            $url = "https://github.com/wezterm/wezterm/releases/download/20240203-110809-5046fc22/WezTerm-windows-20240203-110809-5046fc22.zip"
            $tempZip = "$env:TEMP\terminal_x64.zip"
            $curl = "$env:WINDIR\System32\curl.exe"
            if (Test-Path $curl) {
                & $curl -fSL "$url" -o "$tempZip"
            }
            else {
                (New-Object System.Net.WebClient).DownloadFile($url, $tempZip)
            }
            Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force
        }

        $srcDir = $tempExtract
        $sub = Get-ChildItem -Path $tempExtract -Directory | Where-Object { $_.Name -like "WezTerm-*" -or $_.Name -like "terminal-*" } | Select-Object -First 1
        if ($null -ne $sub) { $srcDir = $sub.FullName }

        # Clean old incompatible binaries if upgrading
        if (Test-Path "$targetDir\WindowsTerminal.exe") {
            Remove-Item -Path "$targetDir\*" -Recurse -Force -ErrorAction SilentlyContinue
        }

        Copy-Item -Path "$srcDir\*" -Destination $targetDir -Recurse -Force
    }
    finally {
        Remove-Item -Path $tempExtract -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Create wt.exe compatibility link
    $wtLink = Join-Path $targetDir "wt.exe"
    $mainExe = if (Test-Path "$targetDir\wezterm-gui.exe") { "$targetDir\wezterm-gui.exe" } elseif (Test-Path "$targetDir\wezterm.exe") { "$targetDir\wezterm.exe" } else { "" }
    if ($mainExe -and (-not (Test-Path $wtLink))) {
        try {
            New-Item -ItemType HardLink -Path $wtLink -Target $mainExe -Force | Out-Null
            Write-Success "Created wt.exe compatibility link -> $mainExe"
        }
        catch {
            Copy-Item -Path $mainExe -Destination $wtLink -Force
            Write-Success "Copied $mainExe to wt.exe"
        }
    }

    # Add to Machine PATH
    $currPath = [System.Environment]::GetEnvironmentVariable('Path', [System.EnvironmentVariableTarget]::Machine)
    if ($currPath -notlike "*$targetDir*") {
        [System.Environment]::SetEnvironmentVariable('Path', "$targetDir;$currPath", [System.EnvironmentVariableTarget]::Machine)
        $env:Path = "$targetDir;$env:Path"
    }

    Install-Fonts -TerminalDir $targetDir
    Configure-TerminalSettings -TerminalDir $targetDir

    # Create Desktop Shortcut in Public Desktop
    $publicDesktop = "C:\Users\Public\Desktop"
    if (-not (Test-Path $publicDesktop)) {
        New-Item -ItemType Directory -Path $publicDesktop -Force | Out-Null
    }

    # Clean up duplicate shortcuts from individual user desktop directories
    $userDirs = @("C:\Users\samuelcaldas\Desktop", "C:\Users\Administrator\Desktop")
    foreach ($uDir in $userDirs) {
        $dup = Join-Path $uDir "Windows Terminal.lnk"
        if (Test-Path $dup) {
            Remove-Item -Path $dup -Force -ErrorAction SilentlyContinue
        }
    }

    $targetExe = if (Test-Path "$targetDir\wt.exe") { "$targetDir\wt.exe" } elseif (Test-Path "$targetDir\wezterm-gui.exe") { "$targetDir\wezterm-gui.exe" } else { "$targetDir\wezterm.exe" }

    Create-DesktopShortcut `
        -ShortcutPath "$publicDesktop\Windows Terminal.lnk" `
        -TargetPath $targetExe `
        -WorkingDirectory "$env:SystemDrive\Users\samuelcaldas" `
        -Description "Windows Terminal (WezTerm Engine)"

    Write-Success "Windows Terminal installed and configured successfully."
}

function Main {
    Write-Host "=============================================================================="
    Write-Host "  Windows Core Guest - Windows Terminal (microsoft/terminal) Installer"
    Write-Host "=============================================================================="
    Install-VCRedist
    Install-TerminalPackage
    Write-Success "Windows Terminal deployment completed successfully."
}

Main
