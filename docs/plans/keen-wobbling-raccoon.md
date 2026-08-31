# Plan: Expand Ninite Catalog & Add Search Engine

## Context

`Install-NiniteApps.ps1` (guest) currently has a hand-curated catalog of ~30 apps across 6 categories. The Ninite website now offers **~100+ apps across 13 categories**. The host scripts (`install-ninite.sh`, `install-ninite.ps1`) just orchestrate deployment; only the guest script needs catalog changes. The task is:

1. Replace the partial catalog with all apps from the HTML dump (categories, slugs, display names, descriptions).
2. Add an incremental search mode so users can filter by name/slug/category without scrolling 100 entries.

---

## Files to Modify

- **`scripts/guest/Install-NiniteApps.ps1`** — only file that changes. Host orchestrators are untouched; they deploy whatever is in the guest script.

---

## Approach

### 1. Expand `$Catalog` to all Ninite apps

Parse slugs, names, descriptions, and categories from the provided HTML. Full catalog:

| Category | Slugs |
|---|---|
| Web Browsers | chrome, operaChromium, firefox, edge, brave, vivaldi |
| Messaging | zoom, discord, teams, pidgin, thunderbird, trillian |
| Media | itunes, vlc, aimp, foobar, winamp, musicbee, audacity, klitecodecs, gom, spotify, cccp, mediamonkey, handbrake |
| .NET | .net4.8.1, .netx8, .neta8, .net8, .netx9, .neta9, .net9, .netx10, .neta10, .net10, aspnetx8, aspneta8, aspnet8, aspnetx9, aspneta9, aspnet9, aspnetx10, aspneta10, aspnet10 |
| Java | adoptjavax8, adoptjava8, adoptjavax11, adoptjavax17, adoptjavax21, adoptjavax25, adoptjdkx8, adoptjdk8, adoptjdkx11, adoptjdkx17, adoptjdkx21, adoptjdkx25, correttojdkx8, correttojdk8, correttojdkx11, correttojdkx17, correttojdkx21, correttojdkx25, correttojrex8, correttojre8 |
| Imaging | krita, blender, paint.net, gimp, irfanview, xnview, inkscape, faststone, greenshot, sharex |
| Documents | foxit, libreoffice, sumatrapdf, cutepdf, openoffice |
| Security | malwarebytes, avast, avg, spybot2, avira, super |
| File Sharing | qbittorrent |
| Online Storage | dropbox, googledrivefordesktop, onedrive, sugarsync |
| Other | evernote, googleearth, steam, epic, keepass2, everything, nvda |
| Utilities | anydesk, teamviewer15, imgburn, realvncserver, realvncviewer, tightvnc, teracopy, cdburnerxp, revo, launchy, windirstat, wiztree, glary, infrarecorder, openshell, ccleaner |
| Compression | 7zip, peazip, winrar |
| VC++ Redistributables | vcredistx15, vcredist15, vcredistarm15, vcredistx13, vcredist13, vcredistx12, vcredist12, vcredistx10, vcredist10, vcredistx08, vcredist08, vcredistx05, vcredist05 |
| Developer Tools | pythonx3, pythona3, python3, python, git, filezilla, notepadplusplus, winscp, putty, winmerge, eclipse, vscode, cursor |

Fix two stale slugs in current catalog: `opera` → `operaChromium`, `python` (was Python 3) → `pythonx3`, `jdk17` → `adoptjdkx17`, `realvnc` → `realvncviewer`.

### 2. Add search mode to TUI

Add a `/` keybinding in the TUI loop. When pressed:
- Print a `Search: ` prompt at the bottom of the screen (after the current status bar).
- Read a search string from `[Console]::ReadKey` one character at a time (backspace support). `Enter` confirms, `Esc` cancels.
- Set `$searchFilter` string; re-render loop filters `$AllItems` to only items where `Id`, `Name`, or `Category` contains the filter (case-insensitive).
- Reset cursor to 0 on filter change.
- Show the filter string in the status bar (`Filter: "<term>"`) when active. Press `/` again with empty input or `Esc` to clear.

This keeps the existing render loop and key-handling `switch`; search is just an overlay that shrinks `$visible` items.

