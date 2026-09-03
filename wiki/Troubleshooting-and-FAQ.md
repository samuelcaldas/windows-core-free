# Troubleshooting & Frequently Asked Questions (FAQ)

This document provides solutions to common questions, operational challenges, and error states when deploying and running **Windows CoreOS (WCOS)**.

---

## ❓ Frequently Asked Questions (FAQ)

### 1. Is Windows CoreOS legal and compliant with Microsoft licensing?
Yes. Windows CoreOS is distributed under the MIT License and strictly contains open-source automation scripts, answer files, and tooling. It **DOES NOT** distribute, host, or mirror proprietary Microsoft Windows ISO media, binary installers, or product keys. Users obtain their own official ISO media directly from Microsoft channels.

### 2. Can I run graphical desktop applications on WCOS?
Yes! While WCOS is headless by default, you can deploy the ultra-lightweight desktop environment at any time:
```bash
./scripts/host/install-desktopshell.sh WinXShell WinFile
```
This enables WinXShell, Microsoft WinFile, and WezTerm GPU terminal, consuming less than 30 MB of additional RAM. You can view the GUI via RDP on port `3389`.

### 3. How does WCOS achieve ~530 MB idle RAM?
By eliminating unneeded server roles, decommissioning nested Hyper-V roles (`Disable-HyperV.ps1`), removing Windows Defender (`MsMpEng`), disabling Superfetch (`SysMain`), stopping telemetry, and consolidating `svchost` containers.

---

## 🔧 Troubleshooting Guide

### Issue 1: KVM Permission Denied (`/dev/kvm: Permission denied`)
**Symptom**: `run-vm.sh` fails with:
```
Could not access KVM kernel module: Permission denied
failed to initialize KVM: Permission denied
```
**Resolution**: Ensure your Linux user belongs to the `kvm` and `libvirt` groups:
```bash
sudo usermod -aG kvm,libvirt $USER
newgrp kvm
# Verify permissions
ls -la /dev/kvm
# Expected: crw-rw----+ 1 root kvm ...
```

---

### Issue 2: OpenSSH Key Authentication Rejected (Prompting for Password)
**Symptom**: `ssh winvm` prompts for a password even after copying public keys.

**Cause**: Windows OpenSSH enforces strict NTFS ACLs on `C:\ProgramData\ssh\administrators_authorized_keys`. If standard users have read permissions, OpenSSH ignores the file.

**Resolution**: Re-run the ACL hardening command on the guest:
```powershell
ssh -p 2222 samuelcaldas@127.0.0.1 "powershell -Command \"
    \$path = 'C:\ProgramData\ssh\administrators_authorized_keys'
    \$acl = Get-Acl \$path
    \$acl.SetAccessRuleProtection(\$true, \$false)
    \$acl.PurgeAccessRules([System.Security.Principal.NTAccount]'BUILTIN\Users')
    \$acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule('NT AUTHORITY\SYSTEM','FullControl','Allow')))
    \$acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule('BUILTIN\Administrators','FullControl','Allow')))
    Set-Acl -Path \$path -AclObject \$acl
\""
```

---

### Issue 3: Windows Setup Fails to Detect Hard Drive during Install
**Symptom**: Windows Setup reports: `We couldn't find any drives. To get a storage driver, click Load driver.`

**Cause**: The secondary virtual drive (`oemdrv.iso`) is missing or does not contain the VirtIO SCSI drivers for Windows Server 2019.

**Resolution**:
1. Verify `iso/virtio-win.iso` was downloaded.
2. Re-run `./scripts/host/build-iso.sh` to re-extract the VirtIO storage drivers into `oemdrv.iso`.
3. Check that QEMU mounts the drive with `-drive file=...oemdrv.iso,media=cdrom`.

---

### Issue 4: Extending Windows Server Evaluation Period
**Symptom**: Windows displays desktop notifications that the 180-day evaluation period is expiring.

**Resolution**: Microsoft allows extending the evaluation period up to 6 times (1,080 days total) using the official `slmgr` rearm command:
```powershell
# Inside Windows CoreOS
slmgr.vbs /rearm
Restart-Computer -Force
```

---

### Issue 5: Reclaiming Host Disk Space from QCOW2 (TRIM / Hole Punching)
**Symptom**: The host QCOW2 file grows over time as packages are installed and removed.

**Resolution**: WCOS uses VirtIO SCSI with `discard=unmap`. Run the Windows defragmentation and TRIM utility inside the guest to punch holes in unused blocks:
```powershell
Optimize-Volume -DriveLetter C -Defrag -Verbose
```
To shrink the QCOW2 image offline:
```bash
./scripts/host/run-vm.sh --stop
qemu-img convert -O qcow2 -c windows-core.qcow2 windows-core-compressed.qcow2
mv windows-core-compressed.qcow2 windows-core.qcow2
```
