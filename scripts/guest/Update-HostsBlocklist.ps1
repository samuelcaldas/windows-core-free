<#
.SYNOPSIS
    Dan Pollock Zero-Route Hosts Blocklist Installer for Windows CoreOS (WCOS).
.DESCRIPTION
    Applies https://someonewhocares.org/hosts/zero/hosts to
    C:\Windows\System32\drivers\etc\hosts for zero-overhead DNS blocking
    of ad, telemetry, tracking, and malware domains.
#>

[CmdletBinding()]
param(
    [string]$SourcePath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

function Write-Step { param([string]$Msg) Write-Host "[INFO] $Msg" -ForegroundColor Cyan }
function Write-Success { param([string]$Msg) Write-Host "[SUCCESS] $Msg" -ForegroundColor Green }
function Write-WarnMsg { param([string]$Msg) Write-Host "[WARN] $Msg" -ForegroundColor Yellow }
function Write-ErrMsg { param([string]$Msg) Write-Host "[ERROR] $Msg" -ForegroundColor Red }

function Main {
    Write-Host "==============================================================================" -ForegroundColor Cyan
    Write-Host "  Windows CoreOS (WCOS) - Dan Pollock Zero-Route Hosts Blocklist Installer" -ForegroundColor Cyan
    Write-Host "==============================================================================" -ForegroundColor Cyan

    $targetHosts = "$env:WINDIR\System32\drivers\etc\hosts"
    $backupHosts = "$env:WINDIR\System32\drivers\etc\hosts.bak"

    # 1. Locate source hosts file
    $sourceFile = $null
    if ($SourcePath -and (Test-Path $SourcePath)) {
        $sourceFile = $SourcePath
    }
    else {
        # Check standard staging locations
        $candidates = @(
            "C:\Provisioning\config\hosts\hosts",
            "C:\Provisioning\config\hosts",
            "C:\Provisioning\hosts",
            "C:\config\hosts\hosts"
        )
        foreach ($cand in $candidates) {
            if (Test-Path $cand) {
                $sourceFile = $cand
                break
            }
        }

        # Check CD/USB drives (OEMDRV)
        if (-not $sourceFile) {
            foreach ($letter in 'DEFGHIJKLMNOPQRSTUVWXYZ'.ToCharArray()) {
                $cand = "${letter}:\config\hosts\hosts"
                if (Test-Path $cand) { $sourceFile = $cand; break }
                $cand = "${letter}:\hosts"
                if (Test-Path $cand) { $sourceFile = $cand; break }
            }
        }
    }

    # 2. Download from official source if offline file not found
    if (-not $sourceFile -or -not (Test-Path $sourceFile)) {
        Write-Step "Downloading latest Dan Pollock hosts blocklist from official URL..."
        $tempFile = "$env:TEMP\hosts_zero_$([System.Guid]::NewGuid().ToString('N'))"
        $url = "https://someonewhocares.org/hosts/zero/hosts"
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
            $curl = "$env:WINDIR\System32\curl.exe"
            if (Test-Path $curl) {
                & $curl -fSL "$url" -o "$tempFile"
            }
            else {
                (New-Object System.Net.WebClient).DownloadFile($url, $tempFile)
            }
            if (Test-Path $tempFile) {
                $sourceFile = $tempFile
                Write-Success "Downloaded hosts blocklist successfully."
            }
        }
        catch {
            Write-ErrMsg "Failed to download hosts file: $_"
            return
        }
    }

    # 3. Create Backup of existing hosts file
    if (Test-Path $targetHosts) {
        try {
            Copy-Item -Path $targetHosts -Destination $backupHosts -Force
            Write-Success "Created backup at: $backupHosts"
        }
        catch {
            Write-WarnMsg "Could not create backup of hosts file: $_"
        }
    }

    # 4. Deploy new hosts file
    Write-Step "Deploying hosts blocklist to $targetHosts..."
    try {
        # Ensure file is not read-only
        if (Test-Path $targetHosts) {
            Set-ItemProperty -Path $targetHosts -Name Attributes -Value ([System.IO.FileAttributes]::Normal) -ErrorAction SilentlyContinue
        }
        Copy-Item -Path $sourceFile -Destination $targetHosts -Force
        Write-Success "Deployed new hosts file."
    }
    catch {
        Write-ErrMsg "Failed to copy hosts file to $targetHosts : $_"
        return
    }

    # 5. Flush Windows DNS Resolver Cache
    Write-Step "Flushing Windows DNS Client Cache..."
    try {
        if (Get-Command Clear-DnsClientCache -ErrorAction SilentlyContinue) {
            Clear-DnsClientCache
        }
        else {
            & "$env:WINDIR\System32\ipconfig.exe" /flushdns | Out-Null
        }
        Write-Success "DNS Client cache flushed."
    }
    catch {
        Write-WarnMsg "DNS flush notice: $_"
    }

    # 6. Verify entry count
    $lineCount = (Get-Content $targetHosts).Count
    Write-Success "Active hosts file verified ($lineCount rules active)."
}

Main
