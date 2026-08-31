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

# --- Catalog Definition (sourced from ninite.com, 2026-08-31) ---
$Catalog = @(
    @{
        Category = "Web Browsers"
        Items = @(
            @{ Id = "chrome";          Name = "Chrome";          Desc = "Fast Browser by Google" },
            @{ Id = "operaChromium";   Name = "Opera";           Desc = "Alternative Browser" },
            @{ Id = "firefox";         Name = "Firefox";         Desc = "Extensible Browser" },
            @{ Id = "edge";            Name = "Edge";            Desc = "Microsoft Edge Browser" },
            @{ Id = "brave";           Name = "Brave";           Desc = "Privacy Browser" },
            @{ Id = "vivaldi";         Name = "Vivaldi";         Desc = "Vivaldi Browser" }
        )
    },
    @{
        Category = "Messaging"
        Items = @(
            @{ Id = "zoom";            Name = "Zoom";            Desc = "Video Conference" },
            @{ Id = "discord";         Name = "Discord";         Desc = "Voice and Text Chat" },
            @{ Id = "teams";           Name = "Teams";           Desc = "Video Conferencing, Meetings, Calling" },
            @{ Id = "pidgin";          Name = "Pidgin";          Desc = "Multi-IM Client" },
            @{ Id = "thunderbird";     Name = "Thunderbird";     Desc = "Email Reader by Mozilla" },
            @{ Id = "trillian";        Name = "Trillian";        Desc = "Trillian IM" }
        )
    },
    @{
        Category = "Media"
        Items = @(
            @{ Id = "itunes";          Name = "iTunes";          Desc = "Music/Media Manager" },
            @{ Id = "vlc";             Name = "VLC";             Desc = "Great Video Player" },
            @{ Id = "aimp";            Name = "AIMP";            Desc = "Music Player" },
            @{ Id = "foobar";          Name = "foobar2000";      Desc = "Music Player" },
            @{ Id = "winamp";          Name = "Winamp";          Desc = "Music Player" },
            @{ Id = "musicbee";        Name = "MusicBee";        Desc = "Music Manager & Player" },
            @{ Id = "audacity";        Name = "Audacity";        Desc = "Audio Editor" },
            @{ Id = "klitecodecs";     Name = "K-Lite Codecs";   Desc = "Video decoders plus Media Player Classic" },
            @{ Id = "gom";             Name = "GOM";             Desc = "Video Player" },
            @{ Id = "spotify";         Name = "Spotify";         Desc = "Online Music Service" },
            @{ Id = "cccp";            Name = "CCCP";            Desc = "Video decoders plus MPC" },
            @{ Id = "mediamonkey";     Name = "MediaMonkey";     Desc = "Music Organizer" },
            @{ Id = "handbrake";       Name = "HandBrake";       Desc = "Convert Videos (requires .NET 5)" }
        )
    },
    @{
        Category = ".NET"
        Items = @(
            @{ Id = ".net4.8.1";       Name = ".NET 4.8.1";                     Desc = "Microsoft .NET 4.8.1" },
            @{ Id = ".netx8";          Name = ".NET Desktop Runtime x64 8";     Desc = ".NET Desktop Runtime (x64) 8" },
            @{ Id = ".neta8";          Name = ".NET Desktop Runtime arm64 8";   Desc = ".NET Desktop Runtime (arm64) 8" },
            @{ Id = ".net8";           Name = ".NET Desktop Runtime 8";         Desc = ".NET Desktop Runtime (x86) 8" },
            @{ Id = ".netx9";          Name = ".NET Desktop Runtime x64 9";     Desc = ".NET Desktop Runtime (x64) 9" },
            @{ Id = ".neta9";          Name = ".NET Desktop Runtime arm64 9";   Desc = ".NET Desktop Runtime (arm64) 9" },
            @{ Id = ".net9";           Name = ".NET Desktop Runtime 9";         Desc = ".NET Desktop Runtime (x86) 9" },
            @{ Id = ".netx10";         Name = ".NET Desktop Runtime x64 10";    Desc = ".NET Desktop Runtime (x64) 10" },
            @{ Id = ".neta10";         Name = ".NET Desktop Runtime arm64 10";  Desc = ".NET Desktop Runtime (arm64) 10" },
            @{ Id = ".net10";          Name = ".NET Desktop Runtime 10";        Desc = ".NET Desktop Runtime (x86) 10" },
            @{ Id = "aspnetx8";        Name = "ASP.NET Core Runtime x64 8";    Desc = "ASP.NET Core Runtime (x64) 8" },
            @{ Id = "aspneta8";        Name = "ASP.NET Core Runtime arm64 8";  Desc = "ASP.NET Core Runtime (arm64) 8" },
            @{ Id = "aspnet8";         Name = "ASP.NET Core Runtime 8";        Desc = "ASP.NET Core Runtime (x86) 8" },
            @{ Id = "aspnetx9";        Name = "ASP.NET Core Runtime x64 9";    Desc = "ASP.NET Core Runtime (x64) 9" },
            @{ Id = "aspneta9";        Name = "ASP.NET Core Runtime arm64 9";  Desc = "ASP.NET Core Runtime (arm64) 9" },
            @{ Id = "aspnet9";         Name = "ASP.NET Core Runtime 9";        Desc = "ASP.NET Core Runtime (x86) 9" },
            @{ Id = "aspnetx10";       Name = "ASP.NET Core Runtime x64 10";   Desc = "ASP.NET Core Runtime (x64) 10" },
            @{ Id = "aspneta10";       Name = "ASP.NET Core Runtime arm64 10"; Desc = "ASP.NET Core Runtime (arm64) 10" },
            @{ Id = "aspnet10";        Name = "ASP.NET Core Runtime 10";       Desc = "ASP.NET Core Runtime (x86) 10" }
        )
    },
    @{
        Category = "Java"
        Items = @(
            @{ Id = "adoptjavax8";     Name = "Java (AdoptOpenJDK) x64 8";     Desc = "64-bit Java Runtime (JRE) 8" },
            @{ Id = "adoptjava8";      Name = "Java (AdoptOpenJDK) 8";         Desc = "32-bit Java Runtime (JRE) 8" },
            @{ Id = "adoptjavax11";    Name = "Java (AdoptOpenJDK) x64 11";    Desc = "64-bit Java Runtime (JRE) 11" },
            @{ Id = "adoptjavax17";    Name = "Java (AdoptOpenJDK) x64 17";    Desc = "64-bit Java Runtime (JRE) 17" },
            @{ Id = "adoptjavax21";    Name = "Java (AdoptOpenJDK) x64 21";    Desc = "64-bit Java Runtime (JRE) 21" },
            @{ Id = "adoptjavax25";    Name = "Java (AdoptOpenJDK) x64 25";    Desc = "64-bit Java Runtime (JRE) 25" },
            @{ Id = "adoptjdkx8";      Name = "JDK (AdoptOpenJDK) x64 8";     Desc = "64-bit Java Development Kit 8" },
            @{ Id = "adoptjdk8";       Name = "JDK (AdoptOpenJDK) 8";         Desc = "Java Development Kit 8" },
            @{ Id = "adoptjdkx11";     Name = "JDK (AdoptOpenJDK) x64 11";    Desc = "64-bit Java Development Kit 11" },
            @{ Id = "adoptjdkx17";     Name = "JDK (AdoptOpenJDK) x64 17";    Desc = "64-bit Java Development Kit 17" },
            @{ Id = "adoptjdkx21";     Name = "JDK (AdoptOpenJDK) x64 21";    Desc = "64-bit Java Development Kit 21" },
            @{ Id = "adoptjdkx25";     Name = "JDK (AdoptOpenJDK) x64 25";    Desc = "64-bit Java Development Kit 25" },
            @{ Id = "correttojdkx8";   Name = "JDK (Amazon Corretto) x64 8";  Desc = "64-bit Java Development Kit 8" },
            @{ Id = "correttojdk8";    Name = "JDK (Amazon Corretto) 8";      Desc = "Java Development Kit 8" },
            @{ Id = "correttojdkx11";  Name = "JDK (Amazon Corretto) x64 11"; Desc = "64-bit Java Development Kit 11" },
            @{ Id = "correttojdkx17";  Name = "JDK (Amazon Corretto) x64 17"; Desc = "64-bit Java Development Kit 17" },
            @{ Id = "correttojdkx21";  Name = "JDK (Amazon Corretto) x64 21"; Desc = "64-bit Java Development Kit 21" },
            @{ Id = "correttojdkx25";  Name = "JDK (Amazon Corretto) x64 25"; Desc = "64-bit Java Development Kit 25" },
            @{ Id = "correttojrex8";   Name = "JRE (Amazon Corretto) x64 8";  Desc = "64-bit Java Runtime Environment 8" },
            @{ Id = "correttojre8";    Name = "JRE (Amazon Corretto) 8";      Desc = "Java Runtime Environment 8" }
        )
    },
    @{
        Category = "Imaging"
        Items = @(
            @{ Id = "krita";           Name = "Krita";           Desc = "Painting Program" },
            @{ Id = "blender";         Name = "Blender";         Desc = "3D Creation Suite" },
            @{ Id = "paint.net";       Name = "Paint.NET";       Desc = "Image Editor (requires .NET 4.5)" },
            @{ Id = "gimp";            Name = "GIMP";            Desc = "Open Source Image Editor" },
            @{ Id = "irfanview";       Name = "IrfanView";       Desc = "Image Viewer" },
            @{ Id = "xnview";          Name = "XnView";          Desc = "Image Viewer" },
            @{ Id = "inkscape";        Name = "Inkscape";        Desc = "Vector Graphics Editor" },
            @{ Id = "faststone";       Name = "FastStone";       Desc = "FastStone Image Viewer" },
            @{ Id = "greenshot";       Name = "Greenshot";       Desc = "Screenshot Tool" },
            @{ Id = "sharex";          Name = "ShareX";          Desc = "Screenshot Uploader" }
        )
    },
    @{
        Category = "Documents"
        Items = @(
            @{ Id = "foxit";           Name = "Foxit Reader";    Desc = "Alternative PDF Reader" },
            @{ Id = "libreoffice";     Name = "LibreOffice";     Desc = "Free Office Suite" },
            @{ Id = "sumatrapdf";      Name = "SumatraPDF";      Desc = "Lightweight PDF Reader" },
            @{ Id = "cutepdf";         Name = "CutePDF";         Desc = "Print Documents as PDF Files" },
            @{ Id = "openoffice";      Name = "OpenOffice";      Desc = "Free Office Suite (JRE recommended)" }
        )
    },
    @{
        Category = "Security"
        Items = @(
            @{ Id = "malwarebytes";    Name = "Malwarebytes";    Desc = "Malware Remover" },
            @{ Id = "avast";           Name = "Avast";           Desc = "Avast Free Antivirus" },
            @{ Id = "avg";             Name = "AVG";             Desc = "AVG Free Antivirus" },
            @{ Id = "spybot2";         Name = "Spybot 2";        Desc = "Spyware Remover" },
            @{ Id = "avira";           Name = "Avira";           Desc = "Avira Free Antivirus" },
            @{ Id = "super";           Name = "SUPERAntiSpyware"; Desc = "SUPERAntiSpyware Free" }
        )
    },
    @{
        Category = "File Sharing"
        Items = @(
            @{ Id = "qbittorrent";     Name = "qBittorrent";     Desc = "Free Bittorrent Client" }
        )
    },
    @{
        Category = "Online Storage"
        Items = @(
            @{ Id = "dropbox";              Name = "Dropbox";                Desc = "Great Online Backup/File Sync" },
            @{ Id = "googledrivefordesktop"; Name = "Google Drive for Desktop"; Desc = "Online File Sync" },
            @{ Id = "onedrive";             Name = "OneDrive";               Desc = "Online File Sync by Microsoft" },
            @{ Id = "sugarsync";            Name = "SugarSync";              Desc = "Online Backup/File Sync" }
        )
    },
    @{
        Category = "Other"
        Items = @(
            @{ Id = "evernote";        Name = "Evernote";           Desc = "Online Notes" },
            @{ Id = "googleearth";     Name = "Google Earth";        Desc = "Online Atlas by Google" },
            @{ Id = "steam";           Name = "Steam";               Desc = "App Store for Games" },
            @{ Id = "epic";            Name = "Epic Games Launcher"; Desc = "Epic Games Store" },
            @{ Id = "keepass2";        Name = "KeePass 2";           Desc = "Password Manager" },
            @{ Id = "everything";      Name = "Everything";          Desc = "Local File Search Engine" },
            @{ Id = "nvda";            Name = "NV Access";           Desc = "Screen Reader" }
        )
    },
    @{
        Category = "Utilities"
        Items = @(
            @{ Id = "anydesk";         Name = "AnyDesk";         Desc = "Remote Desktop" },
            @{ Id = "teamviewer15";    Name = "TeamViewer 15";   Desc = "Remote Access Tool" },
            @{ Id = "imgburn";         Name = "ImgBurn";         Desc = "Disc Burner" },
            @{ Id = "realvncserver";   Name = "RealVNC Server";  Desc = "RealVNC Remote Access" },
            @{ Id = "realvncviewer";   Name = "RealVNC Viewer";  Desc = "RealVNC Remote Access" },
            @{ Id = "tightvnc";        Name = "TightVNC";        Desc = "TightVNC Remote Desktop Software" },
            @{ Id = "teracopy";        Name = "TeraCopy";        Desc = "Better File Copy" },
            @{ Id = "cdburnerxp";      Name = "CDBurnerXP";      Desc = "Disc Burner (requires .NET)" },
            @{ Id = "revo";            Name = "Revo";            Desc = "App Uninstaller/Reverse Ninite" },
            @{ Id = "launchy";         Name = "Launchy";         Desc = "Hotkey Launcher" },
            @{ Id = "windirstat";      Name = "WinDirStat";      Desc = "Directory Statistics" },
            @{ Id = "wiztree";         Name = "WizTree";         Desc = "Directory Statistics" },
            @{ Id = "glary";           Name = "Glary";           Desc = "System Utilities" },
            @{ Id = "infrarecorder";   Name = "InfraRecorder";   Desc = "Disc Burner" },
            @{ Id = "openshell";       Name = "Open-Shell";      Desc = "Old-Style Start Menu" },
            @{ Id = "ccleaner";        Name = "CCleaner";        Desc = "PC Crap Remover" }
        )
    },
    @{
        Category = "Compression"
        Items = @(
            @{ Id = "7zip";            Name = "7-Zip";           Desc = "Great Compression App" },
            @{ Id = "peazip";          Name = "PeaZip";          Desc = "File Compression Tool" },
            @{ Id = "winrar";          Name = "WinRAR";          Desc = "Another Compression Tool (Trial)" }
        )
    },
    @{
        Category = "VC++ Redistributables"
        Items = @(
            @{ Id = "vcredistx15";     Name = "VC Redist x64 2015+";   Desc = "Microsoft C and C++ (MSVC) runtime libraries" },
            @{ Id = "vcredist15";      Name = "VC Redist x86 2015+";   Desc = "Microsoft C and C++ (MSVC) runtime libraries" },
            @{ Id = "vcredistarm15";   Name = "VC Redist arm64 2015+"; Desc = "Microsoft C and C++ (MSVC) runtime libraries" },
            @{ Id = "vcredistx13";     Name = "VC Redist x64 2013";    Desc = "Microsoft C and C++ (MSVC) runtime libraries" },
            @{ Id = "vcredist13";      Name = "VC Redist x86 2013";    Desc = "Microsoft C and C++ (MSVC) runtime libraries" },
            @{ Id = "vcredistx12";     Name = "VC Redist x64 2012";    Desc = "Microsoft C and C++ (MSVC) runtime libraries" },
            @{ Id = "vcredist12";      Name = "VC Redist x86 2012";    Desc = "Microsoft C and C++ (MSVC) runtime libraries" },
            @{ Id = "vcredistx10";     Name = "VC Redist x64 2010";    Desc = "Microsoft C and C++ (MSVC) runtime libraries" },
            @{ Id = "vcredist10";      Name = "VC Redist x86 2010";    Desc = "Microsoft C and C++ (MSVC) runtime libraries" },
            @{ Id = "vcredistx08";     Name = "VC Redist x64 2008";    Desc = "Microsoft C and C++ (MSVC) runtime libraries" },
            @{ Id = "vcredist08";      Name = "VC Redist x86 2008";    Desc = "Microsoft C and C++ (MSVC) runtime libraries" },
            @{ Id = "vcredistx05";     Name = "VC Redist x64 2005";    Desc = "Microsoft C and C++ (MSVC) runtime libraries" },
            @{ Id = "vcredist05";      Name = "VC Redist x86 2005";    Desc = "Microsoft C and C++ (MSVC) runtime libraries" }
        )
    },
    @{
        Category = "Developer Tools"
        Items = @(
            @{ Id = "pythonx3";        Name = "Python x64 3";        Desc = "Programming Language x64" },
            @{ Id = "pythona3";        Name = "Python arm64 3";      Desc = "Programming Language arm64" },
            @{ Id = "python3";         Name = "Python 3";            Desc = "Programming Language x86" },
            @{ Id = "python";          Name = "Python 2";            Desc = "Great Programming Language 2.7" },
            @{ Id = "git";             Name = "Git";                 Desc = "Version Control System" },
            @{ Id = "filezilla";       Name = "FileZilla";           Desc = "FTP Client" },
            @{ Id = "notepadplusplus"; Name = "Notepad++";           Desc = "Programmer's Editor" },
            @{ Id = "winscp";          Name = "WinSCP";              Desc = "SCP Client" },
            @{ Id = "putty";           Name = "PuTTY";               Desc = "SSH client" },
            @{ Id = "winmerge";        Name = "WinMerge";            Desc = "Compare and Merge Files" },
            @{ Id = "eclipse";         Name = "Eclipse";             Desc = "IDE for Java (requires Java)" },
            @{ Id = "vscode";          Name = "Visual Studio Code";  Desc = "Programmer's Editor" },
            @{ Id = "cursor";          Name = "Cursor";              Desc = "Programmer's Editor (AI)" }
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

# ponytail: static catalog — update from ninite.com HTML when major apps are added
$dupes = $AllItems | Group-Object Id | Where-Object { $_.Count -gt 1 }
if ($dupes) { throw "Duplicate catalog slugs: $($dupes.Name -join ', ')" }

$PresetsMap = @{
    "DevStack"  = @("vscode", "notepadplusplus", "7zip", "putty", "winscp", "git", "pythonx3", "cursor")
    "Browsers"  = @("chrome", "firefox")
    "Minimal"   = @("7zip", "notepadplusplus", "chrome")
    "Utilities" = @("7zip", "windirstat", "wiztree", "everything", "teracopy", "ccleaner")
    "Media"     = @("vlc", "foobar", "audacity", "greenshot", "spotify")
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

function Read-SearchString {
    # Inline readline for '/' search — backspace + enter/esc to confirm
    $buf = ""
    [Console]::Write("Search: ")
    while ($true) {
        $k = [Console]::ReadKey($true)
        if ($k.Key -eq [ConsoleKey]::Enter -or $k.Key -eq [ConsoleKey]::Escape) { break }
        if ($k.Key -eq [ConsoleKey]::Backspace) {
            if ($buf.Length -gt 0) {
                $buf = $buf.Substring(0, $buf.Length - 1)
                [Console]::Write("`b `b")
            }
        }
        elseif ($k.KeyChar -match '\S') {
            $buf += $k.KeyChar
            [Console]::Write($k.KeyChar)
        }
    }
    [Console]::WriteLine()
    return $buf
}

function Get-FilteredItems {
    param([string]$Filter, [System.Collections.Generic.List[PSObject]]$Items)
    if ([string]::IsNullOrWhiteSpace($Filter)) { return $Items }
    $f = $Filter.ToLower()
    return @($Items | Where-Object {
        $_.Id.ToLower().Contains($f) -or $_.Name.ToLower().Contains($f) -or $_.Category.ToLower().Contains($f)
    })
}

function Show-TUI {
    param(
        [System.Collections.Generic.HashSet[string]]$InitialSelection
    )

    $selected = [System.Collections.Generic.HashSet[string]]::new($InitialSelection, [System.StringComparer]::OrdinalIgnoreCase)
    $cursor = 0
    $searchFilter = ""
    $visibleItems = $AllItems
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
            $total = $visibleItems.Count
            if ($cursor -ge $total -and $total -gt 0) { $cursor = $total - 1 }

            Clear-Host
            Write-Host "================================================================================" -ForegroundColor Cyan
            Write-Host "            NINITE INTERACTIVE PACKAGE MANAGER (Windows Server Core)           " -ForegroundColor Cyan
            Write-Host "================================================================================" -ForegroundColor Cyan
            Write-Host " [?] Up/Down (j/k) | [Space] Toggle | [a] All | [n] None | [p] Preset" -ForegroundColor Gray
            Write-Host "     [/] Search | [Enter] Install | [q/Esc] Quit" -ForegroundColor Gray
            Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray

            $lastCat = ""
            for ($i = 0; $i -lt $total; $i++) {
                $item = $visibleItems[$i]
                if ($item.Category -ne $lastCat) {
                    Write-Host "`n  :: $($item.Category)" -ForegroundColor Yellow
                    $lastCat = $item.Category
                }

                $isCursor   = ($i -eq $cursor)
                $isSelected = $selected.Contains($item.Id)

                $checkMark = if ($isSelected) { "[x]" } else { "[ ]" }
                $pointer   = if ($isCursor)   { ">" }   else { " " }

                $lineText = "  $pointer $checkMark {0,-24} - {1}" -f $item.Id, $item.Desc

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

            if ($total -eq 0) {
                Write-Host "`n  (no matches)" -ForegroundColor DarkGray
            }

            Write-Host "`n--------------------------------------------------------------------------------" -ForegroundColor DarkGray
            $selCount   = $selected.Count
            $selPreview = if ($selCount -gt 0) { ($selected | Sort-Object) -join ' ' } else { "None" }
            Write-Host " Selected ($selCount apps): " -NoNewline -ForegroundColor Cyan
            Write-Host "$selPreview" -ForegroundColor Green
            if (-not [string]::IsNullOrWhiteSpace($searchFilter)) {
                Write-Host " Filter: `"$searchFilter`" (press / to change, empty input to clear)" -ForegroundColor Magenta
            }
            Write-Host " > Press [ENTER] to download & install selected packages now..." -ForegroundColor Yellow

            $keyInfo = [Console]::ReadKey($true)

            switch ($keyInfo.Key) {
                ([ConsoleKey]::UpArrow)   { $cursor = [Math]::Max(0, $cursor - 1) }
                ([ConsoleKey]::DownArrow) { $cursor = [Math]::Min($total - 1, $cursor + 1) }
                ([ConsoleKey]::K)         { $cursor = [Math]::Max(0, $cursor - 1) }
                ([ConsoleKey]::J)         { $cursor = [Math]::Min($total - 1, $cursor + 1) }
                ([ConsoleKey]::Spacebar) {
                    if ($total -gt 0) {
                        $currId = $visibleItems[$cursor].Id
                        if ($selected.Contains($currId)) {
                            [void]$selected.Remove($currId)
                        }
                        else {
                            [void]$selected.Add($currId)
                        }
                    }
                }
                ([ConsoleKey]::A) {
                    foreach ($it in $visibleItems) { [void]$selected.Add($it.Id) }
                }
                ([ConsoleKey]::N) {
                    $selected.Clear()
                }
                ([ConsoleKey]::P) {
                    $pName = $presetKeys[$presetIndex % $presetKeys.Count]
                    $presetIndex++
                    $selected = Get-SelectedFromPreset -PresetName $pName
                }
                ([ConsoleKey]::OemQuestion) {
                    # '/' — enter search mode
                    [Console]::CursorVisible = $true
                    $searchFilter = Read-SearchString
                    [Console]::CursorVisible = $false
                    $visibleItems = Get-FilteredItems -Filter $searchFilter -Items $AllItems
                    $cursor = 0
                }
                ([ConsoleKey]::Escape) {
                    if (-not [string]::IsNullOrWhiteSpace($searchFilter)) {
                        # First Esc clears search
                        $searchFilter = ""
                        $visibleItems = $AllItems
                        $cursor = 0
                    }
                    else {
                        return [System.Collections.Generic.HashSet[string]]::new()
                    }
                }
                ([ConsoleKey]::Enter) {
                    return $selected
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
    Write-Host "            NINITE PACKAGE SELECTION (Console Fallback Mode)                   " -ForegroundColor Cyan
    Write-Host "================================================================================" -ForegroundColor Cyan

    for ($i = 0; $i -lt $AllItems.Count; $i++) {
        $it = $AllItems[$i]
        $idx = "{0,3}" -f ($i + 1)
        Write-Host " [$idx] {0,-24} - {1}" -f $it.Id, $it.Name -ForegroundColor White
    }

    Write-Host "`nPresets: DevStack, Browsers, Minimal, Utilities, Media, All" -ForegroundColor Yellow
    Write-Host "Enter numbers or IDs separated by commas (or type a preset name, 'q' to exit):" -ForegroundColor Cyan
    $inputStr = Read-Host "Selection"

    if ([string]::IsNullOrWhiteSpace($inputStr) -or $inputStr.Trim().ToLower() -eq 'q') {
        return [System.Collections.Generic.HashSet[string]]::new()
    }

    if ($PresetsMap.ContainsKey($inputStr.Trim())) {
        return Get-SelectedFromPreset -PresetName $inputStr.Trim()
    }

    $set = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
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

    $publicDesktop = "C:\Users\Public\Desktop"
    if (-not (Test-Path $publicDesktop)) {
        New-Item -ItemType Directory -Path $publicDesktop -Force | Out-Null
    }

    # Clean up duplicate shortcuts from individual user desktop directories
    $userDirs = @("C:\Users\samuelcaldas\Desktop", "C:\Users\Administrator\Desktop")
    foreach ($uDir in $userDirs) {
        if (Test-Path $uDir) {
            Get-ChildItem -Path $uDir -Filter "Ninite App Store*.lnk" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
        }
    }
    $legacyPublic = Join-Path $publicDesktop "Ninite App Store (TUI).lnk"
    if (Test-Path $legacyPublic) { Remove-Item -Path $legacyPublic -Force -ErrorAction SilentlyContinue }

    $pwsh7 = "C:\Program Files\PowerShell\7\pwsh.exe"
    $targetExe = if (Test-Path $pwsh7) { $pwsh7 } else { "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" }
    $wshShell = New-Object -ComObject WScript.Shell

    $shortcutPath = Join-Path $publicDesktop "Ninite App Store.lnk"
    $shortcut = $wshShell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $targetExe
    $shortcut.Arguments = "-NoExit -ExecutionPolicy Bypass -File `"$installedScript`""
    $shortcut.WorkingDirectory = "C:\Program Files\Ninite"
    $shortcut.Description = "Ninite Interactive Package Manager"
    $shortcut.Save()
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
