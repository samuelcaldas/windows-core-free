# Plan: Modular sconfig Control Panel Patch for Windows Core Developer Edition

## Context
In Windows Server Core / Hyper-V Server 2019, `sconfig.cmd` / `sconfig.vbs` is the primary interactive terminal utility for server configuration. In its stock state, it contains legacy Hyper-V licensing quirks, telemetry dialogs, and unused Windows Update menus, while lacking developer tooling and management features specific to this distro (such as OpenSSH status, Ninite store, desktop shell selector, and memory optimization).

Following the grilling interview, we will retain the lightweight VBScript host architecture (`sconfig.cmd` calling `sconfig.vbs`) while restructuring the UI into a categorized "Windows Control Panel" TUI layout. Complex operations and new distro features will be implemented in modular standalone scripts placed outside the main VBScript file under `C:\Windows\System32\sconfig-modules\`.

---

## Architecture & Menu Design

### Main Menu Layout
```text
============================================================================
           Windows Core Developer Edition - Server Control Center
============================================================================

 [ System & Identity ]
  1) Computer Name & Workgroup
  2) Local User Accounts & Administrators
  3) Date and Time Settings

 [ Network & Remote Access ]
  4) Network Adapter & IP Configuration
  5) OpenSSH Server & Remote Management (WinRM / RDP)

 [ Developer Tools & Distro Utilities ]
  6) Distro App Store (Ninite & Toolchain Status)
  7) Desktop Shell & File Manager (WinXShell / WinFile / ReactShell)
  8) System Performance & Memory Pruning (Atlas / Core Tuning)

 [ Power & Session ]
  9) Log Off User
 10) Restart Server
 11) Shut Down Server
 12) Exit to PowerShell 7 / Command Line
============================================================================
```

---

## Implementation Steps

### 1. Create Modular PowerShell Helper Modules (`scripts/guest/sconfig/modules/`)
- **`mod-ssh.ps1`**:
  - Displays OpenSSH Server status (Running/Stopped), startup type (Automatic), listening port (22), and firewall rules.
  - Displays count of authorized keys in `C:\ProgramData\ssh\administrators_authorized_keys` and host keys.
  - Provides quick actions: Start/Restart SSH service, view keys, toggle Remote Desktop (RDP).
- **`mod-tools.ps1`**:
  - Checks installed developer runtimes: .NET SDKs (10.0/8.0), Python 3.12, Node.js 20, Git 2.46, Docker CLI, GitHub CLI.
  - Provides option to launch the interactive Ninite App Store (`Install-NiniteApps.ps1`).
- **`mod-shell.ps1`**:
  - Displays currently configured default shell (WinXShell, ReactShell, WinFile, Explorer++, or Windows Command Shell).
  - Allows the user to switch the default shell and file manager with one keystroke and applies appropriate registry keys.
- **`mod-optimize.ps1`**:
  - Displays live memory statistics (Total RAM, Used RAM, Free RAM, Process count).
  - Provides option to trigger `Optimize-System.ps1` memory pruning.

### 2. Patch & Refactor `sconfig.vbs` (`scripts/guest/sconfig/sconfig.vbs`)
- Replace the legacy 15-item flat menu with the 12-item categorized "Windows Control Panel" structure.
- Remove Hyper-V specific telemetry warnings, licensing dialogs, and dead Windows Update options.
- Retain native, lightweight VBScript logic for fast local operations: Computer Name, Workgroup, Local Admin accounts, Date/Time, and IP/DNS settings.
- Delegate developer modules (Options 5, 6, 7, 8) to `oShell.Run "pwsh.exe -NoProfile -ExecutionPolicy Bypass -File C:\Windows\System32\sconfig-modules\mod-*.ps1", 1, True`.

### 3. Create Wrapper & Installer Scripts
- **`scripts/guest/sconfig/sconfig.cmd`**: Update CMD launcher to set clean console titles, colors, and direct invocation.
- **`scripts/guest/Install-SConfigPatch.ps1`**:
  - Deploys `sconfig.cmd`, `sconfig.vbs`, and `sconfig-modules\` to `C:\Windows\System32\`.
  - Creates backup of original `sconfig.vbs` (`sconfig.vbs.bak`).
  - Registers `sconfig` shortcuts if applicable.
- **Integrate into Distro Pipeline**: Add `Install-SConfigPatch.ps1` invocation to `scripts/guest/Install-Tools.ps1`.

---

## Critical Files
- `scripts/guest/sconfig/sconfig.vbs`: Main patched VBScript TUI.
- `scripts/guest/sconfig/sconfig.cmd`: Launcher batch file.
- `scripts/guest/sconfig/modules/mod-ssh.ps1`: SSH & Remote Access module.
- `scripts/guest/sconfig/modules/mod-tools.ps1`: Ninite App Store & Dev toolchain module.
- `scripts/guest/sconfig/modules/mod-shell.ps1`: Desktop Shell switcher module.
- `scripts/guest/sconfig/modules/mod-optimize.ps1`: Memory & Performance module.
- `scripts/guest/Install-SConfigPatch.ps1`: Deployment and installer script.
- `scripts/guest/Install-Tools.ps1`: Distro toolchain pipeline integration.

---

## Verification
1. **Deploy to `winvm`**: Run `Install-SConfigPatch.ps1` on `winvm` over SSH.
2. **Menu Rendering**: Run `sconfig` and verify clean 12-option Control Panel layout without Hyper-V / telemetry popups.
3. **Module Testing**:
   - Option 4: Network & IP configuration (native VBScript).
   - Option 5: SSH & Remote Access module (launches `mod-ssh.ps1`).
   - Option 6: Distro App Store / Dev Toolchains (launches `mod-tools.ps1`).
   - Option 7: Desktop Shell Switcher (launches `mod-shell.ps1`).
   - Option 8: Performance & Memory meter (launches `mod-optimize.ps1`).
   - Option 12: Exit cleanly to PowerShell 7.
