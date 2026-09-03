# SSH Configuration & Remote Access Guide

This guide documents how to configure OpenSSH client access to the Windows CoreOS (WCOS) VM from local and remote machines.

---

## 1. Quick SSH Client Configuration (`~/.ssh/config`)

Add the following block to your local machine's `~/.ssh/config` (Linux, macOS, or Windows):

### Direct / Local Host Access
```sshconfig
Host winvm
    HostName 127.0.0.1
    User samuelcaldas
    Port 2222
    IdentityFile ~/.ssh/id_ed25519
    StrictHostKeyChecking accept-new
    ForwardAgent yes
```

### Remote / Jumper Host Access (ProxyJump)
If accessing the Windows CoreOS (WCOS) VM running on a remote Ubuntu server:
```sshconfig
Host winvm
    HostName 127.0.0.1
    User samuelcaldas
    Port 2222
    ProxyJump seu-usuario@ip-do-servidor-host
    IdentityFile ~/.ssh/id_ed25519
    LocalForward 3001 127.0.0.1:3001
    LocalForward 9090 127.0.0.1:9090
    LocalForward 13389 127.0.0.1:3389
```

---

## 2. Usage Examples

### Connect directly
```bash
ssh winvm
```

### Run single remote commands (PowerShell 7)
```bash
# Check installed tools
ssh winvm "pwsh --version; git --version; node --version"

# Start background agent session
ssh winvm "claude"
```

### Interactive TTY sessions
```bash
# GitHub CLI Login
ssh -t winvm "gh auth login"

# Ninite TUI App Store
ssh -t winvm "pwsh -File C:\Provisioning\scripts\Install-NiniteApps.ps1"
```

---

## 3. Architecture & Security Configuration on Guest

- **Server Daemon**: Win32-OpenSSH running as an automatic Windows Service (`sshd`).
- **Default Shell**: `HKLM:\SOFTWARE\OpenSSH\DefaultShell` -> `C:\Program Files\PowerShell\7\pwsh.exe`.
- **Public Key Authentication**: Stored in `C:\ProgramData\ssh\administrators_authorized_keys` with strict Windows ACLs (`SYSTEM` and `Administrators` full control only).
- **Firewall**: Windows Defender Firewall port `22` (TCP) allowed for inbound connections.
