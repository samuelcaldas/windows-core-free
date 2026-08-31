<#
.SYNOPSIS
    Guest Script: Installs developer toolchains (Git, Node.js LTS, Python 3, PowerShell 7).
.DESCRIPTION
    Automates silent downloading and installation of core developer runtimes and tools
    needed for Windows development and AI Agent execution.
#>
[CmdletBinding()]
param(
    [switch]$SkipNode,
    [switch]$SkipGit,
    [switch]$SkipGh,
    [switch]$SkipPython,
    [switch]$SkipPwsh
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Write-Step { param([string]$Msg) Write-Host "[INFO] $Msg" -ForegroundColor Cyan }
function Write-Success { param([string]$Msg) Write-Host "[SUCCESS] $Msg" -ForegroundColor Green }
function Write-WarnMsg { param([string]$Msg) Write-Host "[WARN] $Msg" -ForegroundColor Yellow }

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$TempDir = "$env:TEMP\win_tools_installer"
if (-not (Test-Path $TempDir)) {
    New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
}

function Refresh-EnvironmentPath {
    $machinePath = [System.Environment]::GetEnvironmentVariable('Path', [System.EnvironmentVariableTarget]::Machine)
    $userPath    = [System.Environment]::GetEnvironmentVariable('Path', [System.EnvironmentVariableTarget]::User)
    $extraPaths  = @(
        'C:\Program Files\Git\bin',
        'C:\Program Files\Git\cmd',
        'C:\Program Files\GitHub CLI',
        'C:\Program Files\nodejs',
        "$env:APPDATA\npm",
        "$env:USERPROFILE\AppData\Roaming\npm",
        'C:\Program Files\PowerShell\7',
        'C:\Program Files\Python312',
        'C:\Program Files\Python312\Scripts'
    )
    $env:Path = ("$machinePath;$userPath;" + ($extraPaths -join ';')).Trim(';')
}

function Download-Fast {
    param([string]$Url, [string]$OutFile)
    Write-Step "Downloading $Url..."
    $curlExe = "$env:WINDIR\System32\curl.exe"
    if (Test-Path $curlExe) {
        & $curlExe -fSL "$Url" -o "$OutFile"
    }
    else {
        $wc = New-Object System.Net.WebClient
        $wc.DownloadFile($Url, $OutFile)
    }
}

function Install-PowerShell7 {
    if ($SkipPwsh) { return }
    Write-Step "Checking PowerShell 7..."
    $currentVer = if (Test-Path "C:\Program Files\PowerShell\7\pwsh.exe") {
        try { (& "C:\Program Files\PowerShell\7\pwsh.exe" --version).Trim() } catch { "" }
    } else { "" }

    $targetVersion = "7.6.5"
    if ($currentVer -like "*$targetVersion*") {
        Write-Success "PowerShell $targetVersion is already installed."
        return
    }

    $msiUrl = "https://github.com/PowerShell/PowerShell/releases/download/v${targetVersion}/PowerShell-${targetVersion}-win-x64.msi"
    $msiFile = "$TempDir\PowerShell-${targetVersion}-win-x64.msi"

    Download-Fast -Url $msiUrl -OutFile $msiFile

    Write-Step "Installing/Upgrading PowerShell $targetVersion silently..."
    Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$msiFile`" /qn /norestart ENABLE_PSREMOTING=1 REGISTER_MANIFEST=1 USE_MU=0" -Wait
    Refresh-EnvironmentPath
    Write-Success "PowerShell $targetVersion installed successfully."
}

function Install-GitForWindows {
    if ($SkipGit) { return }
    Write-Step "Checking Git for Windows..."
    if (Get-Command git -ErrorAction SilentlyContinue) {
        Write-Success "Git is already installed: $(git --version)"
        return
    }

    $gitUrl = "https://github.com/git-for-windows/git/releases/download/v2.46.0.windows.1/Git-2.46.0-64-bit.exe"
    $gitExe = "$TempDir\Git-Installer.exe"

    Download-Fast -Url $gitUrl -OutFile $gitExe

    Write-Step "Installing Git silently..."
    Start-Process -FilePath $gitExe -ArgumentList "/VERYSILENT /NORESTART /NOCANCEL /SP- /CLOSEAPPLICATIONS" -Wait
    Refresh-EnvironmentPath

    try {
        & "C:\Program Files\Git\bin\git.exe" config --system core.longpaths true
        & "C:\Program Files\Git\bin\git.exe" config --system core.autocrlf input
        Write-Success "Git configured with long paths and input LF endings."
    }
    catch {
        Write-WarnMsg "Git global config warning: $_"
    }
}

function Install-GitHubCli {
    if ($SkipGh) { return }
    Write-Step "Checking GitHub CLI..."
    if (Get-Command gh -ErrorAction SilentlyContinue) {
        Write-Success "GitHub CLI is already installed: $(gh --version | Select-Object -First 1)"
        return
    }

    $ghUrl = "https://github.com/cli/cli/releases/download/v2.98.0/gh_2.98.0_windows_amd64.msi"
    $ghMsi = "$TempDir\gh_windows_amd64.msi"

    Download-Fast -Url $ghUrl -OutFile $ghMsi

    Write-Step "Installing GitHub CLI silently..."
    Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$ghMsi`" /qn /norestart" -Wait
    Refresh-EnvironmentPath
    Write-Success "GitHub CLI installed successfully."
}

function Install-NodeJs {
    if ($SkipNode) { return }
    Write-Step "Checking Node.js LTS..."
    if (Get-Command node -ErrorAction SilentlyContinue) {
        Write-Success "Node.js is already installed: $(node -v)"
        return
    }

    $nodeUrl = "https://nodejs.org/dist/v20.17.0/node-v20.17.0-x64.msi"
    $nodeMsi = "$TempDir\node-v20.17.0-x64.msi"

    Download-Fast -Url $nodeUrl -OutFile $nodeMsi

    Write-Step "Installing Node.js LTS silently..."
    Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$nodeMsi`" /qn /norestart" -Wait
    Refresh-EnvironmentPath
    Write-Success "Node.js LTS installed successfully."
}

function Install-Python {
    if ($SkipPython) { return }
    Write-Step "Checking Python 3..."
    if (Get-Command python -ErrorAction SilentlyContinue) {
        Write-Success "Python is already installed: $(python --version)"
        return
    }

    $pyUrl = "https://www.python.org/ftp/python/3.12.5/python-3.12.5-amd64.exe"
    $pyExe = "$TempDir\python-installer.exe"

    Download-Fast -Url $pyUrl -OutFile $pyExe

    Write-Step "Installing Python 3.12 silently..."
    Start-Process -FilePath $pyExe -ArgumentList "/quiet InstallAllUsers=1 PrependPath=1 Include_test=0 Include_pip=1" -Wait
    Refresh-EnvironmentPath
    Write-Success "Python 3.12 installed successfully."
}

function Main {
    Write-Host "=============================================================================="
    Write-Host "  Windows Core Guest - Developer Toolchain Installer"
    Write-Host "=============================================================================="
    Install-PowerShell7
    Install-GitForWindows
    Install-GitHubCli
    Install-NodeJs
    Install-Python
    Refresh-EnvironmentPath

    $desktopShellScript = Join-Path $PSScriptRoot "Install-DesktopShell.ps1"
    if (Test-Path $desktopShellScript) {
        try {
            & $desktopShellScript
        }
        catch {
            Write-WarnMsg "Install-DesktopShell warning: $_"
        }
    }

    $terminalScript = Join-Path $PSScriptRoot "Install-WindowsTerminal.ps1"
    if (Test-Path $terminalScript) {
        try {
            & $terminalScript
        }
        catch {
            Write-WarnMsg "Install-WindowsTerminal warning: $_"
        }
    }

    $niniteScript = Join-Path $PSScriptRoot "Install-NiniteApps.ps1"
    if (Test-Path $niniteScript) {
        try {
            & $niniteScript -DeployOnly
        }
        catch {
            Write-WarnMsg "Install-NiniteApps warning: $_"
        }
    }

    Write-Success "Developer toolchains installed and configured successfully."
}

Main
