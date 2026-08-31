# Windows Core Documentation Index

Welcome to the technical documentation for the **Windows Core Headless Development Host** project.

---

## 📚 Table of Contents

| Document | Description |
| :--- | :--- |
| **[SSH Configuration Guide](file:///home/samuelcaldas/repos/windows-core/docs/ssh-configuration.md)** | Client `~/.ssh/config` setups, ProxyJump tunnels, and port forwards for `winvm`. |
| **[Systemd Autostart & Service Guide](file:///home/samuelcaldas/repos/windows-core/docs/systemd-autostart.md)** | Host-level systemd service setup, boot autostart on Ubuntu, process supervision, and ACPI shutdown. |
| **[System Architecture & Overview](file:///home/samuelcaldas/repos/windows-core/GEMINI.md)** | Full infrastructure blueprint, QEMU/KVM tuning, memory optimizations, and component breakdown. |


---

## 🚀 Key Features & Stack Overview

- **OS**: Windows Server Core 2019 (RS5 build 17763), stripped and memory-optimized to **~530 MB RAM idle**.
- **Host Autostart & Supervision**: Native systemd service (`windows-core.service`) with boot autostart and graceful ACPI powerdown.
- **Remote Access**: Win32-OpenSSH with PowerShell 7 (`pwsh.exe`) default shell.
- **Desktop Shell**: **WinXShell** (`WinXShell.exe -winpe`) default Win32 explorer shell and **WinFile** (`Winfile.exe`) default file explorer (ReactShell, ReactFM, and Explorer++ available as modular options).
- **Package Management**: **OmniGet (og)** multi-source universal package manager (`C:\Program Files\OmniGet`).
- **Terminal**: WezTerm engine with `wt.exe` alias, Cascadia Code fonts, and Mesa software OpenGL rendering.
- **Protection**: Native Dan Pollock zero-route hosts blocklist with 13,371 ad/tracker/malware rules.
- **Developer Stack**: Docker CLI & Docker Compose (standalone), Git, Node.js LTS, Python 3.12, .NET 10/8 SDK, GitHub CLI (`gh`), Claude Code CLI, and Google Antigravity daemon.

---

## 📁 Filesystem & Installation Directory Standards

| Target Path | Permitted Usage | Examples |
| :--- | :--- | :--- |
| **`C:\Program Files\<App>`** | 64-bit applications, runtimes, package managers, and tools. | `C:\Program Files\OmniGet`, `C:\Program Files\dotnet`, `C:\Program Files\WinXShell`, `C:\Program Files\PowerShell\7` |
| **`C:\Program Files (x86)\<App>`** | 32-bit legacy or architecture-specific binaries. | `C:\Program Files (x86)\Common Files` |
| **`C:\ProgramData\<App>`** | Machine-wide application data, daemon state, host keys. | `C:\ProgramData\ssh`, `C:\ProgramData\OmniGet` |
| **`C:\Users\<user>\...`** | User-specific configs, roaming caches, dotfiles. | `C:\Users\samuelcaldas\.wezterm.lua`, `%APPDATA%` |
| **`%TEMP%\<folder>`** | Transient installer downloads and extraction staging. | `$env:TEMP\win_tools_installer` (cleaned up after setup) |
| **`C:\Provisioning`** | Unattended bootstrap scripts and offline package cache. | Strictly ISO boot staging; not a permanent application folder. |
| **`C:\<App>` (Root)** | ❌ **STRICTLY PROHIBITED** | No direct folders on `C:\` (`C:\Tools`, `C:\ReactShell`, `C:\XPShell`, `C:\OmniGet` are forbidden). |
