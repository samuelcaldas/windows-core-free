<#
.SYNOPSIS
    Guest Script: System Specialization, OpenSSH Server, Firewall, and WinRM Setup.
.DESCRIPTION
    Bootstraps the minimal headless Windows Server Core environment:
    - Installs and configures Win32-OpenSSH with PowerShell default shell.
    - Enables WinRM remoting and opens firewall ports.
    - Sets timezone and deactivates nested Hyper-V roles.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Write-Step { param([string]$Msg) Write-Host "[INFO] $Msg" -ForegroundColor Cyan }
function Write-Success { param([string]$Msg) Write-Host "[SUCCESS] $Msg" -ForegroundColor Green }
function Write-WarnMsg { param([string]$Msg) Write-Host "[WARN] $Msg" -ForegroundColor Yellow }

function Configure-SystemBasics {
    Write-Step "Configuring TimeZone to America/Sao_Paulo (E. South America Standard Time)..."
    try {
        Set-TimeZone -Id "E. South America Standard Time" -ErrorAction SilentlyContinue
        Write-Success "TimeZone configured."
    }
    catch {
        Write-WarnMsg "Failed to set timezone: $_"
    }

    Write-Step "Enabling Long Path support in registry..."
    try {
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -Value 1 -Type DWord -Force
        Write-Success "Long paths enabled."
    }
    catch {
        Write-WarnMsg "Failed to enable long paths: $_"
    }

    Write-Step "Ensuring OmniGet (og) binary directory is registered in Machine PATH..."
    $omniBin = "C:\Program Files\OmniGet\bin"
    $machinePath = [System.Environment]::GetEnvironmentVariable('Path', [System.EnvironmentVariableTarget]::Machine)
    if ($machinePath -notlike "*$omniBin*") {
        [System.Environment]::SetEnvironmentVariable('Path', "$omniBin;$machinePath", [System.EnvironmentVariableTarget]::Machine)
        $env:Path = "$omniBin;$env:Path"
        Write-Success "OmniGet binary directory registered in Machine PATH."
    }
}

