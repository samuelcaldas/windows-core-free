# Desktop Shells, GUI & Terminal Environments

While **Windows CoreOS (WCOS)** is designed primarily as a headless server distribution, developers occasionally require graphical tools, a taskbar, file management, or a modern multi-tab terminal emulator.

This document covers WCOS's modular desktop stack, which provides a full graphical desktop environment consuming **less than 30 MB of additional RAM**.

---

## 🪟 Desktop Environment Comparison

| Component | Standard Windows Server GUI | Windows CoreOS (WCOS) Stack | Memory Footprint |
| :--- | :--- | :--- | :--- |
| **Shell & Taskbar** | Windows Shell (`explorer.exe`) | **WinXShell** (`WinXShell.exe -winpe`) | **~15 MB** (vs ~400 MB) |
| **File Manager** | Heavy Shell Namespace Explorer | **Microsoft WinFile** (`winfile.exe`) | **~6 MB** (vs ~120 MB) |
| **Terminal** | `conhost.exe` (Single-tab CMD) | **WezTerm Engine** (`wt.exe`) | **~25 MB** (GPU/Mesa) |
| **Total GUI Footprint** | ~500 MB - 700 MB RAM | **< 50 MB Total RAM** | **> 90% Savings** |

---

## 🌟 WinXShell: Lightweight Taskbar & Start Menu

WCOS uses **WinXShell** as its default graphical shell provider:

* **Executable**: `C:\Program Files\WinXShell\WinXShell.exe`
* **Features**:
  - Full bottom taskbar with running window buttons and system clock.
  - Native Start Menu with search, shutdown/restart buttons, and application categories.
  - System tray (Notification Area) support.
  - Native wallpaper rendering (`config/wallpaper/wallpaper.jpg`).
  - Automatically configured via Winlogon registry:
    ```powershell
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" `
        -Name "Shell" -Value "C:\Program Files\WinXShell\WinXShell.exe -winpe" -Force
    ```

---

## 📁 File Manager Providers

WCOS decouples file management from the Windows desktop shell:

### 1. Microsoft WinFile (Default File Manager)
* **Executable**: `C:\Program Files\WinFile\WinFile.exe`
* **Architecture**: Open-source native 64-bit port of Microsoft Windows File Manager with full UTF-16 Unicode, long path, and split-pane tree navigation.
* **Explorer Association**: Intercepts folder double-clicks and `explorer.exe` invocations via `HKLM:\SOFTWARE\Classes\Folder\shell\open\command`.

### 2. Alternative File Managers
* **ReactOS File Manager (ReactFM)**: Lightweight modern file browser ported from ReactOS.
* **Explorer++**: Tabbed file manager with bookmark bar and advanced filtering.

---

## 💻 Windows Terminal (WezTerm Engine)

WCOS deploys a portable, high-performance terminal emulator based on the WezTerm engine configured as `wt.exe`:

* **Executable**: `C:\Program Files\WindowsTerminal\wt.exe`
* **Features**:
  - Full 24-bit TrueColor and ANSI escape sequence support.
  - Integrated **Cascadia Code** and **Cascadia Mono** programming fonts.
  - Multi-tab management with split panes.
  - Mesa software OpenGL rendering fallback (runs smoothly even without host GPU pass-through).
  - Configured to open **PowerShell 7** by default with Windows CoreOS color themes.

---

## 🚀 Live Host Deployment

You can install or reconfigure the desktop environment live over SSH from your Linux host at any time without rebooting:

```bash
# Deploy WinXShell and Microsoft WinFile
./scripts/host/install-desktopshell.sh WinXShell WinFile

# Deploy Windows Terminal (wt.exe)
./scripts/host/install-terminal.sh
```
