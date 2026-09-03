<#
.SYNOPSIS
    Guest Script: Deploys the modular sconfig Control Center patch for Windows CoreOS (WCOS).
.DESCRIPTION
    Replaces legacy Hyper-V sconfig.vbs with the categorized Control Center TUI,
    installs sconfig-modules into System32, and configures shortcuts.
#>
[CmdletBinding()]
param(
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Write-Step { param([string]$Msg) Write-Host "[INFO] $Msg" -ForegroundColor Cyan }
function Write-Success { param([string]$Msg) Write-Host "[SUCCESS] $Msg" -ForegroundColor Green }
function Write-WarnMsg { param([string]$Msg) Write-Host "[WARN] $Msg" -ForegroundColor Yellow }

$SourceDir = Join-Path $PSScriptRoot "sconfig"
if (-not (Test-Path $SourceDir)) {
    $SourceDir = "C:\Provisioning\scripts\sconfig"
}

$System32Dir = "$env:WINDIR\System32"
$EnUsDir     = "$env:WINDIR\System32\en-US"
$ModulesDir  = "$env:WINDIR\System32\sconfig-modules"

Write-Host "=============================================================================="
Write-Host "  Windows CoreOS (WCOS) Guest - sconfig Control Center Patch Installer"
Write-Host "=============================================================================="

# 1. Ensure target modules directory exists
if (-not (Test-Path $ModulesDir)) {
    New-Item -ItemType Directory -Path $ModulesDir -Force | Out-Null
    Write-Step "Created modules directory: $ModulesDir"
}

# 2. Take ownership and backup existing sconfig files if needed
$vbsTarget = Join-Path $System32Dir "sconfig.vbs"
$vbsEnUs   = Join-Path $EnUsDir "sconfig.vbs"
$cmdTarget = Join-Path $System32Dir "sconfig.cmd"

foreach ($targetFile in @($vbsTarget, $vbsEnUs, $cmdTarget)) {
    if (Test-Path $targetFile) {
        try {
            & takeown.exe /f $targetFile 2>$null | Out-Null
            & icacls.exe $targetFile /grant "administrators:F" /q 2>$null | Out-Null
        } catch {}

        if (-not (Test-Path "$targetFile.bak")) {
            Copy-Item -Path $targetFile -Destination "$targetFile.bak" -Force
            Write-Step "Created backup: $targetFile.bak"
        }
    }
}

# 3. Deploy sconfig.cmd and sconfig.vbs
$vbsSource = Join-Path $SourceDir "sconfig.vbs"
$cmdSource = Join-Path $SourceDir "sconfig.cmd"

if (Test-Path $vbsSource) {
    Copy-Item -Path $vbsSource -Destination $vbsTarget -Force
    if (Test-Path $EnUsDir) {
        Copy-Item -Path $vbsSource -Destination $vbsEnUs -Force
    }
    Write-Success "Deployed patched sconfig.vbs to System32."
} else {
    Write-WarnMsg "sconfig.vbs source not found at $vbsSource"
}

if (Test-Path $cmdSource) {
    Copy-Item -Path $cmdSource -Destination $cmdTarget -Force
    Write-Success "Deployed patched sconfig.cmd to System32."
} else {
    Write-WarnMsg "sconfig.cmd source not found at $cmdSource"
}

# 4. Deploy modular PowerShell scripts to System32\sconfig-modules
$modulesSource = Join-Path $SourceDir "modules"
if (Test-Path $modulesSource) {
    Get-ChildItem -Path $modulesSource -Filter "*.ps1" | ForEach-Object {
        $dest = Join-Path $ModulesDir $_.Name
        Copy-Item -Path $_.FullName -Destination $dest -Force
        Write-Step "Installed module: $($_.Name)"
    }
    Write-Success "Installed all modular sconfig PowerShell scripts."
}

# 5. Create Desktop shortcut on Public Desktop
$publicDesktop = [Environment]::GetFolderPath('CommonDesktopDirectory')
if (Test-Path $publicDesktop) {
    try {
        $wshShell = New-Object -ComObject WScript.Shell
        $shortcutPath = Join-Path $publicDesktop "Server Control Center (sconfig).lnk"
        $shortcut = $wshShell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = "$System32Dir\sconfig.cmd"
        $shortcut.WorkingDirectory = $System32Dir
        $shortcut.Description = "Windows Core Developer Edition - Server Control Center"
        $shortcut.IconLocation = "$System32Dir\shell32.dll,21"
        $shortcut.Save()
        Write-Success "Created Desktop shortcut: Server Control Center (sconfig).lnk"
    }
    catch {
        Write-WarnMsg "Shortcut creation warning: $_"
    }
}

Write-Success "sconfig Control Center patch deployed successfully."
