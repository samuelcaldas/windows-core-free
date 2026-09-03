# Windows CoreOS (WCOS) — System Architecture & Agent Guidelines

## 1. Project Overview & Objective

This repository maintains the automated build, customization, unattended installation, and lifecycle management of **Windows CoreOS (WCOS)**: a free, lightweight Windows Server Core distribution running on a headless **Linux (Ubuntu / KVM / Proxmox)** host.

The guest is based on **Microsoft Hyper-V Server 2019** (Windows Server Core RS5, build 17763), customized to act as a pure, lightweight Windows development, DevOps, and autonomous AI agent execution node.

### Key Goals
- **Windows CoreOS (WCOS)**: Run an ultra-lightweight, stripped-down headless Windows environment on Linux KVM/QEMU, Proxmox VE, or Docker.
- **AI Agent & Automation Workstation**: Execute developer tooling and agentic CLI workflows natively on Windows, including:
  - **Google Antigravity CLI** (`antigravity-cli`) & **Headless Remote Control** (`agy-daemon` via [Antigravity Remote Control](https://antigravity.google/docs/remote-control/)).
  - **Anthropic Claude Code CLI** (`claude-cli`).
  - **OpenAI Codex CLI** (`codex-cli`).
  - **Node.js, Python, Git, and .NET runtime environments**.
- **Hyper-V Role Deactivation**: Since Windows CoreOS operates purely as a virtualized guest on Linux KVM, all nested Hyper-V roles, virtualization services, and hypervisor components are disabled/removed to save RAM/CPU and eliminate hypervisor conflicts.
- **Remote Access First**: Primary interaction through **OpenSSH Server**, **PowerShell Remoting (WinRM / PSSession)**, and background daemon APIs (`agy-daemon`).
- **Fully Automated Provisioning**: Zero-touch installation using customized answer files (`autounattend.xml`), VirtIO drivers, and headless provisioning scripts.

---

## 2. Legal Notice & Upstream ISO Requirement

> [!IMPORTANT]
> **Windows CoreOS is an open-source automation layer distributed under the MIT License.**
> This repository DOES NOT redistribute, host, or mirror proprietary Microsoft Windows binaries, ISO installation media, or product keys.
> Users must obtain their own legitimate, officially licensed or evaluation copy of Microsoft Hyper-V Server 2019 / Windows Server 2019 from official Microsoft channels.
> Microsoft, Windows, Windows Server, Hyper-V, and PowerShell are registered trademarks of Microsoft Corporation. Windows CoreOS is not affiliated with or endorsed by Microsoft Corporation.

### Official Microsoft ISO Reference:
- **Image Name**: `17763.737.190906-2324.rs5_release_svc_refresh_SERVERHYPERCORE_OEM_x64FRE_en-us_1.iso`
- **Direct Download**: [Microsoft CDN Link](https://software-download.microsoft.com/download/pr/17763.737.190906-2324.rs5_release_svc_refresh_SERVERHYPERCORE_OEM_x64FRE_en-us_1.iso)
- **Evaluation Center**: [Microsoft Evaluation Center Portal](https://www.microsoft.com/en-us/evalcenter/evaluate-hyper-v-server-2019)
- **SHA256 Hash**: `48e9b944518e5bbc80876a9a7ff99716f386f404f4be48dca47e16a66ae7872c`
- **Automated Download**: `./scripts/host/setup-host.sh --download-iso`

---

## 3. Infrastructure & Host Architecture

### Host Environment
- **Host OS**: Ubuntu Desktop / Server (headless configuration).
- **Host Administration**: Root access via `ssh root@localhost` with PowerShell (`pwsh`) / bash scripting.
- **Virtualization Engine**:
  - **Primary**: Direct KVM / QEMU automation (via optimized bash/pwsh scripts and optional systemd service) for maximum performance, direct VirtIO device control, and minimal overhead.
  - **Secondary / Alternative**: Docker container wrapper (KVM pass-through via `/dev/kvm` with Docker Compose for portable deployment).
  - **Roadmap / Portability**: Full compatibility with **Proxmox VE** (native QCOW2 and VirtIO architecture enables direct import/migration to Proxmox clusters).

### Storage & Virtual Disks
- **Format**: Dynamic **Sparse QCOW2** (`qemu-img create -f qcow2 windows-core.qcow2 64G`) with `discard=unmap` (TRIM) and instant snapshot support for safe rollbacks before running experimental code or AI agents.
- **Secondary (Docker)**: Named Docker volume when running via container wrapper.

### Network & Port Map
| Service | Guest Port | Default Host Port / Access | Purpose |
| :--- | :--- | :--- | :--- |
| **OpenSSH** | `22` | `2222` (or host bridged IP) | Direct CLI / terminal access & agent sessions |
| **WinRM (HTTPS/HTTP)** | `5986` / `5985` | `5986` / `5985` | PowerShell Remoting (`Enter-PSSession`, Ansible) |
| **Antigravity Daemon** | `9090` (default) | `9090` | Headless Remote Control (`agy-daemon`) |
| **RDP (Optional)** | `3389` | `3389` | Fallback graphical / console debugging |

---

## 4. Windows Image Customization & Unattended Setup

### Base ISO & Provisioning Strategy
- **Base Image**: `iso/17763.737.190906-2324.rs5_release_svc_refresh_SERVERHYPERCORE_OEM_x64FRE_en-us_1.iso` (Microsoft Hyper-V Server 2019 OEM x64, kept unmodified).
- **Provisioning Method**: **Dual-drive unattended boot**.
  - A helper script generates a secondary virtual ISO / FAT drive (`oemdrv.iso` or `unattend.img`) containing `autounattend.xml`, VirtIO drivers, and initial bootstrap scripts.
  - Windows Setup automatically detects `autounattend.xml` from the secondary drive, loads VirtIO storage and network drivers on-the-fly, and completes zero-touch installation directly onto the VirtIO virtual disk (`.qcow2`).

### Unattended Specification (`autounattend.xml`)
- **Localization**:
  - UI Language: `en-US`
  - System Locale & Format: `pt-BR`
  - Keyboard Layout: `0416:00000416` (ABNT2)
  - Timezone: `E. South America Standard Time` (`America/Sao_Paulo`, UTC-3)
- **User Accounts**:
  - `samuelcaldas` (Administrator group, non-expiring password)
  - Built-in `Administrator` (AutoLogon enabled for first boot provisioning)
- **Performance & Security Tuning**:
  - Bypasses: TPM, SecureBoot, RAM checks for virtualized environments.
  - Disable: UAC, SmartScreen, SAC, Fast Startup, System Restore, Hibernation, Telemetry, Bing search, Edge background tasks.
  - Enable: Long File Paths (>260 chars), PowerShell Unrestricted script execution, Remote Desktop, OpenSSH Server.
  - VirtIO: Automated VirtIO guest tools and driver installation.
- **Component Pruning**:
  - Removal of consumer apps, Xbox services, Cortana, Edge bloatware, telemetry packages, and non-essential capabilities.
  - Decommissioning Hyper-V hypervisor role (`Disable-WindowsOptionalFeature -FeatureName Microsoft-Hyper-V-All`).

---

## 5. Modular Two-Stage Provisioning & Developer Stack

### Stage 1: Minimal Core Bootstrap (Unattended FirstBoot)
Executed automatically by `autounattend.xml` during OS installation:
1. **VirtIO Guest Integration**: Drivers, QEMU guest agent, ballooning service.
2. **PowerShell 7 (`pwsh`)**: Modern PowerShell core runtime.
3. **OpenSSH Server**: Configured as an automatic Windows Service with Password Authentication enabled initially, with PowerShell 7 set as the default SSH shell (`DefaultShell = "C:\Program Files\PowerShell\7\pwsh.exe"`).
4. **Hyper-V Role Deactivation**: Disables the Hyper-V hypervisor role and disables hypervisor boot launch (`bcdedit /set hypervisorlaunchtype off`).
5. **Firewall Rules**: Open ports for SSH (`22`), WinRM (`5985`/`5986`), and Antigravity Daemon (`9090`).

### Stage 2: Remote Toolchain & Agent Orchestration (Post-Boot via SSH)
Managed and triggered remotely from the Linux host over SSH/WinRM:
1. **SSH Key Exchange**: Script pushes host SSH public key (`~/.ssh/id_ed25519.pub`) to `C:\ProgramData\ssh\administrators_authorized_keys` with correct Windows ACLs.
2. **Developer Toolchains & Package Management**:
   - **OmniGet (og)**: Universal multi-source package manager deployed to `C:\Program Files\OmniGet`.
   - Docker CLI & Docker Compose (standalone native client in `C:\Program Files\Docker`).
   - Git for Windows (`C:\Program Files\Git` configured with long paths and LF line endings).
   - GitHub CLI (`C:\Program Files\GitHub CLI\gh.exe`).
   - Node.js LTS (`C:\Program Files\nodejs`).
   - Python 3.x (`C:\Program Files\Python312` with `.venv` and pip).
   - .NET SDK (`C:\Program Files\dotnet` with .NET 10.0 and 8.0).
3. **AI Agent Tooling**:
   - **Google Antigravity CLI** (`antigravity-cli`) & **Headless Remote Control** (`agy-daemon` on port 9090).
   - **Claude Code CLI** (`claude-cli`).
   - **Codex CLI** (`codex-cli`).

### Filesystem & Installation Directory Hierarchy Policy
To maintain system cleanliness, predictable PATH resolution, and standard Windows security permissions:
* **STRICT PROHIBITION of Root `C:\` Application Folders**: Applications, runtimes, portable tools, utilities, shell replacements, or package managers MUST NEVER create installation or binary directories directly on the root drive (e.g. `C:\ReactShell`, `C:\XPShell`, `C:\Python27`, `C:\OmniGet`, `C:\Tools` are strictly forbidden).
* **64-bit Applications & Runtimes**: Must be installed under `C:\Program Files\<VendorOrToolName>` (e.g., `C:\Program Files\OmniGet`, `C:\Program Files\WinXShell`, `C:\Program Files\WinFile`, `C:\Program Files\WindowsTerminal`, `C:\Program Files\dotnet`, `C:\Program Files\PowerShell\7`, `C:\Program Files\Docker`, `C:\Program Files\Git`).
* **32-bit Applications**: Must be installed under `C:\Program Files (x86)\<VendorOrToolName>`.
* **System-Wide Application Data & State**: Non-binary state, host keys, daemon data, and global configuration must reside under `C:\ProgramData\<AppName>` (e.g. `C:\ProgramData\ssh`, `C:\ProgramData\OmniGet`).
* **User Data & Cache**: User-specific configuration and caches must reside in `%APPDATA%`, `%LOCALAPPDATA%`, or `C:\Users\<user>\.<tool>`.
* **Temporary Installer Artifacts**: Download and extract transient installers in `%TEMP%\<installer_folder>` and clean up on exit.
* **Unattended Bootstrap Staging**: `C:\Provisioning` is reserved strictly for temporary OS initialization scripts and offline package cache during unattended setup; it must never serve as an application's permanent runtime installation directory.

---

## 6. Agent Operating Guidelines & Versioning

### 6.1 Worktree Lifecycle for Agents
Agents operating in this repository must follow the worktree lifecycle strictly:
1. `git fetch origin && git rebase origin/master`
2. `git worktree add .worktrees/<name> -b <name>`
3. Commit logical changes incrementally.
4. Clean working tree check before merge (`git status` must be clean).
5. Merge `--no-ff` directly into `master`.
6. Cleanup: remove worktree and delete branch.

### 6.2 Versioning & Release Bumping (SemVer 2.0.0)
- **Single Source of Truth**: Annotated Git Tags (`v*`). No separate `VERSION` file.
- **Bumping Steps**:
  1. Determine next SemVer (`vX.Y.Z`).
  2. Create annotated tag: `git tag -a vX.Y.Z -m "release: Windows CoreOS vX.Y.Z"`.
  3. Push tag: `git push origin vX.Y.Z`.
  4. GitHub Actions automatically executes `.github/workflows/release.yml`, generating `wcos-scripts.zip`, `wcos-oemdrv-template.zip`, and GitHub release notes.
- Refer to [`docs/VERSIONING.md`](docs/VERSIONING.md) for full instructions.
