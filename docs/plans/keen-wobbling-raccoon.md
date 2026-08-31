# Architecture & Engineering Plan: OmniGet (`og`) — The Universal Multi-Source Package Engine for Windows

## Context & Objectives

The goal is to extract and elevate the software installer logic from disconnected guest scripts (`Install-Tools.ps1`, `Install-DesktopShell.ps1`, `Install-WindowsTerminal.ps1`, `Setup-Agents.ps1`, `Update-HostsBlocklist.ps1`, `Install-NiniteApps.ps1`) into a **standalone, modular, public open-source project named `OmniGet` (CLI alias: `og` or `omniget`)**.

`OmniGet` will be hosted on GitHub under `github.com/samuelcaldas/omniget` (public repository) and integrated into `windows-core` as a **git submodule** at `external/omniget`. 

### Key Requirements
1. **Generic Windows Store**: OmniGet is built for *any* Windows version (Windows 10, 11, Server, and Server Core), without hardcoded references to Windows Core in its generic UI/copy.
2. **Pluggable Provider Architecture**: Implements Strategy & Factory Design Patterns in PowerShell 7 (`IProvider` contract) with support for:
   - **`Ninite` Provider**: Dynamic multi-app single-binary bundle builder with all 142 apps.
   - **`Direct` / `GitHub` Provider**: Standalone release downloader and silent installer for official MSI/EXE/ZIP packages (.NET SDK, Git, GitHub CLI, Node.js, Python, Docker CLI, WezTerm, VC++ Redistributable, OpenSSH).
   - **`Distro` / `Recipes` Provider**: System components, Win32 desktop shells (WinXShell, ReactShell, WinFile, Explorer++), VirtIO guest agent & drivers, Dan Pollock DNS blocklist, and system specialization tweaks.
   - **`Community` Provider (Scoop / Chocolatey / WinGet)**: Dynamic fallback when package managers are available on guest (with awareness that WinGet/MSIX is not native on Windows Core).
   - **`Npm` / `Pip` Provider**: Global developer tool runner (@anthropic-ai/claude-code, etc.).
3. **Modern ANSI Multi-Panel TUI for PS7**:
   - Clean, high-performance TUI with keyboard shortcuts (`Tab` for Sources/Tabs, `/` for Search, `Space` for Toggle, `p` for Presets, `Enter` for Install, `q` for Quit).
   - **Home / Featured View**: Shows only most popular, curated apps and essential desktop/dev packages.
   - **Source-Filtered Views**: Switching source (e.g. `[Ninite]`, `[GitHub]`, `[Distro]`, `[All]`) displays all packages available under that provider.
   - **Incremental Search (`/`)**: Searches across all 180+ packages across all providers simultaneously.
4. **Clean Decoupling from `windows-core`**:
   - Move deprecated standalone installers from `scripts/guest/` into `external/omniget`.
   - Provide lightweight wrapper entrypoints in `scripts/guest/` (`Install-OmniGet.ps1` or `Launch-OmniGet.ps1`) and in `scripts/host/` (`install-omniget.sh` / `.ps1`).
   - Update `sconfig` Control Center module (`mod-tools.ps1`) to use `OmniGet`.

---

## 1. Project Naming, Branding & CLI Specification

- **Project Name**: `OmniGet`
- **Short Name / Description**: *The Lean, Multi-Source Universal Package Engine for Windows.*
- **Tagline**: *One command, all sources. Ninite, GitHub Releases, Standalone Toolchains, Shells, and Distro Recipes united.*
- **CLI Commands & Aliases**:
  - Primary executable: `omniget`
  - Compact alias: `og` (verified conflict-free on Windows and Linux)
  - Secondary alias: `om`
- **Branding Palette**:
  - Primary Accent: Cyan (`#00FFFF` / ANSI 14)
  - Success: Green (`#00FF00` / ANSI 10)
  - Warning/Preset: Yellow (`#FFFF00` / ANSI 11)
  - Source Badges:
    - `[Ninite]`  -> Light Magenta
    - `[GitHub]`  -> Bright Blue
    - `[Distro]`  -> Cyan
    - `[Direct]`  -> White
    - `[NPM]`     -> Red

### CLI Command Syntax
```powershell
# Interactive Mode (Full ANSI TUI)
og
omniget

# Direct Package Installation
og install <package-id> [<package-id>...] [-Silent] [-Force]
og install vscode git nodejs docker-cli winxshell -Silent

# Presets
og preset DevStack -Silent
og preset Browsers
og preset SystemShells

# Search & Info
og search python
og info docker-cli
og list [--source ninite|github|distro|all]
```

