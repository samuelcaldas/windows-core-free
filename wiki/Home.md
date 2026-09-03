# Welcome to the Windows CoreOS (WCOS) Wiki

<div align="center">

![Windows CoreOS](https://raw.githubusercontent.com/samuelcaldas/windows-core-free/master/docs/branding/assets/wcos-logo-horizontal.svg)

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://github.com/samuelcaldas/windows-core-free/blob/master/LICENSE)
[![Latest Release](https://img.shields.io/github/v/release/samuelcaldas/windows-core-free?color=00F5D4&label=release)](https://github.com/samuelcaldas/windows-core-free/releases)
[![Architecture: x86_64](https://img.shields.io/badge/arch-x86__64-informational.svg)](#)
[![RAM Idle](https://img.shields.io/badge/RAM%20Idle-~530%20MB-success.svg)](#)
[![Default Shell](https://img.shields.io/badge/Shell-PowerShell%207.6.5-0078D4.svg)](#)

**The Free, Ultra-Lightweight Windows Server Core Distribution for Headless Linux (KVM / Ubuntu / Proxmox) and Autonomous AI Agents.**

</div>

---

## 🎯 What is Windows CoreOS (WCOS)?

**Windows CoreOS (WCOS)** is an automated build, customization, unattended installation, and lifecycle management layer built on top of **Microsoft Hyper-V Server 2019 OEM x64** (Windows Server Core RS5, build 17763).

Operating as a virtualized guest on Linux KVM/QEMU, Proxmox VE, or Docker, WCOS strips away unnecessary server bloatware, consumer apps, telemetry, and hypervisor components. It delivers a hyper-efficient Windows execution environment that boots in under 15 seconds and consumes only **~530 MB of idle RAM** (down from ~2.1 GB on standard installations).

WCOS is designed from the ground up to act as a **Developer Workstation**, **DevOps CI/CD runner**, and **Autonomous AI Agent Execution Node** running tools such as Google Antigravity CLI (`antigravity-cli`), Anthropic Claude Code CLI (`claude-code`), and OpenAI Codex CLI (`codex-cli`).

---

## ⚡ Key Highlights & Specifications

| Feature | Windows CoreOS (WCOS) | Standard Windows Server 2019 |
| :--- | :--- | :--- |
| **Idle RAM Footprint** | **~530 MB - 600 MB** | 2.1 GB - 2.8 GB |
| **Licensing** | **Free / Legitimate OEM Evaluation** | Paid Commercial License Required |
| **Hyper-V Nested Roles** | **Completely Removed** (no hypervisor conflicts) | Enabled by default |
| **Primary Interaction** | **OpenSSH (PowerShell 7 default shell)** | GUI / Server Manager |
| **Windows Defender** | **Pruned & Disabled** (`MsMpEng` disabled) | Consumes ~250MB RAM constantly |
| **Package Manager** | **OmniGet (`og`)** pre-installed | None / manual downloads |
| **Desktop Environment** | **WinXShell (~15MB RAM)** + WinFile | Full heavy Explorer (~400MB RAM) |
| **AI Agent Support** | Native Google Antigravity & Claude Code | Manual manual setup |
| **Linux Host Supervision** | Systemd native service (`windows-core.service`) | Manual virtualization scripts |
| **DNS Privacy & Adblock** | Dan Pollock zero-route (`0.0.0.0`) 13k+ rules | Unfiltered Windows telemetry |

---

## 🏗️ High-Level System Architecture

```mermaid
graph TD
    subgraph Host ["Headless Linux Host (Ubuntu / Proxmox / KVM)"]
        systemd["systemd (windows-core.service)"]
        qemu["QEMU / KVM Engine (-enable-kvm, -cpu host)"]
        ovmf["UEFI OVMF Firmware"]
        sparse_disk[("Sparse QCOW2 Disk (windows-core.qcow2, 64G)")]
        iso_store["ISO Directory (Official OEM ISO + oemdrv.iso)"]
        
        systemd -->|Supervises| qemu
        qemu --> ovmf
        qemu --> sparse_disk
        qemu --> iso_store
    end

    subgraph Guest ["Windows CoreOS (WCOS) Guest"]
        subgraph Core ["OS Foundation & Kernel (Build 17763)"]
            kernel["Windows Server Core RS5 x64 Kernel"]
            virtio["VirtIO Drivers (SCSI, Net, Balloon, Serial)"]
            pwsh7["PowerShell 7 (pwsh.exe - Default Shell)"]
            decom["Hyper-V Hypervisor Decommissioned"]
        end

        subgraph Remoting ["Headless Remoting Services"]
            openssh["OpenSSH Server (Port 22 / 2222)"]
            winrm["WinRM / WS-Man (Port 5985 / 5986)"]
            agy["Antigravity Daemon (agy-daemon, Port 9090)"]
        end

        subgraph Toolchain ["Developer & AI Toolchains"]
            omniget["OmniGet Package Engine (C:\Program Files\OmniGet)"]
            devstack["Node.js LTS, Python 3.12, Git, .NET SDK, Docker CLI"]
            ai_agents["Claude CLI, Antigravity CLI, Codex CLI"]
        end

        subgraph ShellUI ["Optional Lightweight GUI"]
            winxshell["WinXShell Desktop (~15MB RAM)"]
            winfile["Microsoft WinFile (File Explorer)"]
            wezterm["Windows Terminal (WezTerm Engine)"]
        end
    end

    qemu -->|KVM Virtualization & Port Forwarding| Guest
```

---

## 🗺️ Wiki Navigation & Documentation Index

Explore the comprehensive guides below:

### 🚀 Getting Started & Fundamentals
* **[Getting Started](Getting-Started)**: Host prerequisites, one-line setup, downloading the official Microsoft ISO, creating unattended media, and initial VM boot.
* **[Architecture & Hardware](Architecture-and-Hardware)**: Detailed hardware configuration, QEMU flags, VirtIO devices, sparse storage, and port mappings.
* **[Unattended Installation](Unattended-Installation)**: Dual-drive zero-touch provisioning, `autounattend.xml` structure, component bypasses, and bootstrap stages.

### ⚙️ Performance, Tuning & Networking
* **[System Optimization & Memory Pruning](System-Optimization-and-Memory-Pruning)**: How WCOS reclaims RAM, disables Defender and telemetry, decommissions Hyper-V, and installs hosts blocklists.
* **[Remote Access & OpenSSH](Remote-Access-and-SSH)**: Setting up SSH key authentication, PowerShell 7 default shell, ProxyJump jumper hosts, and WinRM.
* **[Host Systemd Autostart](Host-Systemd-Autostart)**: Running WCOS as a native Linux systemd service with auto-boot, failure recovery, and ACPI shutdown.
* **[Proxmox & Docker Portability](Proxmox-and-Docker-Portability)**: Migrating QCOW2 disks to Proxmox VE clusters and containerized execution with Docker.

### 🖥️ Desktop, Software & AI Agents
* **[Desktop Shells & GUI](Desktop-Shells-and-UI)**: Enabling WinXShell, Microsoft WinFile, and WezTerm GPU terminal on Windows Server Core.
* **[Package Management with OmniGet](Package-Management-with-OmniGet)**: Managing developer tools, hot-swapping in-use files, Ninite bundles, and recipes with OmniGet (`og`).
* **[Autonomous AI Agent Workstation](Autonomous-AI-Agent-Workstation)**: Configuring Google Antigravity CLI, Claude Code CLI, and headless daemon orchestration.

### 🛡️ Governance, Standards & Operations
* **[Brand Identity & Assets](Brand-Identity-and-Assets)**: Brand manual summary, color palettes, vector SVG assets, and ASCII MOTD banner.
* **[Agent Operating Guidelines](Agent-Operating-Guidelines)**: Rules for AI agents, worktree lifecycle, coding standards, and filesystem hierarchy policies.
* **[Release & Versioning Guide](Release-and-Versioning-Guide)**: Semantic Versioning (SemVer 2.0.0), Git tags single source of truth, and GitHub Actions CI/CD release pipeline.
* **[Troubleshooting & FAQ](Troubleshooting-and-FAQ)**: Diagnosing OpenSSH, WinRM, KVM permissions, Windows activation, and common questions.

---

## ⚖️ Legal Disclaimer

> [!IMPORTANT]
> **Windows CoreOS is an open-source automation layer distributed under the MIT License.**
> This project DOES NOT mirror, host, or redistribute proprietary Microsoft Windows binaries, ISO media, or product activation keys.
> Users must obtain their own legitimate installation media directly from official Microsoft channels.
> *Microsoft, Windows, Windows Server, Hyper-V, and PowerShell are registered trademarks of Microsoft Corporation.*
