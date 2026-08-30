<#
.SYNOPSIS
    Interactive TUI Ninite Application Manager & Installer for Windows Server Core.
.DESCRIPTION
    Provides an interactive Terminal User Interface (TUI) and CLI tool to browse,
    select, and install software packages dynamically via Ninite.com without bloatware.
.PARAMETER Apps
    Array of Ninite app slugs to install directly without interactive prompt.
.PARAMETER Preset
    Preset profile to select (e.g. DevStack, Browsers, Minimal, Utilities, Media).
.PARAMETER Silent
    When specified, installs without interactive confirmation prompt.
.EXAMPLE
    .\Install-NiniteApps.ps1
    .\Install-NiniteApps.ps1 -Preset DevStack -Silent
    .\Install-NiniteApps.ps1 -Apps @("vscode", "7zip", "chrome") -Silent
#>
[CmdletBinding()]
param(
    [string[]]$Apps = @(),
    [ValidateSet("DevStack", "Browsers", "Minimal", "Utilities", "Media", "All", "")]
    [string]$Preset = "",
    [switch]$Silent,
    [switch]$DeployOnly
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# --- Catalog Definition ---
$Catalog = @(
    @{
        Category = "Web Browsers"
        Items = @(
            @{ Id = "chrome"; Name = "Google Chrome"; Desc = "Fast, modern web browser by Google" },
            @{ Id = "firefox"; Name = "Mozilla Firefox"; Desc = "Extensible open-source browser" },
            @{ Id = "edge"; Name = "Microsoft Edge"; Desc = "Chromium-based Microsoft browser" },
            @{ Id = "brave"; Name = "Brave Browser"; Desc = "Privacy-focused ad-blocking browser" },
            @{ Id = "opera"; Name = "Opera"; Desc = "Alternative feature-rich browser" }
        )
    },
    @{
        Category = "Developer Tools & Editors"
        Items = @(
            @{ Id = "vscode"; Name = "Visual Studio Code"; Desc = "Popular code editor by Microsoft" },
            @{ Id = "notepadplusplus"; Name = "Notepad++"; Desc = "Fast tabbed source and text editor" },
            @{ Id = "putty"; Name = "PuTTY"; Desc = "SSH and Telnet client" },
            @{ Id = "winscp"; Name = "WinSCP"; Desc = "SFTP, SCP, and FTP client" },
            @{ Id = "filezilla"; Name = "FileZilla"; Desc = "FTP/FTPS/SFTP client" },
            @{ Id = "python"; Name = "Python 3"; Desc = "Python programming language runtime" },
            @{ Id = "jdk17"; Name = "OpenJDK 17 LTS"; Desc = "Java Development Kit 17" }
        )
    },
    @{
        Category = "Compression & Utilities"
        Items = @(
            @{ Id = "7zip"; Name = "7-Zip"; Desc = "High-compression file archiver" },
            @{ Id = "peazip"; Name = "PeaZip"; Desc = "Open-source file manager and archiver" },
            @{ Id = "winrar"; Name = "WinRAR"; Desc = "RAR archiver (Trial)" },
            @{ Id = "teracopy"; Name = "TeraCopy"; Desc = "Fast reliable file copier" },
            @{ Id = "windirstat"; Name = "WinDirStat"; Desc = "Disk space usage visualizer" },
            @{ Id = "everything"; Name = "Everything"; Desc = "Instant filename search tool" }
        )
    },
    @{
        Category = "Media & Graphics"
        Items = @(
            @{ Id = "vlc"; Name = "VLC Media Player"; Desc = "Versatile open-source media player" },
            @{ Id = "spotify"; Name = "Spotify"; Desc = "Digital music streaming app" },
            @{ Id = "audacity"; Name = "Audacity"; Desc = "Open-source audio recording & editor" },
            @{ Id = "gimp"; Name = "GIMP"; Desc = "GNU Image Manipulation Program" },
            @{ Id = "paint.net"; Name = "Paint.NET"; Desc = "Image and photo editing software" },
            @{ Id = "greenshot"; Name = "Greenshot"; Desc = "Lightweight screenshot capture tool" },
            @{ Id = "sharex"; Name = "ShareX"; Desc = "Screen capture and file sharing" }
        )
    },
    @{
        Category = "Documents & Readers"
        Items = @(
            @{ Id = "sumatrapdf"; Name = "SumatraPDF"; Desc = "Slim, fast, lightweight PDF reader" },
            @{ Id = "foxit"; Name = "Foxit Reader"; Desc = "PDF viewing and annotation" },
            @{ Id = "libreoffice"; Name = "LibreOffice"; Desc = "Complete open-source office suite" }
        )
    },
    @{
        Category = "Remote Access"
        Items = @(
            @{ Id = "anydesk"; Name = "AnyDesk"; Desc = "Fast remote desktop software" },
            @{ Id = "teamviewer15"; Name = "TeamViewer"; Desc = "Remote control and meeting tool" },
            @{ Id = "realvnc"; Name = "RealVNC Viewer"; Desc = "VNC remote control viewer" }
        )
    }
)

# Flattened lookup list
$AllItems = [System.Collections.Generic.List[PSObject]]::new()
foreach ($cat in $Catalog) {
    foreach ($item in $cat.Items) {
        $AllItems.Add([PSCustomObject]@{
            Category = $cat.Category
            Id       = $item.Id
            Name     = $item.Name
            Desc     = $item.Desc
        })
    }
}

$PresetsMap = @{
    "DevStack"  = @("vscode", "notepadplusplus", "7zip", "putty", "winscp", "python")
    "Browsers"  = @("chrome", "firefox")
    "Minimal"   = @("7zip", "notepadplusplus", "chrome")
    "Utilities" = @("7zip", "windirstat", "everything", "teracopy")
    "Media"     = @("vlc", "greenshot", "audacity", "spotify")
    "All"       = ($AllItems | ForEach-Object { $_.Id })
}

function Get-SelectedFromPreset {
    param([string]$PresetName)
    $set = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    if ($PresetsMap.ContainsKey($PresetName)) {
        foreach ($app in $PresetsMap[$PresetName]) {
            [void]$set.Add($app)
        }
    }
    return $set
}

function Invoke-NiniteInstallation {
    param(
        [System.Collections.Generic.HashSet[string]]$SelectedIds
    )

    if ($SelectedIds.Count -eq 0) {
        Write-Host "`n[WARN] No applications selected for installation. Exiting." -ForegroundColor Yellow
        return
    }

    $slugs = $SelectedIds | Sort-Object
    $slugString = ($slugs -join "-")
    $installerUrl = "https://ninite.com/${slugString}/ninite.exe"
    $installerPath = "$env:TEMP\ninite_installer.exe"

    Write-Host "`n==============================================================================" -ForegroundColor Cyan
    Write-Host "  Ninite Package Installation" -ForegroundColor Cyan
    Write-Host "==============================================================================" -ForegroundColor Cyan
    Write-Host "[INFO] Selected packages ($($SelectedIds.Count)): $($slugs -join ', ')" -ForegroundColor Green
    Write-Host "[INFO] Generated Ninite Installer URL: $installerUrl" -ForegroundColor Gray
    Write-Host "[INFO] Downloading custom Ninite bundle..." -ForegroundColor Cyan

    $curlExe = "$env:WINDIR\System32\curl.exe"
    try {
        if (Test-Path $curlExe) {
            & $curlExe -fSL "$installerUrl" -o "$installerPath"
        }
        else {
            $wc = New-Object System.Net.WebClient
            $wc.DownloadFile($installerUrl, $installerPath)
        }

        if (-not (Test-Path $installerPath) -or (Get-Item $installerPath).Length -lt 1024) {
            throw "Downloaded installer is empty or corrupted."
        }

        $sizeKb = [math]::Round((Get-Item $installerPath).Length / 1KB, 1)
        Write-Host "[SUCCESS] Installer downloaded successfully ($sizeKb KB)." -ForegroundColor Green
        Write-Host "[INFO] Executing Ninite silent installation in background..." -ForegroundColor Cyan
        Write-Host "[INFO] Please wait while applications are being downloaded and installed..." -ForegroundColor Yellow

        $proc = Start-Process -FilePath $installerPath -Wait -PassThru -NoNewWindow
        Write-Host "[SUCCESS] Ninite process completed with exit code $($proc.ExitCode)." -ForegroundColor Green
    }
    catch {
        Write-Host "[ERROR] Installation failed: $_" -ForegroundColor Red
    }
    finally {
        if (Test-Path $installerPath) {
            Remove-Item -Path $installerPath -Force -ErrorAction SilentlyContinue
            Write-Host "[INFO] Cleaned up temporary installer file." -ForegroundColor Gray
        }
    }
}

function Show-TUI {
    param(
        [System.Collections.Generic.HashSet[string]]$InitialSelection
    )

    $selected = [System.Collections.Generic.HashSet[string]]::new($InitialSelection, [System.StringComparer]::OrdinalIgnoreCase)
    $cursor = 0
    $total = $AllItems.Count
    $presetKeys = @("Minimal", "DevStack", "Browsers", "Utilities", "Media", "All")
    $presetIndex = 0

    $canRawUI = $true
    try {
        $null = [Console]::KeyAvailable
    }
    catch {
        $canRawUI = $false
    }

    if (-not $canRawUI) {
        return Show-FallbackMenu -InitialSelection $selected
    }

    [Console]::CursorVisible = $false
    try {
        while ($true) {
            Clear-Host
            Write-Host "================================================================================" -ForegroundColor Cyan
            Write-Host "            NINITE INTERACTIVE PACKAGE MANAGER (Windows Server Core)           " -ForegroundColor Cyan
            Write-Host "================================================================================" -ForegroundColor Cyan
            Write-Host " [?] Use Up/Down (or j/k) | [Space] Toggle | [a] All | [n] None" -ForegroundColor Gray
            Write-Host "     [p] Cycle Presets | [Enter] Install Selected | [q/Esc] Quit" -ForegroundColor Gray
            Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray

            $lastCat = ""
            for ($i = 0; $i -lt $total; $i++) {
                $item = $AllItems[$i]
                if ($item.Category -ne $lastCat) {
                    Write-Host "`n  :: $($item.Category)" -ForegroundColor Yellow
                    $lastCat = $item.Category
                }

                $isCursor = ($i -eq $cursor)
                $isSelected = $selected.Contains($item.Id)

                $checkMark = if ($isSelected) { "[x]" } else { "[ ]" }
                $pointer   = if ($isCursor)   { ">" }   else { " " }

                $lineText = "  $pointer $checkMark {0,-18} - {1}" -f $item.Id, $item.Desc

                if ($isCursor) {
                    Write-Host $lineText -ForegroundColor Black -BackgroundColor Cyan
                }
                elseif ($isSelected) {
                    Write-Host $lineText -ForegroundColor Green
                }
                else {
                    Write-Host $lineText -ForegroundColor White
                }
            }

            Write-Host "`n--------------------------------------------------------------------------------" -ForegroundColor DarkGray
            $selCount = $selected.Count
            $selPreview = if ($selCount -gt 0) { ($selected | Sort-Object) -join ' ' } else { "None" }
            Write-Host " Selected ($selCount apps): " -NoNewline -ForegroundColor Cyan
            Write-Host "$selPreview" -ForegroundColor Green
            Write-Host " > Press [ENTER] to download & install selected packages now..." -ForegroundColor Yellow

            $keyInfo = [Console]::ReadKey($true)

            switch ($keyInfo.Key) {
                ([ConsoleKey]::UpArrow) {
                    $cursor = [Math]::Max(0, $cursor - 1)
                }
                ([ConsoleKey]::DownArrow) {
                    $cursor = [Math]::Min($total - 1, $cursor + 1)
                }
                ([ConsoleKey]::K) {
                    $cursor = [Math]::Max(0, $cursor - 1)
                }
                ([ConsoleKey]::J) {
                    $cursor = [Math]::Min($total - 1, $cursor + 1)
                }
                ([ConsoleKey]::Spacebar) {
                    $currId = $AllItems[$cursor].Id
                    if ($selected.Contains($currId)) {
                        [void]$selected.Remove($currId)
                    }
                    else {
                        [void]$selected.Add($currId)
                    }
                }
                ([ConsoleKey]::A) {
                    foreach ($it in $AllItems) { [void]$selected.Add($it.Id) }
                }
                ([ConsoleKey]::N) {
                    $selected.Clear()
                }
                ([ConsoleKey]::P) {
                    $pName = $presetKeys[$presetIndex % $presetKeys.Count]
                    $presetIndex++
                    $selected = Get-SelectedFromPreset -PresetName $pName
                }
                ([ConsoleKey]::Enter) {
                    return $selected
                }
                ([ConsoleKey]::Escape) {
                    return [System.Collections.Generic.HashSet[string]]::new()
                }
                ([ConsoleKey]::Q) {
                    return [System.Collections.Generic.HashSet[string]]::new()
                }
            }
        }
    }
    finally {
        [Console]::CursorVisible = $true
    }
}

function Show-FallbackMenu {
    param(
        [System.Collections.Generic.HashSet[string]]$InitialSelection
    )

    Clear-Host
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host "            NINITE PACKAGE SELECTION (Console Fallback Mode)                    " -ForegroundColor Cyan
    Write-Host "================================================================================" -ForegroundColor Cyan

    for ($i = 0; $i -lt $AllItems.Count; $i++) {
        $it = $AllItems[$i]
        $idx = "{0,2}" -f ($i + 1)
        Write-Host " [$idx] {0,-18} - {1}" -f $it.Id, $it.Name -ForegroundColor White
    }

    Write-Host "`nPresets: DevStack, Browsers, Minimal, Utilities, Media, All" -ForegroundColor Yellow
    Write-Host "Enter numbers or IDs separated by commas (or type a preset name, 'q' to exit):" -ForegroundColor Cyan
    $inputStr = Read-Host "Selection"

    if ([string]::IsNullOrWhiteSpace($inputStr) -or $inputStr.Trim().ToLower() -eq 'q') {
        return [System.Collections.Generic.HashSet[string]]::new()
    }

    $set = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    if ($PresetsMap.ContainsKey($inputStr.Trim())) {
        return Get-SelectedFromPreset -PresetName $inputStr.Trim()
    }

    $tokens = $inputStr.Split(',', [System.StringSplitOptions]::RemoveEmptyEntries)
    foreach ($token in $tokens) {
        $t = $token.Trim()
        if ($t -match '^\d+$') {
            $num = [int]$t
            if ($num -ge 1 -and $num -le $AllItems.Count) {
                [void]$set.Add($AllItems[$num - 1].Id)
            }
        }
        else {
            $match = $AllItems | Where-Object { $_.Id -eq $t -or $_.Name -like "*$t*" } | Select-Object -First 1
            if ($null -ne $match) {
                [void]$set.Add($match.Id)
            }
        }
    }
    return $set
}

function Deploy-DesktopShortcut {
    $scriptDir = "C:\Program Files\Ninite"
    if (-not (Test-Path $scriptDir)) {
        New-Item -ItemType Directory -Path $scriptDir -Force | Out-Null
    }

    $installedScript = Join-Path $scriptDir "Install-NiniteApps.ps1"
    if ($PSCommandPath -and (Test-Path $PSCommandPath) -and ($PSCommandPath -ne $installedScript)) {
        Copy-Item -Path $PSCommandPath -Destination $installedScript -Force
    }

    $desktopDirs = @(
        "C:\Users\Public\Desktop",
        "C:\Users\samuelcaldas\Desktop"
    )

    $pwsh7 = "C:\Program Files\PowerShell\7\pwsh.exe"
    $targetExe = if (Test-Path $pwsh7) { $pwsh7 } else { "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" }
    $wshShell = New-Object -ComObject WScript.Shell

    foreach ($dir in $desktopDirs) {
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        $shortcutPath = Join-Path $dir "Ninite App Store (TUI).lnk"
        $shortcut = $wshShell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = $targetExe
        $shortcut.Arguments = "-NoExit -ExecutionPolicy Bypass -File `"$installedScript`""
        $shortcut.WorkingDirectory = "C:\Program Files\Ninite"
        $shortcut.Description = "Ninite Interactive Package Manager"
        $shortcut.Save()
    }
}

function Main {
    Deploy-DesktopShortcut

    if ($DeployOnly) {
        Write-Host "[SUCCESS] Ninite App Store desktop shortcut deployed." -ForegroundColor Green
        return
    }

    # 1. Non-interactive CLI mode via -Apps argument
    if ($Apps.Count -gt 0) {
        $selected = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($a in $Apps) { [void]$selected.Add($a) }
        Invoke-NiniteInstallation -SelectedIds $selected
        return
    }

    # 2. Preset mode via -Preset argument
    if (-not [string]::IsNullOrWhiteSpace($Preset)) {
        $selected = Get-SelectedFromPreset -PresetName $Preset
        if ($Silent) {
            Invoke-NiniteInstallation -SelectedIds $selected
            return
        }
    }
    else {
        $selected = Get-SelectedFromPreset -PresetName "Minimal"
    }

    # 3. Interactive TUI mode
    $finalSelected = Show-TUI -InitialSelection $selected
    if ($finalSelected.Count -gt 0) {
        Invoke-NiniteInstallation -SelectedIds $finalSelected
    }
    else {
        Write-Host "`n[INFO] Operation cancelled by user." -ForegroundColor Gray
    }
}

Main
