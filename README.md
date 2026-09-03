<p align="center">
  <img src="docs/branding/assets/wcos-logo-horizontal.svg" alt="Windows CoreOS Logo" width="680">
</p>

<p align="center">
  <strong>Free, lightweight Windows Server Core distribution and automation framework for developers and autonomous AI agents.</strong>
</p>

<p align="center">
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License: MIT"></a>
  <a href="https://github.com/PowerShell/PowerShell"><img src="https://img.shields.io/badge/PowerShell-7%2B-blue.svg?logo=powershell" alt="PowerShell 7"></a>
  <a href="docs/branding/MANUAL.md"><img src="docs/branding/assets/wcos-badge.svg" alt="Windows CoreOS Distro"></a>
  <a href="https://github.com/samuelcaldas/windows-core-free/releases"><img src="https://img.shields.io/github/v/release/samuelcaldas/windows-core-free?include_prereleases&label=Release&color=brightgreen" alt="GitHub Release"></a>
  <a href="docs/README.md"><img src="https://img.shields.io/badge/Docs-Wiki%20%26%20Guides-00D2FF.svg?logo=gitbook" alt="Documentation"></a>
  <a href="https://microsoft.com/windows"><img src="https://img.shields.io/badge/Base%20Kernel-Windows%20Server%20Core%20RS5%20(17763)-0078D6?logo=windows" alt="Windows Server Core 2019"></a>
</p>

---

## ⚡ Overview

**Windows CoreOS (WCOS)** is an open-source, reproducible automation suite and headless distribution based on official **Microsoft Hyper-V Server 2019 / Windows Server Core 2019** (RS5, build 17763). 

It transforms vanilla Windows Server Core into an ultra-lean, cloud-native virtualized workstation on **Linux (Ubuntu / KVM / Proxmox)** or Docker, engineered specifically for systems programmers, DevOps workflows, and autonomous AI agents (**Google Antigravity**, **Anthropic Claude Code**, and **OpenAI Codex**).

---

## 🛡️ Critical Notice & Legal Disclaimer

> [!IMPORTANT]
> **This repository DOES NOT redistribute, host, or publish proprietary Microsoft Windows binaries, ISO disk images, or product keys.**
>
> Windows CoreOS is an independent automation and configuration framework (MIT License). Users are required to provide their own legitimate, officially licensed or evaluation copy of Microsoft Hyper-V Server 2019 / Windows Server 2019.
>
> Microsoft, Windows, Windows Server, Hyper-V, and PowerShell are registered trademarks of Microsoft Corporation. Windows CoreOS is not affiliated with, endorsed by, or sponsored by Microsoft Corporation.

### 📥 Official Microsoft ISO Sources
Microsoft provides **Microsoft Hyper-V Server 2019** as a free, non-expiring production hypervisor and core OS. You can download the official image directly from Microsoft's distribution servers:

