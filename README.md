# Windows Core Headless Development Host

An automated build, unattended installation, memory optimization, and lifecycle management toolkit for running an ultra-lightweight, generic **Windows Server Core** virtualized workstation on **Linux (Ubuntu / KVM / Proxmox)**.

---

## ⚡ Highlights

- **Ultra-Low Memory Footprint**: Stripped from ~2.1 GB down to **~530 MB RAM idle** by uninstalling Windows Defender (`MsMpEng`) and Hyper-V roles, and disabling Superfetch (`SysMain`), Telemetry, and error reporting.
- **SSH-First Remote Management**: Connect directly via `ssh winvm` with **PowerShell 7** as the default shell and public key authentication.
- **Desktop Environment**: Lightweight **WinXShell** (`WinXShell.exe -winpe`) as the primary default Win32 shell provider and **WinFile** (Microsoft Windows File Manager) as the default File Explorer (`explorer.exe` link), with ReactShell, ReactFM, and Explorer++ preserved as modular alternatives.
- **Tabbed Terminal**: WezTerm engine with `wt.exe` launcher, Cascadia Code fonts, and Mesa software OpenGL rendering for Windows Server Core.
- **DNS Blocklist**: Dan Pollock zero-route (`0.0.0.0`) hosts blocklist blocking 13,371 ad, tracker, telemetry, and malware domains.
- **AI Agent & CLI Stack**: Pre-configured with Docker CLI & Docker Compose (standalone client), Git for Windows, GitHub CLI (`gh`), Node.js, Python 3.12, Claude Code CLI, and Google Antigravity daemon (`agy-daemon`).

---

## 🔌 Quick Start & SSH Access

### 1. SSH Client Config (`~/.ssh/config`)
```sshconfig
Host winvm
    HostName 127.0.0.1
    User samuelcaldas
    Port 2222
    IdentityFile ~/.ssh/id_ed25519
    StrictHostKeyChecking accept-new
    ForwardAgent yes
```

### 2. Connect
```bash
# Open interactive PowerShell 7 shell
ssh winvm

# Run remote commands
ssh winvm "docker --version; docker compose version; gh --version; git --version"
```

