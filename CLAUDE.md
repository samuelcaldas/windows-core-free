# Windows Core Headless Development Host

## 1. Project Overview & Objective

This repository maintains the automated build, customization, unattended installation, and lifecycle management of a lightweight, generic **Windows Server Core** environment running inside a headless **Linux (Ubuntu)** host.

The guest is based on **Microsoft Hyper-V Server 2019** (Windows Server Core RS5, build 17763), customized to act as a pure, lightweight Windows development and agent execution node.

### Key Goals
- **Generic Windows Core Guest**: Run a stripped-down, headless Windows environment on top of Linux KVM/QEMU or Docker.
- **AI Agent & CLI Workstation**: Execute developer tooling and agentic CLI workflows natively on Windows, including:
  - **Google Antigravity CLI** (`antigravity-cli`) & **Headless Remote Control** (`agy-daemon` via [Antigravity Remote Control](https://antigravity.google/docs/remote-control/)).
  - **Anthropic Claude CLI** (`claude-cli`).
  - **OpenAI Codex CLI** (`codex-cli`).
  - **Node.js, Python, Git, and .NET runtime environments**.
- **Hyper-V Role Deactivation**: Since the Windows Core system operates purely as a virtualized guest on Linux KVM, all nested Hyper-V roles, virtualization services, and hypervisor components are disabled/removed to save RAM/CPU and eliminate hypervisor conflicts.
- **Remote Access First**: Primary interaction through **OpenSSH Server**, **PowerShell Remoting (WinRM / PSSession)**, and background daemon APIs (`agy-daemon`).
- **Fully Automated Provisioning**: Zero-touch installation using customized answer files (`autounattend.xml`), VirtIO drivers, and headless provisioning scripts.

---

## 2. Infrastructure & Host Architecture

### Host Environment
- **Host OS**: Ubuntu Desktop (headless configuration).
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

## 3. Windows Image Customization & Unattended Setup

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
  - Decommissioning Hyper-V hypervisor role (`Remove-WindowsFeature Hyper-V` or dism package removal).

---

## 4. Modular Two-Stage Provisioning & Developer Stack

The provisioning is structured in two distinct, decoupled stages:

### Stage 1: Minimal Core Bootstrap (Unattended FirstBoot)
Executed automatically by `autounattend.xml` during OS installation:
1. **VirtIO Guest Integration**: Drivers, QEMU guest agent, ballooning service.
2. **PowerShell 7 (`pwsh`)**: Modern PowerShell core runtime.
3. **OpenSSH Server**: Configured as an automatic Windows Service with Password Authentication enabled initially, with PowerShell 7 set as the default SSH shell (`DefaultShell = "C:\Program Files\PowerShell\7\pwsh.exe"`).
4. **Hyper-V Role Deactivation**: Disables the Hyper-V hypervisor role (`Disable-WindowsOptionalFeature -FeatureName Microsoft-Hyper-V-All`) and disables hypervisor boot launch (`bcdedit /set hypervisorlaunchtype off`) to free memory/CPU and avoid virtualization conflicts.
5. **Firewall Rules**: Open ports for SSH (`22`), WinRM (`5985`/`5986`), and Antigravity Daemon (`9090`).

### Stage 2: Remote Toolchain & Agent Orchestration (Post-Boot via SSH)
Managed and triggered remotely from the Linux host over SSH/WinRM:
1. **SSH Key Exchange**: Script pushes host SSH public key (`~/.ssh/id_ed25519.pub`) to `C:\ProgramData\ssh\administrators_authorized_keys` with correct Windows ACLs, enabling key-based authentication.
2. **Developer Toolchains**:
   - Docker CLI & Docker Compose (standalone native client with remote SSH contexts).
   - Git for Windows (configured with long paths and LF line endings).
   - GitHub CLI (`gh`).
   - Node.js LTS (via standalone installer or `fnm`).
   - Python 3.x with `.venv` and pip.
   - .NET Core / Framework SDK.
2. **AI Agent Tooling**:
   - **Google Antigravity CLI** (`antigravity-cli`) & **Headless Remote Control** (`agy-daemon` via [Antigravity Remote Control](https://antigravity.google/docs/remote-control/)).
   - **Persistence**: `agy-daemon` is registered as a background **Windows Service / Scheduled Task at Boot** running under the `samuelcaldas` account for 24/7 headless availability.
   - **Claude CLI** (`claude-cli`).
   - **Codex CLI** (`codex-cli`).

---

## 5. Repository Structure

```
windows-core/
├── autounattend.xml             # Unattended dual-drive installation answer file
├── config/
│   ├── explorerpp/              # Pre-configured portable Explorer++ config.xml
│   ├── hosts/                   # Dan Pollock zero-route hosts blocklist
│   └── winxshell/               # Shell settings & WinXShell.lua
├── docs/                        # Architecture and remote access documentation
│   ├── README.md                # Documentation index
│   └── ssh-configuration.md     # SSH client config & ProxyJump guide
├── external/
│   ├── Atlas/                   # Git Submodule: AtlasOS Windows optimization scripts
│   ├── ReactShell/              # Git Submodule: Standalone ReactOS Win32 Explorer & File Manager
│   └── winfile/                 # Git Submodule: Microsoft Windows File Manager (WinFile)
├── iso/                         # Base Windows ISOs and offline package cache (gitignored)
├── scripts/
│   ├── host/                    # Linux host management scripts (Dual Bash & PowerShell 7)
│   │   ├── build-iso.sh / .ps1  # Generates unattended installer & OEMDRV ISOs
│   │   ├── install-desktopshell.sh / .ps1 # Sets up WinXShell (default), WinFile, ReactShell, Explorer++
│   │   ├── install-ninite.sh / .ps1       # Interactive TUI Ninite app store
│   │   ├── install-terminal.sh / .ps1     # Deploys WezTerm wt.exe engine with OpenGL
│   │   ├── optimize-vm.sh / .ps1          # Deep memory optimization & Defender uninstallation
│   │   ├── provision-remote.sh / .ps1     # SSH key exchange & remote toolchain orchestration
│   │   ├── run-vm.sh / .ps1               # Starts QEMU/KVM instance with VirtIO & port forwarding
│   │   ├── setup-host.sh / .ps1           # Prepares Ubuntu dependencies (qemu, ovmf, virtio-win)
│   │   └── update-hosts.sh / .ps1         # Deploys Dan Pollock zero-route hosts blocklist
│   └── guest/                   # Post-installation guest configuration scripts
│       ├── Disable-HyperV.ps1   # Deactivates nested Hyper-V roles and services
│       ├── Install-DesktopShell.ps1 # Configures WinXShell (default), WinFile, ReactShell, Explorer++
│       ├── Install-NiniteApps.ps1   # Interactive PowerShell TUI for Ninite installers
│       ├── Install-Tools.ps1    # Installs Git, Node, Python, PowerShell 7, gh CLI
│       ├── Install-WindowsTerminal.ps1 # Installs WezTerm with wt.exe & OpenGL support
│       ├── Optimize-System.ps1  # Uninstalls Defender/Hyper-V, disables SysMain/Telemetry
│       ├── Setup-Agents.ps1     # Installs antigravity-cli, claude-cli, agy-daemon service
│       ├── Specialize.ps1       # System specialization & feature removal bootstrap
│       └── Update-HostsBlocklist.ps1 # Installs DNS hosts blocklist
├── README.md                    # Project landing page and quickstart guide
├── GEMINI.md                    # System architecture reference (this file)
└── CLAUDE.md                    # Operational and coding rules
```

---

## 6. Commands & Workflows

### 1. Host Preparation
```bash
# Install virtualization prerequisites on Ubuntu
sudo apt-get update && sudo apt-get install -y qemu-system-x86 qemu-utils ovmf cloud-image-utils
```

### 2. ISO / Unattended Preparation
```bash
# Create unattended installer ISO and secondary OEMDRV media
./scripts/host/build-iso.sh
```

### 3. Launching Windows Core VM
```bash
# Boot VM with KVM acceleration, VirtIO disk/net, and forwarded SSH/WinRM/Daemon ports
./scripts/host/run-vm.sh
```

### 4. Remote Management from Ubuntu Host (`ssh winvm`)
```bash
# Connect directly via SSH alias (configured in ~/.ssh/config)
ssh winvm

# Or connect via explicit port
ssh -p 2222 samuelcaldas@localhost

# Connect via PowerShell Remoting
pwsh -Command "Enter-PSSession -HostName localhost -Port 2222 -UserName samuelcaldas"
```

### 5. Memory Optimization & System Protection
```bash
# Optimize memory and strip Defender/Hyper-V features (down to ~530MB RAM)
./scripts/host/optimize-vm.sh

# Deploy Dan Pollock zero-route DNS hosts blocklist (13,371 rules)
./scripts/host/update-hosts.sh
```