### 3. Update presets

Update `$PresetsMap` to use correct slugs and add a few new preset entries:
- `"DevStack"` → add `git`, `vscode`, use `pythonx3` not `python`/`jdk17`
- `"Browsers"` — unchanged
- `"Minimal"` — unchanged
- `"Utilities"` — add `wiztree`, `ccleaner`
- `"Media"` — add `vlc`, `foobar`, `audacity`
- `"All"` — auto-derived from catalog (unchanged logic)

### 4. Fix `Show-FallbackMenu` search

The fallback numeric/ID menu already works. After catalog expansion it will auto-show all 100 apps — add the same name-fuzzy search (already present: `$_.Name -like "*$t*"`). No change needed.

---

## Implementation Details

### Search state in `Show-TUI`

Add two variables at the top of `Show-TUI`:
```powershell
$searchFilter = ""
$visibleItems = $AllItems  # updated whenever $searchFilter changes
```

Replace `$total = $AllItems.Count` with `$total = $visibleItems.Count`, and `$AllItems[$i]` with `$visibleItems[$i]`.

Add a helper:
```powershell
function Update-Visible {
    param([string]$Filter, [array]$Items)
    if ([string]::IsNullOrWhiteSpace($Filter)) { return $Items }
    $f = $Filter.ToLower()
    return @($Items | Where-Object { $_.Id.ToLower() -contains $f -or $_.Name.ToLower() -contains $f -or $_.Category.ToLower() -contains $f })
}
```

Add `/` key handler in the switch:
```powershell
([ConsoleKey]::OemQuestion) {  # '/' key
    $searchFilter = Read-SearchString   # inline readline-like input
    $visibleItems = Update-Visible -Filter $searchFilter -Items $AllItems
    $cursor = 0
}
```

Add `Read-SearchString` function (reads chars, supports backspace, Enter/Esc):
```powershell
function Read-SearchString {
    $buf = ""
    while ($true) {
        $k = [Console]::ReadKey($true)
        if ($k.Key -eq [ConsoleKey]::Enter -or $k.Key -eq [ConsoleKey]::Escape) { break }
        if ($k.Key -eq [ConsoleKey]::Backspace -and $buf.Length -gt 0) { $buf = $buf.Substring(0, $buf.Length - 1) }
        elseif ($k.KeyChar -match '\S') { $buf += $k.KeyChar }
    }
    return $buf
}
```

Show filter in status bar when active:
```powershell
if ($searchFilter) {
    Write-Host " Filter: `"$searchFilter`" (/ to change, Esc to clear)" -ForegroundColor Magenta
}
```

---

## What's Skipped

- No icons, version strings, or live Ninite API calls — catalog is static strings. Add when Ninite exposes a machine-readable API.
- No pagination — 100 items will scroll off-screen on short terminals. Add page-chunking when users report it's needed.

---

## Verification

```powershell
# On Windows guest, run:
pwsh -ExecutionPolicy Bypass -File 'C:\Program Files\Ninite\Install-NiniteApps.ps1'
# 1. Verify all categories appear in TUI with correct item count (~100 apps)
# 2. Press '/' and type "python" — confirm only Python variants are shown
# 3. Press '/' and type "net" — confirm .NET + ASP.NET entries appear
# 4. Press Esc, confirm full list restored
# 5. Select 'vscode' + '7zip', press Enter — confirm Ninite URL built correctly: https://ninite.com/7zip-vscode/ninite.exe

# From host, run dry-run (no actual install):
./scripts/host/install-ninite.sh --preset DevStack
# Confirm SSH + deployment succeed without errors
```

Self-check assertion (paste at bottom of script for one run):
```powershell
# ponytail: remove after first run / before shipping
$slugs = $AllItems | ForEach-Object { $_.Id }
$dupes = $slugs | Group-Object | Where-Object { $_.Count -gt 1 }
if ($dupes) { throw "Duplicate slugs: $($dupes.Name -join ', ')" }
Write-Host "Catalog OK: $($AllItems.Count) apps across $((($AllItems | Select-Object Category -Unique).Count)) categories" -ForegroundColor Green
```