---

## 2. Directory Structure & Submodule Architecture

### Repository 1: `samuelcaldas/omniget` (New Public Repository & Submodule)
```
omniget/
├── manifests/                        # Declarative package catalog & recipe definitions
│   ├── featured.json                 # Curated apps shown on Home Page
│   ├── ninite.json                   # 142 Ninite application definitions
│   ├── github.json                   # GitHub Releases tools (pwsh, gh, git, docker-compose, wezterm, etc.)
│   ├── direct.json                   # Direct official downloads (Node.js, Python, .NET SDK, vc_redist)
│   ├── distro.json                   # Shells, WinFile, Explorer++, VirtIO, Dan Pollock Hosts, Antigravity
│   └── presets.json                  # Curated bundles (DevStack, Minimal, Browsers, Utilities, etc.)
├── src/
│   ├── OmniGet.psd1                  # PowerShell Module Manifest
│   ├── OmniGet.psm1                  # Core Module entrypoint & exports
│   ├── OmniGet.ps1                   # Standalone self-contained CLI launcher
│   ├── Core/
│   │   ├── Engine.ps1                # Orchestrates provider resolution, dependencies, and batching
│   │   ├── Environment.ps1           # Machine PATH management, shortcut creation, environment sync
│   │   ├── Downloader.ps1            # Fast multi-threaded curl.exe / WebClient downloader
│   │   └── ManifestReader.ps1        # Loads, merges, and validates JSON/HashTable manifests
│   ├── Providers/
│   │   ├── BaseProvider.ps1          # Abstract Provider contract (IProvider)
│   │   ├── NiniteProvider.ps1        # Dynamic URL bundle creator & silent execution
│   │   ├── DirectProvider.ps1        # MSI / InnoSetup / Standalone executable executor
│   │   ├── GitHubReleaseProvider.ps1 # GitHub Release asset resolution & extraction
│   │   ├── DistroRecipeProvider.ps1  # Shells, hardlinks, hosts, and driver installation recipes
│   │   └── NpmProvider.ps1           # Global npm packages (claude-code)
│   └── UI/
│       ├── TuiApp.ps1                # Main ANSI Curses-style interactive loop
│       ├── Layout.ps1                # Header, Status bar, Provider Tabs, and Item Grid
│       └── SearchEngine.ps1          # Live incremental fuzzy filtering
├── bin/
│   ├── og.cmd                        # Windows Command Prompt launcher stub
│   ├── og.ps1                        # PowerShell launcher alias
│   └── omniget.cmd                   # Full name launcher stub
├── README.md                         # Rich GitHub landing page with demo GIF, documentation, and badges
└── LICENSE                           # MIT License
```

### Integration in `windows-core`:
```
windows-core/
├── external/
│   ├── Atlas/
│   ├── ReactShell/
│   ├── winfile/
│   └── omniget/                     # Git submodule -> https://github.com/samuelcaldas/omniget.git
├── scripts/
│   ├── guest/
│   │   ├── Install-OmniGet.ps1       # Deploys OmniGet to C:\Program Files\OmniGet, registers PATH & desktop shortcut
│   │   ├── Install-Tools.ps1         # Refactored: delegates toolchain install to `og preset DevStack -Silent`
│   │   └── sconfig/modules/
│   │       └── mod-tools.ps1         # Launches `og` interactive store
│   └── host/
│       ├── install-omniget.sh        # Host orchestrator to deploy and run OmniGet over SSH
│       └── install-omniget.ps1       # Host PowerShell orchestrator
```

---

## 3. Pluggable Provider Architecture & Design Patterns

### 3.1 Design Patterns
1. **Strategy Pattern (`IProvider`)**: Each provider implements a common execution interface:
   - `[bool] CanHandle([Package]$pkg)`
   - `[PackageAudit] AuditStatus([Package]$pkg)` -> detects if already installed and version
   - `[InstallResult] Install([Package[]]$packages, [bool]$silent, [bool]$force)`
2. **Factory Pattern (`ProviderFactory`)**: Resolves the appropriate provider dynamically based on package metadata (`Source: "ninite" | "github" | "direct" | "distro" | "npm"`).
3. **Composite Batching**:
   - Groups all selected `ninite` packages into a single batch download URL (`https://ninite.com/app1-app2-.../ninite.exe`).
   - Executes `direct`, `github`, and `distro` recipes sequentially with clean rollback and temporary file cleanup.
