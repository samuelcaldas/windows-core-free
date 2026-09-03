# Windows CoreOS (WCOS) — Documentation Index

Welcome to the comprehensive documentation index for **Windows CoreOS (WCOS)**: the free, lightweight Windows Server Core distribution and automation suite.

---

## 📚 Core Documentation & Technical Wiki

Full documentation is published in the **[Windows CoreOS Wiki](https://github.com/samuelcaldas/windows-core-free/wiki)** (and stored locally in [`../wiki/`](../wiki/Home.md)):

| Document | Description |
| :--- | :--- |
| **[Technical Wiki](../wiki/Home.md)** | Complete 15-page knowledge base covering architecture, installation, tuning, and AI agents. |
| **[Brand Identity Manual](branding/MANUAL.md)** | Visual identity, logo guidelines, official color palette, typography, and vector assets. |
| **[Agent Operating Guidelines](../AGENTS.md)** | Architecture, development conventions, and testing protocols for autonomous AI agents. |
| **[Versioning & Release Guide](VERSIONING.md)** | Semantic Versioning 2.0.0 policy, Git tag bumping steps, and GitHub Actions release automation. |
| **[SSH Configuration Guide](ssh-configuration.md)** | Client `~/.ssh/config` setups, ProxyJump tunnels, and port forwarding for `winvm`. |
| **[Systemd Autostart & Service Guide](systemd-autostart.md)** | Host-level systemd service unit, boot autostart on Ubuntu, process supervision, and clean ACPI shutdown. |
| **[System Architecture Blueprint](../GEMINI.md)** | Full infrastructure blueprint, QEMU/KVM tuning, memory optimization, and component breakdown. |
| **[OmniGet Package Manager Wiki](../external/omniget/wiki/Home.md)** | Complete documentation for OmniGet (`og`), the multi-source package manager and ANSI curses store. |

---

## 🛡️ Upstream ISO Requirements & Legal Notice

> [!NOTE]
> Windows CoreOS is an open-source automation layer (MIT License) that provisions official Microsoft installation media. This repository **does not host or redistribute Windows ISOs or product keys**.

Users must obtain the official Microsoft Hyper-V Server 2019 OEM ISO directly from Microsoft:
- **Direct Official Download**: [`17763.737.190906-2324.rs5_release_svc_refresh_SERVERHYPERCORE_OEM_x64FRE_en-us_1.iso`](https://software-download.microsoft.com/download/pr/17763.737.190906-2324.rs5_release_svc_refresh_SERVERHYPERCORE_OEM_x64FRE_en-us_1.iso)
- **Official Portal**: [Microsoft Evaluation Center](https://www.microsoft.com/en-us/evalcenter/evaluate-hyper-v-server-2019)
- **SHA256 Hash**: `48e9b944518e5bbc80876a9a7ff99716f386f404f4be48dca47e16a66ae7872c`
- **Host Automation**: `./scripts/host/setup-host.sh --download-iso`

---

## 🚀 Key Features & Stack Overview

- **Base Kernel**: Windows Server Core 2019 (RS5 build 17763), memory-optimized down to **~530 MB RAM idle**.
- **Host Supervision**: Native Linux systemd service unit (`windows-core.service`) with boot autostart and ACPI shutdown.
- **Remote Access**: OpenSSH Server with PowerShell 7 (`pwsh.exe`) default shell and ED25519 key authentication.
- **Desktop Shell**: **WinXShell** (`WinXShell.exe -winpe`) lightweight Win32 shell and **WinFile** (`Winfile.exe`) file explorer.
- **Package Management**: **OmniGet (`og`)** multi-source universal package engine (`C:\Program Files\OmniGet`).
- **Terminal**: WezTerm engine with `wt.exe` launcher, Cascadia Code fonts, and Mesa software OpenGL rendering.
- **Protection**: Pre-configured Dan Pollock zero-route (`0.0.0.0`) hosts blocklist with 13,000+ domain filters.
- **Developer Stack**: Standalone Docker CLI & Docker Compose, Git, Node.js LTS, Python 3.12, .NET SDK, GitHub CLI (`gh`), Claude Code CLI, and Google Antigravity daemon (`agy-daemon`).

---

## 📁 Filesystem & Installation Directory Standards

| Target Path | Permitted Usage | Examples |
| :--- | :--- | :--- |
| **`C:\Program Files\<App>`** | 64-bit applications, runtimes, package managers, and tools. | `C:\Program Files\OmniGet`, `C:\Program Files\dotnet`, `C:\Program Files\WinXShell`, `C:\Program Files\PowerShell\7` |
| **`C:\Program Files (x86)\<App>`** | 32-bit legacy or architecture-specific binaries. | `C:\Program Files (x86)\Common Files` |
| **`C:\ProgramData\<App>`** | Machine-wide application data, daemon state, host keys. | `C:\ProgramData\ssh`, `C:\ProgramData\OmniGet` |
| **`C:\Users\<user>\...`** | User-specific configs, roaming caches, dotfiles. | `C:\Users\samuelcaldas\.wezterm.lua`, `%APPDATA%` |
| **`%TEMP%\<folder>`** | Transient installer downloads and extraction staging. | `$env:TEMP\wcos_installer` (cleaned up after setup) |
| **`C:\Provisioning`** | Unattended bootstrap scripts and offline package cache. | Strictly ISO boot staging; not a permanent application folder. |
| **`C:\<App>` (Root)** | ❌ **STRICTLY PROHIBITED** | No direct folders on `C:\` (`C:\Tools`, `C:\ReactShell`, `C:\OmniGet` are forbidden). |
