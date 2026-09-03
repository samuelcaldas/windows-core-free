# Unattended Installation Architecture

This document details the zero-touch automated provisioning architecture of **Windows CoreOS (WCOS)** using Microsoft Answer Files (`autounattend.xml`) and dual-drive ISO injection.

---

## 🚀 Dual-Drive Unattended Strategy

Standard Windows Setup requires interactive prompts to accept licenses, select partition schemes, format disks, and install drivers. WCOS eliminates all interactive prompts through **dual-drive virtualization**:

```
+-------------------------------------------------------------+
| QEMU Virtual Machine                                        |
|                                                             |
|   Drive 1: windows-core-installer.iso (Read-Only DVD)       |
|     - Official unmodified Microsoft OEM ISO                 |
|     - Contains install.wim (Server Core build 17763)        |
|                                                             |
|   Drive 2: oemdrv.iso (Virtual OEM Drive)                   |
|     - autounattend.xml                                      |
|     - VirtIO storage & network drivers                      |
|     - PowerShell 7 runtime MSI                              |
|     - C:\Provisioning scripts & configuration cache         |
|                                                             |
|   Drive 3: windows-core.qcow2 (VirtIO SCSI Disk)            |
|     - Target GPT/UEFI installation target                   |
+-------------------------------------------------------------+
```

When Windows Setup boots from Drive 1, it automatically scans all connected drives for a file named `autounattend.xml`. Finding it on Drive 2 (`OEMDRV`), Setup switches into automated unattended mode without any user intervention.

---

## 📑 Unattended Configuration Stages (`autounattend.xml`)

Windows Setup executes answer file directives across defined configuration passes:

### 1. `windowsPE` Pass (Preinstallation Environment)
* **Hardware Bypasses**: Injects registry flags into the WinPE setup environment to bypass TPM 2.0, SecureBoot, RAM, and CPU compatibility checks:
  ```xml
  <RunSynchronousCommand wcm:action="add">
    <Order>1</Order>
    <Path>reg add HKLM\SYSTEM\Setup\LabConfig /v BypassTPMCheck /t REG_DWORD /d 1 /f</Path>
  </RunSynchronousCommand>
  <RunSynchronousCommand wcm:action="add">
    <Order>2</Order>
    <Path>reg add HKLM\SYSTEM\Setup\LabConfig /v BypassSecureBootCheck /t REG_DWORD /d 1 /f</Path>
  </RunSynchronousCommand>
  <RunSynchronousCommand wcm:action="add">
    <Order>3</Order>
    <Path>reg add HKLM\SYSTEM\Setup\LabConfig /v BypassRAMCheck /t REG_DWORD /d 1 /f</Path>
  </RunSynchronousCommand>
  ```
* **VirtIO Driver Injection**: Directs Setup to scan `D:\virtio\amd64\2k19` (or `E:\`) for VirtIO SCSI and Network drivers before initializing the storage controller.
* **Disk Partitioning**: Automatically initializes the target disk with a standard UEFI/GPT layout:
  - Partition 1: EFI System Partition (100 MB, FAT32)
  - Partition 2: Microsoft Reserved Partition (16 MB, MSR)
  - Partition 3: Windows OS Partition (Remaining space, NTFS, labeled `WindowsCore`)
* **Image Selection**: Automatically selects the Windows Server Core OEM edition (`SERVERHYPERCORE`) from `install.wim`.

---

### 2. `specialize` Pass (Hardware & Network Specialization)
* **Computer Name**: Sets NetBIOS hostname to `windows-core`.
* **Timezone & Locale**:
  - Timezone: `E. South America Standard Time` (`America/Sao_Paulo`, UTC-3).
  - UI Language: `en-US`.
  - System Locale & Number Formatting: `pt-BR`.
  - Input Keyboard Layout: `0416:00000416` (Brazilian ABNT2).
* **Network Location**: Configures network profile as `Private` to enable remote management services without aggressive public firewall drop policies.
* **Stage 1 Provisioning**: Executes `C:\Provisioning\scripts\Specialize.ps1`.

---

### 3. `oobeSystem` Pass (Out-Of-Box Experience & Accounts)
* **User Accounts**:
  - `samuelcaldas`: Primary developer account added to local `Administrators` group with a non-expiring password.
  - Built-in `Administrator`: AutoLogon enabled for 1 session to complete headless FirstLogon execution.
* **Privacy & Telemetry Restrictions**: Disables consumer telemetry, Customer Experience Improvement Program (CEIP), error reporting, and Bing search integration.

---

## 🛠️ Automated Bootstrap Script (`Specialize.ps1`)

During the `specialize` pass, `Specialize.ps1` executes under local SYSTEM privileges to configure critical core subsystems:

1. **PowerShell 7 (`pwsh`) Installation**:
   - Installs modern PowerShell 7 silently from the offline OEM drive (`PowerShell-7.x-win-x64.msi`).
   - Sets PowerShell execution policy to `Unrestricted`.
2. **Win32-OpenSSH Server Deployment**:
   - Registers `sshd` and `ssh-agent` as automatic Windows services.
   - Configures PowerShell 7 as the default shell for all SSH sessions:
     ```powershell
     New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name "DefaultShell" `
         -Value "C:\Program Files\PowerShell\7\pwsh.exe" -PropertyType String -Force
     ```
3. **Hyper-V Role Deactivation**:
   - Because WCOS is a virtual guest on Linux KVM, nested Hyper-V roles and services are decommissioned to prevent CPU/RAM overhead:
     ```powershell
     & bcdedit.exe /set hypervisorlaunchtype off
     ```
4. **Firewall Rules**:
   - Opens incoming firewall ports for OpenSSH (`22`), WinRM (`5985`/`5986`), and Antigravity Daemon (`9090`).
5. **Branding Deployment (`Deploy-WcosBranding`)**:
   - Copies `motd.txt` to `C:\ProgramData\ssh\banner.txt`.
   - Configures PowerShell 7 profile (`profile.ps1`) to display the MOTD ASCII banner on terminal start.
