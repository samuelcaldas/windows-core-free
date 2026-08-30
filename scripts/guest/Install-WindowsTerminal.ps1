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
    Write-Step "Configuring Windows Terminal profiles and settings..."
    $pwshPath = "C:\Program Files\PowerShell\7\pwsh.exe"
    $defaultPwsh = if (Test-Path $pwshPath) { $pwshPath } else { "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" }
    
    $settingsContent = @"
{
    "`$schema": "https://aka.ms/terminal-profiles-schema",
    "defaultProfile": "{574e775e-4f2a-5b96-ac1e-a2962a402336}",
    "initialCols": 120,
    "initialRows": 30,
    "theme": "dark",
    "profiles": {
        "defaults": {
            "font": {
                "face": "Cascadia Code",
                "size": 11
            },
            "padding": "8, 8, 8, 8",
            "useAcrylic": false
        },
        "list": [
            {
                "guid": "{574e775e-4f2a-5b96-ac1e-a2962a402336}",
                "name": "PowerShell",
                "commandline": "$($defaultPwsh -replace '\\', '\\\\')",
                "hidden": false
            },
            {
                "guid": "{0caa0dad-35be-5f56-a8ff-afceeeaa6101}",
                "name": "Command Prompt",
                "commandline": "cmd.exe",
                "hidden": false
            }
        ]
    }
}
"@

    $targetDirs = @(
        "$env:LOCALAPPDATA\Microsoft\Windows Terminal",
        "C:\Users\samuelcaldas\AppData\Local\Microsoft\Windows Terminal",
        $TerminalDir
    )

    foreach ($dir in $targetDirs) {
        try {
            if (-not (Test-Path $dir)) {
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
            }
            $settingsFile = Join-Path $dir "settings.json"
            $settingsContent | Out-File -FilePath $settingsFile -Encoding utf8 -Force
            Write-Success "Settings deployed to: $settingsFile"
        }
        catch {
            Write-WarnMsg "Could not write settings to $dir : $_"
        }
    }
}

function Install-TerminalPackage {
    Write-Step "Installing Windows Terminal package..."
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
            Write-Step "Extracting Windows Terminal from $zipFile..."
            Expand-Archive -Path $zipFile -DestinationPath $tempExtract -Force
        }
        elseif (-not (Test-Path "$targetDir\wt.exe")) {
            Write-Step "Downloading Windows Terminal portable release..."
            $url = "https://github.com/microsoft/terminal/releases/download/v1.24.11911.0/Microsoft.WindowsTerminal_1.24.11911.0_x64.zip"
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
        $sub = Get-ChildItem -Path $tempExtract -Directory | Where-Object { $_.Name -like "terminal-*" } | Select-Object -First 1
        if ($null -ne $sub) { $srcDir = $sub.FullName }

        Copy-Item -Path "$srcDir\*" -Destination $targetDir -Recurse -Force
    }
    finally {
        Remove-Item -Path $tempExtract -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Add to Machine PATH
    $currPath = [System.Environment]::GetEnvironmentVariable('Path', [System.EnvironmentVariableTarget]::Machine)
    if ($currPath -notlike "*$targetDir*") {
        [System.Environment]::SetEnvironmentVariable('Path', "$targetDir;$currPath", [System.EnvironmentVariableTarget]::Machine)
        $env:Path = "$targetDir;$env:Path"
    }

    Install-Fonts -TerminalDir $targetDir
    Configure-TerminalSettings -TerminalDir $targetDir

    # Create Desktop Shortcuts
    $iconPath = Join-Path $targetDir "Images\terminal_contrast-black.ico"
    if (-not (Test-Path $iconPath)) {
        $iconPath = "$targetDir\wt.exe,0"
    }

    $desktopDirs = @(
        "C:\Users\Public\Desktop",
        "C:\Users\samuelcaldas\Desktop",
        "C:\Users\Administrator\Desktop"
    )

    foreach ($desk in $desktopDirs) {
        Create-DesktopShortcut `
            -ShortcutPath "$desk\Windows Terminal.lnk" `
            -TargetPath "$targetDir\wt.exe" `
            -WorkingDirectory "$env:SystemDrive\Users\samuelcaldas" `
            -IconLocation $iconPath `
            -Description "Microsoft Windows Terminal"
    }

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
