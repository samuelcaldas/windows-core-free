---
layout: home

hero:
  name: Windows CoreOS
  text: Free Windows Server Core Distribution
  tagline: Ultra-lightweight headless Windows Server Core RS5 for Linux KVM, Proxmox, and Autonomous AI Agents. Drops idle RAM to ~530 MB.
  image:
    src: /hero.svg
    alt: Windows CoreOS Logo
  actions:
    - theme: brand
      text: Get Started →
      link: /guides/Getting-Started
    - theme: alt
      text: Architecture
      link: /guides/Architecture-and-Hardware
    - theme: alt
      text: GitHub Releases
      link: https://github.com/samuelcaldas/windows-core-free/releases

features:
  - icon: 📉
    title: ~530 MB Idle RAM
    details: Reclaims over 75% of RAM compared to stock Windows Server by eliminating nested Hyper-V, Defender, SysMain, and telemetry bloatware.
  - icon: 🔑
    title: OpenSSH & PowerShell 7
    details: Native headless management over SSH with ED25519 keys, PowerShell 7 default shell, ProxyJump tunnels, and WinRM remoting.
  - icon: 🤖
    title: Autonomous AI Agent Node
    details: Pre-configured execution environment for Google Antigravity Daemon (port 9090), Claude Code CLI, and OpenAI Codex CLI.
  - icon: 📦
    title: OmniGet Package Engine
    details: Universal multi-source package manager with Ninite bundles, zero-downtime hot-swap binary updates, and curated stacks.
  - icon: 🏎️
    title: Linux KVM & VirtIO Native
    details: Paravirtualized VirtIO SCSI with TRIM discard, VirtIO Net, UEFI OVMF firmware, and instant QCOW2 snapshots.
  - icon: 🖥️
    title: Modular Desktop Environment
    details: Optional WinXShell desktop, Microsoft WinFile, and WezTerm GPU terminal consuming less than 30MB additional RAM.
---

<div class="vp-doc" style="margin-top: 3rem;">

## 📊 Live RAM Footprint Benchmark

```
Stock Windows Server 2019 Core (Fresh Boot)
[████████████████████████████████████████] ~2,100 MB RAM

Windows CoreOS (WCOS) after Optimization
[██████████] ~530 MB RAM (75% RAM Reduction!)
```

| Component | Stock Windows Server 2019 | Windows CoreOS (WCOS) | Reclaimed RAM |
| :--- | :--- | :--- | :--- |
| **Windows Defender** (`MsMpEng.exe`) | Active (real-time disk scan) | Removed via DISM | ~250 MB |
| **Nested Hyper-V Roles** (`vmms.exe`) | Enabled by default | Decommissioned | ~220 MB |
| **Superfetch / SysMain** | Active | Disabled | ~100 MB |
| **Telemetry & Error Reporting** | Active | Disabled & Blocked | ~80 MB |
| **Svchost Splitting** | ~60 split processes | Consolidated | ~250 MB |

---

## ⚡ Quick Start: 3 Commands to Boot

From any headless Ubuntu/Debian host:

```bash
# 1. Clone with submodules & prepare host environment
git clone --recurse-submodules https://github.com/samuelcaldas/windows-core-free.git
cd windows-core-free && ./scripts/host/setup-host.sh --download-iso

# 2. Build unattended boot media & assemble VirtIO drivers
./scripts/host/build-iso.sh

# 3. Boot virtual machine in KVM
./scripts/host/run-vm.sh
```

Connect via SSH once installed:
```bash
ssh -p 2222 samuelcaldas@127.0.0.1
```

---

## 🌐 Network Topology & Port Map

| Service | Guest Port | Forwarded Port | Purpose |
| :--- | :--- | :--- | :--- |
| **OpenSSH Server** | `22` | `2222` | Direct CLI access & agent orchestration |
| **WinRM (HTTP/HTTPS)** | `5985` / `5986` | `5985` / `5986` | PowerShell Remoting (`Enter-PSSession`, Ansible) |
| **Antigravity Daemon** | `9090` | `9090` | Headless Remote Control (`agy-daemon`) |
| **RDP Console (Optional)** | `3389` | `3389` | Fallback graphical debugging |

---

## ⚖️ Legal Disclaimer & Official ISO Notice

::: tip LEGAL NOTICE & UPSTREAM ISO REQUIREMENT
**Windows CoreOS is an open-source automation layer distributed under the MIT License.**
This repository DOES NOT redistribute, host, or mirror proprietary Microsoft Windows binaries, ISO installation media, or product keys. Users must obtain their own legitimate copy of Microsoft Hyper-V Server 2019 from official Microsoft channels.

*Microsoft, Windows, Windows Server, Hyper-V, and PowerShell are registered trademarks of Microsoft Corporation.*
:::

</div>