function Configure-Firewall {
    Write-Step "Configuring Windows Firewall rules for remote administration..."
    $rules = @(
        @{ Name = 'OpenSSH-Server-In-TCP'; Port = 22; Description = 'Inbound rule for OpenSSH Server' },
        @{ Name = 'WinRM-HTTP-In-TCP'; Port = 5985; Description = 'Inbound rule for WinRM HTTP' },
        @{ Name = 'WinRM-HTTPS-In-TCP'; Port = 5986; Description = 'Inbound rule for WinRM HTTPS' },
        @{ Name = 'Antigravity-Daemon-In-TCP'; Port = 9090; Description = 'Inbound rule for Antigravity Headless Remote Control Daemon' }
    )

    foreach ($rule in $rules) {
        try {
            $existing = Get-NetFirewallRule -Name $rule.Name -ErrorAction SilentlyContinue
            if ($null -eq $existing) {
                New-NetFirewallRule -Name $rule.Name -DisplayName $rule.Name -Description $rule.Description `
                    -Direction Inbound -LocalPort $rule.Port -Protocol TCP -Action Allow -Profile Any | Out-Null
                Write-Success "Firewall rule created: $($rule.Name) (Port $($rule.Port))"
            }
            else {
                Set-NetFirewallRule -Name $rule.Name -Enabled True | Out-Null
                Write-Success "Firewall rule already present: $($rule.Name)"
            }
        }
        catch {
            Write-WarnMsg "Firewall rule error for $($rule.Name): $_"
        }
    }
}

function Install-OpenSshServer {
    Write-Step "Installing and configuring Win32-OpenSSH Server..."
    $targetDir = "C:\Program Files\OpenSSH"
    
    if (-not (Test-Path "$targetDir\sshd.exe")) {
        # Search for offline OpenSSH package on CD/USB drives
        $zipSource = $null
        foreach ($letter in 'DEFGHIJKLMNOPQRSTUVWXYZ'.ToCharArray()) {
            foreach ($candidate in @("${letter}:\openssh\OpenSSH-Win64.zip", "${letter}:\OpenSSH-Win64.zip")) {
                if (Test-Path $candidate) {
                    $zipSource = $candidate
                    break
                }
            }
            if ($null -ne $zipSource) { break }
        }

        if ($null -ne $zipSource) {
            Write-Step "Extracting offline OpenSSH package from $zipSource..."
            Expand-Archive -Path $zipSource -DestinationPath "C:\Program Files" -Force
            if (Test-Path "C:\Program Files\OpenSSH-Win64") {
                if (Test-Path $targetDir) { Remove-Item -Path $targetDir -Recurse -Force }
                Move-Item -Path "C:\Program Files\OpenSSH-Win64" -Destination $targetDir -Force
            }
        }
        else {
            Write-Step "Downloading OpenSSH-Win64 from GitHub..."
            try {
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
                $url = "https://github.com/PowerShell/Win32-OpenSSH/releases/download/v9.5.0.0p1-Beta/OpenSSH-Win64.zip"
                $tempZip = "$env:TEMP\OpenSSH-Win64.zip"
                Invoke-WebRequest -Uri $url -OutFile $tempZip -UseBasicParsing
                Expand-Archive -Path $tempZip -DestinationPath "C:\Program Files" -Force
                if (Test-Path "C:\Program Files\OpenSSH-Win64") {
                    if (Test-Path $targetDir) { Remove-Item -Path $targetDir -Recurse -Force }
                    Move-Item -Path "C:\Program Files\OpenSSH-Win64" -Destination $targetDir -Force
                }
            }
            catch {
                Write-WarnMsg "Download failed: $_"
            }
        }

        if (Test-Path "$targetDir\install-sshd.ps1") {
            Write-Step "Running install-sshd.ps1..."
            & powershell.exe -ExecutionPolicy Bypass -File "$targetDir\install-sshd.ps1"
        }
    }

    # Add OpenSSH to machine PATH
    $currPath = [System.Environment]::GetEnvironmentVariable('Path', [System.EnvironmentVariableTarget]::Machine)
    if ($currPath -notlike "*$targetDir*") {
        [System.Environment]::SetEnvironmentVariable('Path', "$targetDir;$currPath", [System.EnvironmentVariableTarget]::Machine)
        $env:Path = "$targetDir;$env:Path"
    }

    # Generate host keys if missing
    if (Test-Path "$targetDir\ssh-keygen.exe") {
        if (-not (Test-Path "C:\ProgramData\ssh\ssh_host_ed25519_key")) {
            & "$targetDir\ssh-keygen.exe" -A | Out-Null
        }
    }

    # Configure and start SSH services
    Write-Step "Starting SSH and SSH-Agent services..."
    foreach ($svcName in @('sshd', 'ssh-agent')) {
        $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
        if ($null -ne $svc) {
            Set-Service -Name $svcName -StartupType Automatic
            if ($svc.Status -ne 'Running') {
                Start-Service -Name $svcName
            }
            Write-Success "Service started and set to Automatic: $svcName"
        }
    }

    # Configure default SSH shell to PowerShell
    Write-Step "Setting OpenSSH default shell to PowerShell..."
    $pwshPath = "C:\Program Files\PowerShell\7\pwsh.exe"
    $defaultShell = if (Test-Path $pwshPath) { $pwshPath } else { "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" }
    
    $regPath = "HKLM:\SOFTWARE\OpenSSH"
    if (-not (Test-Path $regPath)) {
        New-Item -Path $regPath -Force | Out-Null
    }
    Set-ItemProperty -Path $regPath -Name "DefaultShell" -Value $defaultShell -Type String -Force
    Write-Success "Default SSH shell set to: $defaultShell"

    # Initialize ProgramData ssh directory and ACLs
    $programDataSsh = "C:\ProgramData\ssh"
    if (-not (Test-Path $programDataSsh)) {
        New-Item -ItemType Directory -Path $programDataSsh -Force | Out-Null
    }
    $adminAuthKeys = "$programDataSsh\administrators_authorized_keys"
    if (-not (Test-Path $adminAuthKeys)) {
        New-Item -ItemType File -Path $adminAuthKeys -Force | Out-Null
    }
    & icacls.exe "$adminAuthKeys" /inheritance:r /grant "NT AUTHORITY\SYSTEM:(F)" /grant "BUILTIN\Administrators:(F)" | Out-Null
    Write-Success "OpenSSH administrators_authorized_keys initialized with strict ACLs."
}

function Configure-WinRM {
    Write-Step "Configuring PowerShell Remoting (WinRM)..."
    try {
        Enable-PSRemoting -Force -SkipNetworkProfileCheck -ErrorAction SilentlyContinue
        Set-Item -Path "WSMan:\localhost\Service\Auth\Basic" -Value $true -Force -ErrorAction SilentlyContinue
        Set-Item -Path "WSMan:\localhost\Service\AllowUnencrypted" -Value $true -Force -ErrorAction SilentlyContinue
        Write-Success "WinRM remoting enabled."
    }
    catch {
        Write-WarnMsg "WinRM configuration returned: $_"
    }
}

function Main {
    Write-Host "=============================================================================="
    Write-Host "  Windows Core Guest - Specialization & Remote Management Bootstrap"
    Write-Host "=============================================================================="
    Configure-SystemBasics
    Configure-Firewall
    Install-OpenSshServer
    Configure-WinRM

    $disableHyperVScript = Join-Path $PSScriptRoot "Disable-HyperV.ps1"
    if (Test-Path $disableHyperVScript) {
        & $disableHyperVScript
    }

    $optimizeScript = Join-Path $PSScriptRoot "Optimize-System.ps1"
    if (Test-Path $optimizeScript) {
        & $optimizeScript
    }

    $hostsScript = Join-Path $PSScriptRoot "Update-HostsBlocklist.ps1"
    if (Test-Path $hostsScript) {
        & $hostsScript
    }

    $installOmniGetScript = Join-Path $PSScriptRoot "Install-OmniGet.ps1"
    if (Test-Path $installOmniGetScript) {
        Write-Step "Deploying OmniGet (og) Package Engine during specialization..."
        try {
            & $installOmniGetScript -DeployOnly
            Write-Success "OmniGet deployed successfully during specialization."
        }
        catch {
            Write-WarnMsg "Install-OmniGet deployment returned: $_"
        }
    }

    Write-Success "Guest specialization completed successfully."
}

Main
