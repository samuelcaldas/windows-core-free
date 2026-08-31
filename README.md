# Windows Core Headless Development Host

An automated build, unattended installation, memory optimization, and lifecycle management toolkit for running an ultra-lightweight, generic **Windows Server Core** virtualized workstation on **Linux (Ubuntu / KVM / Proxmox)**.

---

## ⚡ Highlights

- **Ultra-Low Memory Footprint**: Stripped from ~2.1 GB down to **~530 MB RAM idle** by uninstalling Windows Defender (`MsMpEng`) and Hyper-V roles, and disabling Superfetch (`SysMain`), Telemetry, and error reporting.
- **SSH-First Remote Management**: Connect directly via `ssh winvm` with **PowerShell 7** as the default shell and public key authentication.
- **Optional Desktop Environment**: Lightweight WinXShell + Explorer++ (configured in portable mode as the default system file manager with `explorer.exe` hardlink).
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
│   └── winxshell/               # WinXShell settings & Lua scripts
├── docs/                        # Architecture & SSH documentation
│   ├── README.md
│   └── ssh-configuration.md
├── iso/                         # Downloaded packages & ISO cache (gitignored)
├── scripts/
│   ├── guest/                   # Windows guest provisioning & optimization scripts
│   │   ├── Disable-HyperV.ps1   # Deactivates nested Hyper-V roles
│   │   ├── Install-DesktopShell.ps1 # Sets up WinXShell and Explorer++
│   │   ├── Install-NiniteApps.ps1   # Interactive TUI Ninite app store
│   │   ├── Install-Tools.ps1    # Installs Git, Node, Python, PowerShell 7, gh
│   │   ├── Install-WindowsTerminal.ps1 # Deploys WezTerm wt.exe engine with OpenGL
│   │   ├── Optimize-System.ps1  # In-place memory optimization & Defender uninstallation
│   │   ├── Setup-Agents.ps1     # Deploys Claude Code CLI and Antigravity daemon
│   │   ├── Specialize.ps1       # System specialization bootstrap
│   │   └── Update-HostsBlocklist.ps1 # Deploys DNS hosts blocklist
│   └── host/                    # Linux host management scripts (Bash & PowerShell 7)
│       ├── build-iso.sh / .ps1  # Generates unattended installer & OEMDRV ISOs
│       ├── install-desktopshell.sh / .ps1
│       ├── install-ninite.sh / .ps1
│       ├── install-terminal.sh / .ps1
│       ├── optimize-vm.sh / .ps1
│       ├── provision-remote.sh / .ps1
│       ├── run-vm.sh / .ps1
│       ├── setup-host.sh / .ps1
│       └── update-hosts.sh / .ps1
├── CLAUDE.md                    # Project guidelines & Calisthenics rules
└── GEMINI.md                    # Detailed architecture & reference manual
```

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
```
