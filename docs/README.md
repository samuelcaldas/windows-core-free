# Windows Core Documentation Index

Welcome to the technical documentation for the **Windows Core Headless Development Host** project.

---

## 📚 Table of Contents

| Document | Description |
| :--- | :--- |
| **[SSH Configuration Guide](file:///home/samuelcaldas/repos/windows-core/docs/ssh-configuration.md)** | Client `~/.ssh/config` setups, ProxyJump tunnels, and port forwards for `winvm`. |
| **[System Architecture & Overview](file:///home/samuelcaldas/repos/windows-core/GEMINI.md)** | Full infrastructure blueprint, QEMU/KVM tuning, memory optimizations, and component breakdown. |

---

## 🚀 Key Features & Stack Overview

- **OS**: Windows Server Core 2019 (RS5 build 17763), stripped and memory-optimized to **~530 MB RAM idle**.
- **Remote Access**: Win32-OpenSSH with PowerShell 7 (`pwsh.exe`) default shell.
- **Desktop Shell**: Standalone **ReactShell** (`react-shell.exe` + `react-fm.exe`) Win32 explorer shell and file manager (WinXShell & Explorer++ available as optional fallbacks).
- **Terminal**: WezTerm engine with `wt.exe` alias, Cascadia Code fonts, and Mesa software OpenGL rendering.
- **Protection**: Native Dan Pollock zero-route hosts blocklist with 13,371 ad/tracker/malware rules.
- **Developer Stack**: Docker CLI & Docker Compose (standalone), Git, Node.js LTS, Python 3.12, .NET, GitHub CLI (`gh`), Claude Code CLI, and Google Antigravity daemon.
