# Product Context: Windows CoreOS (WCOS)

## Product Mission
Windows CoreOS (WCOS) is a free, ultra-lightweight, automated Windows Server Core distribution running on headless Linux hosts (Ubuntu / Debian / KVM / Proxmox). It transforms vanilla Microsoft Hyper-V Server 2019 into a dedicated, high-performance developer workstation and autonomous AI agent execution node.

## The Core Problem
1. **Excessive RAM Overhead**: Standard Windows Server installations consume 2.1 GB to 2.8 GB of RAM at idle, making them prohibitively heavy for multi-tenant Linux hosts or modest VPS environments.
2. **Hypervisor Role Conflicts**: Nested Hyper-V roles enabled by default create CPU scheduling overhead and hypervisor conflicts when running virtualized under Linux KVM.
3. **Lack of Headless Automation**: Windows Server defaults to interactive setups, manual installers, and heavy GUI shells rather than clean OpenSSH CLI remoting and scripted package management.
4. **AI Agent Tooling Gap**: Emerging autonomous AI CLI agents (Google Antigravity, Claude Code, OpenAI Codex) require native Windows environments for specific workloads, yet lack lightweight, automated Windows VMs.

## The Solution & Value Proposition
* **Radical Memory Efficiency**: Drops idle RAM consumption down to **~530 MB** (a >75% reduction) by removing Windows Defender, deactivating Hyper-V nested roles, disabling Superfetch (SysMain), and consolidating service host processes.
* **Remote-First Architecture**: OpenSSH Server pre-configured with modern **PowerShell 7 (`pwsh.exe`)** as the default shell, ED25519 public key authentication, and WinRM support.
* **Autonomous AI Agent Execution**: Native support and pre-configured daemons for Google Antigravity Daemon (`agy-daemon` on port 9090), Claude Code CLI, and Codex CLI.
* **Universal Package Engine**: Powered by **OmniGet (`og`)**, providing zero-downtime hot-swap binary updates, Ninite dynamic bundles, and curated presets.
* **Zero-Touch Provisioning**: Automated unattended setup using dual-drive ISO injection (`autounattend.xml` + `oemdrv.iso`), GPT partitioning, and VirtIO paravirtualized drivers.
* **Linux Host Native**: Supervised by native Linux `systemd` (`windows-core.service`) with graceful ACPI shutdown.

## Target Audience
1. **Systems & DevOps Engineers**: Needing a reproducible, lightweight Windows build node for CI/CD pipelines (GitHub Actions, GitLab CI).
2. **Autonomous AI Agents & Researchers**: Running multi-agent CLI workflows that require a dedicated, low-overhead Windows execution sandbox.
3. **Linux / Proxmox Administrators**: Wanting Windows capability on home labs or enterprise virtualization clusters without paying a memory penalty.

## Success Metrics
* Idle RAM footprint < 600 MB.
* Zero-touch installation time < 7 minutes from boot to SSH availability.
* Zero broken links and 100% test pass rate across all host and guest automation scripts.