For remote server access and ProxyJump configuration, see the **[SSH Configuration Guide](file:///home/samuelcaldas/repos/windows-core/docs/ssh-configuration.md)**.

---

## 📁 Repository Structure

```
windows-core/
├── autounattend.xml             # Unattended dual-drive installation answer file
├── config/
│   ├── explorerpp/              # Explorer++ portable config.xml
│   ├── hosts/                   # Dan Pollock zero-route hosts blocklist
│   ├── systemd/                 # Systemd service unit template (windows-core.service)
│   └── winxshell/               # WinXShell settings & Lua scripts
├── docs/                        # Architecture & SSH documentation
│   ├── README.md
│   └── ssh-configuration.md
├── external/
│   ├── Atlas/                   # Git Submodule: AtlasOS Windows optimization scripts
│   ├── ReactShell/              # Git Submodule: Standalone ReactOS Win32 Explorer & File Manager
│   ├── winfile/                 # Git Submodule: Microsoft Windows File Manager (WinFile)
│   └── omniget/                 # Git Submodule: OmniGet (og) Universal Package Engine
├── iso/                         # Downloaded packages & ISO cache (gitignored)
├── scripts/
│   ├── guest/                   # Windows guest provisioning & optimization scripts
│   │   ├── Disable-HyperV.ps1   # Deactivates nested Hyper-V roles
│   │   ├── Install-DesktopShell.ps1 # Sets up WinXShell and Explorer++
│   │   ├── Install-OmniGet.ps1  # Deploys OmniGet (og) Universal Package Manager
│   │   ├── Install-Tools.ps1    # Installs Git, Node, Python, PowerShell 7, gh via OmniGet
│   │   ├── Install-WindowsTerminal.ps1 # Deploys WezTerm wt.exe engine with OpenGL
│   │   ├── Optimize-System.ps1  # In-place memory optimization & Defender uninstallation
│   │   ├── Setup-Agents.ps1     # Deploys Claude Code CLI and Antigravity daemon
│   │   ├── Specialize.ps1       # System specialization bootstrap
│   │   └── Update-HostsBlocklist.ps1 # Deploys DNS hosts blocklist
│   └── host/                    # Linux host management scripts (Bash & PowerShell 7)
│       ├── build-iso.sh / .ps1  # Generates unattended installer & OEMDRV ISOs
│       ├── install-desktopshell.sh / .ps1
│       ├── install-omniget.sh / .ps1 # Deploys & runs OmniGet interactive TUI over SSH
│       ├── install-terminal.sh / .ps1
│       ├── optimize-vm.sh / .ps1
│       ├── provision-remote.sh / .ps1
│       ├── run-vm.sh / .ps1
│       ├── setup-host.sh / .ps1
│       ├── setup-service.sh / .ps1  # Configures systemd autostart on Ubuntu boot
│       └── update-hosts.sh / .ps1
├── CLAUDE.md                    # Project guidelines & Calisthenics rules
└── GEMINI.md                    # Detailed architecture & reference manual
```

---

## 🏛️ Filesystem & Program Installation Standards

To ensure consistency, security, and avoid drive root clutter, all scripts and package installations in this distribution follow strict filesystem rules:

- **No Root `C:\` Application Directories**: Applications and runtimes must **never** be placed directly on the root drive (e.g. `C:\Tools`, `C:\ReactShell`, `C:\XPShell`, `C:\OmniGet`, `C:\Python27` are prohibited).
- **Standard 64-bit Directory**: All 64-bit packages, runtimes, shells, and CLI utilities install under `C:\Program Files\<VendorOrToolName>` (e.g. `C:\Program Files\OmniGet`, `C:\Program Files\dotnet`, `C:\Program Files\WinXShell`, `C:\Program Files\PowerShell\7`).
- **Standard 32-bit Directory**: 32-bit components install under `C:\Program Files (x86)\<VendorOrToolName>`.
- **System Data & Non-Binary State**: Host keys, daemon databases, and global app data reside in `C:\ProgramData\<AppName>`.
- **User Configurations & Dotfiles**: User-specific configuration resides in `%APPDATA%`, `%LOCALAPPDATA%`, or `C:\Users\<user>\.<tool>`.
- **Transient Installer Storage**: Downloads and intermediate extractions occur in `%TEMP%\<folder>` and are cleaned up upon exit.
- **Unattended Bootstrap Staging**: `C:\Provisioning` is strictly reserved for unattended boot ISO staging and is never a permanent program folder.

---

## 🛠️ Host Automation Commands

```bash
# 1. Prepare host prerequisites (qemu, ovmf, virtio-win)
./scripts/host/setup-host.sh

# 2. Build unattended ISO & OEMDRV image
./scripts/host/build-iso.sh

# 3. Boot Windows Core VM
./scripts/host/run-vm.sh

# 4. Provision developer toolchain & AI agents
./scripts/host/provision-remote.sh

# 5. Optimize memory & strip Defender/Hyper-V (down to ~530MB RAM)
./scripts/host/optimize-vm.sh

# 6. Apply Dan Pollock DNS blocklist
./scripts/host/update-hosts.sh

# 7. Configure systemd service for automatic startup on Ubuntu host boot
./scripts/host/setup-service.sh --install
```

---

## 🚀 Automatic Startup on Ubuntu Boot (Systemd)

To ensure the Windows Server Core VM automatically starts whenever the Ubuntu host boots up:

```bash
# Install, enable autostart on boot, and start the service
./scripts/host/setup-service.sh --install

# Check service status & boot enablement
./scripts/host/setup-service.sh --status

# Follow live systemd logs
./scripts/host/setup-service.sh --logs

# Control service manually
./scripts/host/setup-service.sh --stop       # Gracefully shuts down VM via ACPI
./scripts/host/setup-service.sh --start      # Starts the VM
./scripts/host/setup-service.sh --restart    # Restarts the VM

# Enable or disable boot startup without removing service
./scripts/host/setup-service.sh --enable
./scripts/host/setup-service.sh --disable

# Completely uninstall systemd service
./scripts/host/setup-service.sh --uninstall
```

*Equivalent PowerShell 7 command:*
```powershell
./scripts/host/setup-service.ps1 -Install
```