4. **Declarative Manifests**: Packages are defined with unified schema:
   ```json
   {
     "id": "docker-cli",
     "name": "Docker CLI & Compose",
     "category": "Developer Tools",
     "source": "distro",
     "version": "27.5.1",
     "desc": "Standalone native client without Docker Desktop overhead",
     "recipe": "Install-DockerCli"
   }
   ```

---

## 4. Modern ANSI TUI Experience for PowerShell 7

### Key Elements of the TUI:
- **Header**: OmniGet version, total package count, active tab/source.
- **Top Navigation Bar (Tabs)**:
  - `[1] Home (Featured)`
  - `[2] All Packages (180+)`
  - `[3] Ninite (142 apps)`
  - `[4] Developer & CLI`
  - `[5] System Shells & GUI`
  - `[6] Utilities & Media`
- **Dynamic Search (`/`)**: Inline prompt at bottom; live filters across `Id`, `Name`, `Category`, `Provider`, and `Description`.
- **Package List Area**:
  - `>` Cursor indicator with high-contrast active background
  - `[x]` / `[ ]` Checkboxes for multi-selection
  - `[Source]` Colored Badge (`[Ninite]`, `[GitHub]`, `[Distro]`, `[Direct]`)
  - Status indicators: `✓ Installed (v2.46.0)` or `Available`
- **Details Pane**: Shows expanded description, publisher, source type, and target installation path for the currently focused item.
- **Status Bar**: Selected count, summary of selected packages, and active keyboard shortcuts.

---

## 5. Migration Plan & Step-by-Step Execution Sequence

### Phase 1: Create OmniGet Standalone Repository
1. Initialize local repository structure in temporary build directory.
2. Implement core engine (`OmniGet.psm1`, `Engine.ps1`, `Downloader.ps1`, `Environment.ps1`).
3. Implement Providers (`NiniteProvider`, `DirectProvider`, `GitHubReleaseProvider`, `DistroRecipeProvider`, `NpmProvider`).
4. Build declarative catalogs in `manifests/` (including all 142 Ninite apps, dev tools, shells, terminal, adblock, virtio).
5. Implement ANSI Multi-Panel TUI in `UI/TuiApp.ps1` with tab navigation and incremental search.
6. Add CLI entrypoint `bin/og.cmd` and `bin/og.ps1`.
7. Push new repository to `github.com/samuelcaldas/omniget` via GitHub CLI (`gh repo create`).

### Phase 2: Add Submodule & Link to `windows-core`
1. Add git submodule: `git submodule add https://github.com/samuelcaldas/omniget.git external/omniget`.
2. Update `.gitmodules`.

### Phase 3: Refactor Guest Scripts & Host Orchestrators
1. Create `scripts/guest/Install-OmniGet.ps1` (deploys OmniGet to `C:\Program Files\OmniGet`, puts `og` in system PATH, creates Public Desktop shortcut `OmniGet Store.lnk`).
2. Update `scripts/guest/Install-Tools.ps1` to leverage OmniGet recipes or presets.
3. Update `scripts/guest/sconfig/modules/mod-tools.ps1` to launch `og`.
4. Update `scripts/host/install-ninite.sh` and `install-ninite.ps1` -> rename/supersede with `install-omniget.sh` and `install-omniget.ps1` (with backward compatibility aliases).
5. Update `build-iso.sh` / `build-iso.ps1` to package `external/omniget` into OEMDRV / guest provisioning.
6. Update `README.md`, `GEMINI.md`, and `docs/` with OmniGet documentation.

---

## 6. Verification & Validation

1. **CLI Functional Tests**:
   - `og list --source ninite` -> returns 142 apps without errors.
   - `og search git` -> returns Git for Windows, GitHub CLI, and Ninite git apps.
   - `og preset DevStack --dry-run` -> generates expected execution batch.
2. **TUI Interactive Tests**:
   - Launch `og` in PowerShell 7 console.
   - Verify Home tab displays only featured apps.
   - Press `Tab` / `3` to switch to Ninite tab -> verify all 142 apps appear.
   - Press `/` and type search query -> verify instant filtering across all sources.
   - Select combination of Ninite apps + Distro tools -> press `Enter` and verify batch execution.
3. **Host Orchestration Tests**:
   - Run `./scripts/host/install-omniget.sh --interactive` -> opens remote TUI over SSH.
   - Run `./scripts/host/install-omniget.sh --preset DevStack` -> executes unattended silent installation.
