#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Synchronizes Windows CoreOS (WCOS) Wiki pages to GitHub Wiki repository (PowerShell 7)
.DESCRIPTION
    Pushes documentation from wiki/ to the GitHub Wiki git endpoint.
#>
[CmdletBinding()]
param(
    [string]$WikiGitUrl = "git@github.com:samuelcaldas/windows-core-free.wiki.git"
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot  = (Resolve-Path "$ScriptDir/../..").Path
$WikiSrc   = Join-Path $RepoRoot "wiki"

function Write-Step { param([string]$Msg) Write-Host "[INFO] $Msg" -ForegroundColor Cyan }
function Write-Success { param([string]$Msg) Write-Host "[SUCCESS] $Msg" -ForegroundColor Green }
function Write-WarnMsg { param([string]$Msg) Write-Host "[WARN] $Msg" -ForegroundColor Yellow }
function Write-ErrMsg { param([string]$Msg) Write-Host "[ERROR] $Msg" -ForegroundColor Red }

function Main {
    Write-Host "=============================================================================="
    Write-Host "  Windows CoreOS (WCOS) - GitHub Wiki Synchronization (PowerShell)"
    Write-Host "=============================================================================="

    if (-not (Test-Path $WikiSrc)) {
        Write-ErrMsg "Wiki source directory '$WikiSrc' does not exist."
        exit 1
    }

    $pages = Get-ChildItem -Path $WikiSrc -Filter "*.md"
    Write-Step "Found $($pages.Count) markdown pages in $WikiSrc."

    $tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ("wcos-wiki-sync-" + [System.Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null

    try {
        Write-Step "Attempting to clone GitHub Wiki repository..."
        $cloned = $false
        try {
            & git clone $WikiGitUrl $tmpDir 2>$null
            if ($LASTEXITCODE -eq 0) { $cloned = $true }
        }
        catch {}

        if (-not $cloned) {
            Write-WarnMsg "Wiki remote repository could not be cloned directly."
            Write-WarnMsg "Initializing fresh Git repository for push..."
            & git -C $tmpDir init -b master
            & git -C $tmpDir remote add origin $WikiGitUrl
        }

        Write-Step "Copying pages from $WikiSrc..."
        Copy-Item -Path "$WikiSrc\*" -Destination $tmpDir -Recurse -Force

        & git -C $tmpDir add .
        & git -C $tmpDir diff --staged --quiet
        if ($LASTEXITCODE -eq 0) {
            Write-Step "No changes to sync. GitHub Wiki is already up to date."
            return
        }

        $timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ssZ")
        & git -C $tmpDir commit -m "docs(wiki): synchronize WCOS wiki pages ($timestamp)"

        Write-Step "Pushing wiki pages to GitHub..."
        & git -C $tmpDir push origin master
        if ($LASTEXITCODE -ne 0) {
            & git -C $tmpDir push origin HEAD:master
        }

        if ($LASTEXITCODE -eq 0) {
            Write-Success "GitHub Wiki synchronized successfully!"
        }
        else {
            Write-ErrMsg "Failed to push to GitHub Wiki."
            Write-WarnMsg "Note: GitHub requires the first wiki page to be initialized via the web UI."
            Write-WarnMsg "Visit https://github.com/samuelcaldas/windows-core-free/wiki and click 'Create the first page' once, then re-run this script."
        }
    }
    finally {
        if (Test-Path $tmpDir) {
            Remove-Item -Path $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Main