| Attribute | Specification / Value |
| :--- | :--- |
| **Official File Name** | `17763.737.190906-2324.rs5_release_svc_refresh_SERVERHYPERCORE_OEM_x64FRE_en-us_1.iso` |
| **Official Microsoft CDN**| [Direct Download Link (Microsoft CDN)](https://software-download.microsoft.com/download/pr/17763.737.190906-2324.rs5_release_svc_refresh_SERVERHYPERCORE_OEM_x64FRE_en-us_1.iso) |
| **Evaluation Center** | [Microsoft Evaluation Center Portal](https://www.microsoft.com/en-us/evalcenter/evaluate-hyper-v-server-2019) |
| **SHA256 Checksum** | `48e9b944518e5bbc80876a9a7ff99716f386f404f4be48dca47e16a66ae7872c` |
| **File Size** | ~2.83 GB (3,043,995,648 bytes) |

#### 🤖 Automated One-Command Download & Verification
WCOS host scripts can automatically download and verify the official Microsoft ISO directly to `iso/`:

```bash
# Downloads official ISO directly from Microsoft and verifies SHA256 checksum
./scripts/host/setup-host.sh --download-iso
```

---

## 🌟 Key Features

- 📉 **Ultra-Low Memory Footprint**: Stripped from vanilla ~2.1 GB down to **~530 MB RAM idle** by cleanly pruning Defender (`MsMpEng`), disabling nested Hyper-V roles, Superfetch (`SysMain`), error reporting, and non-essential background tasks.
- 🔑 **SSH-First Remote Orchestration**: Native **OpenSSH Server** configured out-of-the-box with **PowerShell 7 (`pwsh`)** as the default shell and ED25519 public key authentication.
- 📦 **Multi-Source Package Engine (OmniGet)**: Built-in universal package manager (`og`) aggregating **140+ Ninite apps** (dynamic multi-app bundles), **GitHub Releases**, **Direct Vendor Installers**, and **Distro Recipes**.
- ⚡ **Zero-Downtime Hot-Swaps**: Upgrading PowerShell 7 or active shells runs via in-use binary rotation (`.old_<timestamp>`), preventing OpenSSH disconnects or store crashes.
- 🤖 **Autonomous AI Agent Stack**: Pre-configured support for **Google Antigravity CLI** (`antigravity-cli`, `agy-daemon` on port `9090`), **Claude Code CLI**, and **Codex CLI**.
- 🛡️ **Zero Bloat & Zero Telemetry**: Pre-installed Dan Pollock zero-route (`0.0.0.0`) DNS blocklist (13,000+ ad, telemetry, tracking, and malware domains).
- 🖥️ **Modular Win32 Desktop Shells**: Lightweight **WinXShell** (~15MB RAM) and **Microsoft WinFile** (Windows File Manager), with WezTerm GPU/OpenGL terminal (`wt.exe`).
- 🔄 **Autonomous Systemd Autostart**: Native Linux systemd service unit (`windows-core.service`) with automated boot startup, live logging, and clean ACPI shutdown orchestration.

---

## 🏗️ System Architecture

```mermaid
flowchart TD
    subgraph Host [Linux Ubuntu Host (KVM/QEMU)]
        VirtStack["QEMU / KVM Hypervisor + VirtIO"]
        Systemd["systemd (windows-core.service)"]
        SSHClient["SSH Client (ssh winvm)"]
        Browser["Host Web Browser / APIs"]
    end

    subgraph Guest [Windows CoreOS (WCOS)]
        SSHD["OpenSSH Server (:22 -> :2222)"]
        WinRM["WinRM Service (:5985)"]
        AgyDaemon["Antigravity Daemon (:9090)"]
        Shell["PowerShell 7 Core (pwsh.exe)"]
        OmniGet["OmniGet Package Engine (og)"]
        Desktop["WinXShell & WinFile (Optional Desktop)"]
    end

    Systemd -->|Supervises| VirtStack
    SSHClient -->|Port 2222| SSHD
    Browser -->|Port 9090| AgyDaemon
    SSHD --> Shell
    Shell --> OmniGet
    OmniGet --> Desktop
```

### Network & Port Topology
| Service | Guest Port | Default Host Port | Protocol / Purpose |
| :--- | :--- | :--- | :--- |
| **OpenSSH Server** | `22` | `2222` | Direct interactive CLI, agent sessions, and SFTP file transfer |
| **WinRM (WSMan)** | `5985` | `5985` | PowerShell Remoting (`Enter-PSSession`, Ansible automation) |
| **Antigravity Daemon** | `9090` | `9090` | Headless Remote Control API (`agy-daemon`) |
| **RDP (Optional)** | `3389` | `3389` | Fallback graphical remote desktop |

---

## 🚀 Quick Start Guide

### 1. Prerequisites (Ubuntu Linux Host)
Install virtualization prerequisites and download the official Microsoft ISO:

```bash
# 1. Clone repository
git clone --recurse-submodules https://github.com/samuelcaldas/windows-core-free.git
cd windows-core-free

# 2. Setup host dependencies and download official Microsoft ISO
./scripts/host/setup-host.sh --download-iso
```

### 2. Build Unattended Media & Allocate Disk
Generate the secondary virtual driver (OEMDRV) containing `autounattend.xml`, VirtIO drivers, and bootstrap scripts:

```bash
./scripts/host/build-iso.sh
```

### 3. Launch Windows CoreOS VM
Boot the VM with KVM acceleration, VirtIO network/storage, and port forwarding:

```bash
./scripts/host/run-vm.sh
```

### 4. Connect via OpenSSH (`winvm`)
Configure your SSH client in `~/.ssh/config`:

```sshconfig
Host winvm
    HostName 127.0.0.1
    User samuelcaldas
    Port 2222
    IdentityFile ~/.ssh/id_ed25519
    StrictHostKeyChecking accept-new
    ForwardAgent yes
```

Connect directly to your Windows CoreOS node:

```bash
ssh winvm
```

```text
   __      ___           _                     _____              ____   _____ 
   \ \    / (_)         | |                   / ____|            / __ \ / ____|
    \ \  / / _ _ __   __| | _____      _____ | |     ___  _ __ ___| |  | | (___  
     \ \/ / | | '_ \ / _` |/ _ \ \ /\ / / __|| |    / _ \| '__/ _ \ |  | |\___ \ 
      \  /  | | | | | (_| | (_) \ V  V /\__ \| |___| (_) | | |  __/ |__| |____) |
       \/   |_|_| |_|\__,_|\___/ \_/\_/ |___(_)_____\___/|_|  \___|\____/|_____/ 
                                                                                   
 ==================================================================================
  Windows CoreOS (WCOS) — Free Windows Server Core Distribution for Developers & AI
 ==================================================================================
```

---

## 📦 Software Management with OmniGet (`og`)

Windows CoreOS includes **OmniGet** (`og`), an ultra-fast multi-source package manager with an interactive ANSI curses store:

```powershell
# Launch visual interactive TUI store
og

# Search across 140+ Ninite apps, GitHub releases, and direct vendors
og search git

# Install developer preset silently
og preset DevStack -s

# Install applications with zero-downtime hot-swapping
og install pwsh git nodejs docker-cli -s

# Check installed version
og version
```

---

## 🏛️ Filesystem & Directory Standards

To maintain clean system paths and adhere strictly to Windows security standards:

- **Strict Prohibition of Root `C:\` Application Directories**: Applications, portable tools, runtimes, or package managers must **never** create installation folders directly on the root drive (e.g. `C:\Tools`, `C:\ReactShell`, `C:\Python27` are strictly forbidden).
- **64-bit Applications**: Must be installed under `C:\Program Files\<VendorOrToolName>` (e.g. `C:\Program Files\OmniGet`, `C:\Program Files\PowerShell\7`, `C:\Program Files\Git`).
- **32-bit Applications**: Must be installed under `C:\Program Files (x86)\<VendorOrToolName>`.
- **System-Wide Data & State**: Resides in `C:\ProgramData\<AppName>` (e.g. `C:\ProgramData\ssh`).
- **User Configurations & Caches**: Resides in `%APPDATA%`, `%LOCALAPPDATA%`, or `C:\Users\<user>\.<tool>`.
- **Transient Installer Storage**: Downloads occur in `%TEMP%\<folder>` and are cleaned up on exit.

---

## 🔄 Automatic Startup on Ubuntu Boot (Systemd)

Manage the VM as a native background system service on your Linux host:

```bash
# Install and enable autostart on Ubuntu boot
./scripts/host/setup-service.sh --install

# Check live status & boot enablement
./scripts/host/setup-service.sh --status

# View live journal logs
./scripts/host/setup-service.sh --logs

# Gracefully shutdown VM via ACPI
./scripts/host/setup-service.sh --stop

# Restart VM
./scripts/host/setup-service.sh --restart
```

---

## 📚 Documentation Index

- 🎨 **[Brand Identity Manual](docs/branding/MANUAL.md)**: Visual identity guidelines, official palette, typography, vector assets, and logo usage.
- 🤖 **[Agent Operating Guidelines](AGENTS.md)**: Workflows, conventions, and testing protocols for autonomous AI agents.
- 🏷️ **[Versioning & Release Guide](docs/VERSIONING.md)**: SemVer 2.0.0 conventions, Git tag bumping, and GitHub Actions automation.
- 🔑 **[SSH Configuration Guide](docs/ssh-configuration.md)**: Detailed ProxyJump, port forwarding, and key exchange tutorials.
- ⚙️ **[System Architecture Reference](GEMINI.md)**: Comprehensive architectural blueprint and hardware optimization reference.
- 📦 **[OmniGet Package Manager Docs](external/omniget/wiki/Home.md)**: Complete OmniGet Wiki and provider specifications.

---

## 📄 License & Legal Notice

Distributed under the **MIT License**. See [`LICENSE`](LICENSE) for full details.

```
Copyright (c) 2026 Samuel Caldas and contributors.
```

- **Microsoft Trademarks**: Windows, Windows Server, Windows Server Core, Hyper-V, PowerShell, and Win32 are registered trademarks of Microsoft Corporation.
- **Independent Project**: Windows CoreOS is an independent open-source configuration toolkit and is not affiliated with, endorsed by, or sponsored by Microsoft Corporation.
- **Third-Party Software**: VirtIO drivers, Ninite applications, and third-party tools deployed through WCOS scripts are subject to their respective original licenses and copyrights.
