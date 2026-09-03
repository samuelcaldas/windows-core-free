# Remote Access & OpenSSH Server

This document explains the remote access architecture of **Windows CoreOS (WCOS)**, focusing on OpenSSH Server, PowerShell 7 remoting, ED25519 key exchange, and multi-hop SSH tunnels.

---

## 🔑 Win32-OpenSSH Architecture

Windows CoreOS replaces legacy GUI management with a Linux-native remote administration workflow using **Microsoft Win32-OpenSSH**:

* **Service**: `sshd` and `ssh-agent` running as Windows Services (Automatic startup).
* **Default Shell**: Modern **PowerShell 7 Core** (`C:\Program Files\PowerShell\7\pwsh.exe`) rather than legacy `cmd.exe` or Windows PowerShell 5.1.
* **Authentication**: Password authentication initially; upgraded to secure **ED25519 public key authentication**.
* **Authorized Keys File**: Located at `C:\ProgramData\ssh\administrators_authorized_keys` for administrative users, configured with strict Windows Access Control Lists (ACLs).

---

## 🛠️ Configuring Client Access (`~/.ssh/config`)

Add the following configuration block to your local machine's `~/.ssh/config` file (works on Linux, macOS, or Windows):

### Direct / Local Host Connection
When running WCOS locally on your Linux workstation:
```sshconfig
Host winvm
    HostName 127.0.0.1
    User samuelcaldas
    Port 2222
    IdentityFile ~/.ssh/id_ed25519
    StrictHostKeyChecking accept-new
    ForwardAgent yes
    RequestTTY yes
```

### Remote / Jumper Host Access (ProxyJump)
When WCOS is running on a remote headless Ubuntu server (e.g. `10.250.50.165` or cloud VM):
```sshconfig
Host winvm-remote
    HostName 127.0.0.1
    User samuelcaldas
    Port 2222
    ProxyJump devops@10.250.50.165
    IdentityFile ~/.ssh/id_ed25519
    LocalForward 3000 127.0.0.1:3000
    LocalForward 9090 127.0.0.1:9090
    LocalForward 13389 127.0.0.1:3389
```

With this configured, you can connect with a single command:
```bash
ssh winvm
```

---

## 🔐 Windows ACLs on `administrators_authorized_keys`

OpenSSH on Windows strictly validates NTFS permissions on `administrators_authorized_keys`. If any non-administrative user has read access, OpenSSH rejects key authentication and falls back to passwords.

WCOS automates the exact ACL lockdown during provisioning:

```powershell
$authKeyPath = "C:\ProgramData\ssh\administrators_authorized_keys"

# Disable inheritance and remove inherited rules
$acl = Get-Acl $authKeyPath
$acl.SetAccessRuleProtection($true, $false)

# Grant Full Control strictly to SYSTEM and Builtin\Administrators
$acl.PurgeAccessRules([System.Security.Principal.NTAccount]"BUILTIN\Users")
$ruleSystem = New-Object System.Security.AccessControl.FileSystemAccessRule("NT AUTHORITY\SYSTEM", "FullControl", "Allow")
$ruleAdmins = New-Object System.Security.AccessControl.FileSystemAccessRule("BUILTIN\Administrators", "FullControl", "Allow")
$acl.AddAccessRule($ruleSystem)
$acl.AddAccessRule($ruleAdmins)

Set-Acl -Path $authKeyPath -AclObject $acl
```

---

## 📡 PowerShell Remoting (WinRM / WSMan)

For automation tools like Ansible or native PowerShell remote sessions, WCOS configures WinRM over both HTTP (`5985`) and HTTPS (`5986`):

### Starting an Interactive PSSession from Linux Host
```powershell
# From Linux pwsh
$cred = Get-Credential -UserName "samuelcaldas"
Enter-PSSession -ComputerName 127.0.0.1 -Port 5985 -Credential $cred
```

### Executing Ad-hoc Remote Commands
```powershell
Invoke-Command -ComputerName 127.0.0.1 -Port 5985 -Credential $cred -ScriptBlock {
    Get-Service | Where-Object Status -eq 'Running'
}
```

---

## 🚀 Port Forwarding & Agent Tunnels

You can map services running inside WCOS to your local browser using SSH local port forwarding:

* **Antigravity Daemon API**: `ssh -L 9090:127.0.0.1:9090 winvm`
* **Web Applications**: `ssh -L 3000:127.0.0.1:3000 winvm`
* **RDP Graphics Debugging**: `ssh -L 13389:127.0.0.1:3389 winvm` (then connect your RDP client to `localhost:13389`).
