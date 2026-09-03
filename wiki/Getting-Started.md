# Getting Started with Windows CoreOS (WCOS)

This guide walks you through setting up a headless **Windows CoreOS (WCOS)** virtual machine on an Ubuntu / Debian Linux host using QEMU/KVM, from host preparation to first automated boot and SSH access.

---

## 📋 System Requirements

### Host Requirements (Linux)
* **Operating System**: Ubuntu 22.04 LTS / 24.04 LTS or Debian 12 (headless server or desktop).
* **CPU Virtualization**: Intel VT-x or AMD-V enabled in host BIOS/UEFI.
* **CPU Cores**: Minimum 2 cores allocated to guest (4 recommended).
* **RAM**: Minimum 2 GB allocated to guest (4 GB recommended for heavy builds). Host needs at least 4 GB total.
* **Disk Space**: ~40 GB free space on host SSD/NVMe (QCOW2 disk is dynamic/sparse and occupies only ~12 GB initially).

### Guest Specifications
* **Base OS**: Microsoft Hyper-V Server 2019 OEM x64 (Build 17763.737, English US).
* **Virtualization Model**: QEMU/KVM with VirtIO SCSI, VirtIO Net, VirtIO Balloon, and UEFI OVMF.

---

## ⚡ Step-by-Step Installation

### Step 1: Clone Repository & Submodules
```bash
git clone --recurse-submodules https://github.com/samuelcaldas/windows-coreos.git
cd windows-coreos
```

### Step 2: Host Environment Preparation
Run the automated host setup script to install QEMU, KVM, OVMF UEFI firmware, 7-Zip, `xorriso`, and configure user permissions:

```bash
./scripts/host/setup-host.sh
```

> [!TIP]
> Ensure your Linux user belongs to the `kvm` and `libvirt` groups:
> `sudo usermod -aG kvm,libvirt $USER && newgrp kvm`

---

### Step 3: Download Official Microsoft ISO

Windows CoreOS does NOT bundle proprietary Microsoft Windows binaries. You must obtain the official evaluation ISO from Microsoft.

You can automate the download and SHA256 verification with a single command:

```bash
./scripts/host/setup-host.sh --download-iso
```

*Or via PowerShell 7:*
```powershell
./scripts/host/setup-host.ps1 -DownloadIso
```

#### Manual ISO Reference
If downloading manually, place the file in the `iso/` directory:
* **Filename**: `17763.737.190906-2324.rs5_release_svc_refresh_SERVERHYPERCORE_OEM_x64FRE_en-us_1.iso`
* **Direct Download Link**: [Microsoft CDN Link](https://software-download.microsoft.com/download/pr/17763.737.190906-2324.rs5_release_svc_refresh_SERVERHYPERCORE_OEM_x64FRE_en-us_1.iso)
* **Expected SHA256**: `48e9b944518e5bbc80876a9a7ff99716f386f404f4be48dca47e16a66ae7872c`

---

### Step 4: Build Unattended Provisioning Media (`oemdrv.iso`)

Run the ISO generator script to assemble the dual-drive unattended media containing `autounattend.xml`, VirtIO drivers, and first-boot bootstrap scripts:

```bash
./scripts/host/build-iso.sh
```

This script will:
1. Download the latest stable Fedora VirtIO drivers ISO (`virtio-win.iso`).
2. Extract required storage and network drivers for Windows Server 2019 (2k19/amd64).
3. Download the standalone PowerShell 7 MSI (`PowerShell-7.x-win-x64.msi`).
4. Generate the `iso/oemdrv.iso` drive containing `autounattend.xml`.

---

### Step 5: Boot the Virtual Machine

Start the automated installation by launching the QEMU/KVM virtual machine:

```bash
./scripts/host/run-vm.sh
```

During first boot:
1. Windows Setup starts in zero-touch unattended mode.
2. Setup detects `autounattend.xml` on the secondary virtual drive (`oemdrv.iso`).
3. VirtIO SCSI storage drivers are loaded on-the-fly.
4. The 64 GB sparse virtual disk (`windows-core.qcow2`) is partitioned with GPT/UEFI layout.
5. Windows Server Core is installed, customized, and boots into PowerShell 7.
6. The entire process takes approximately 3 to 7 minutes depending on disk speed.

---

### Step 6: Connect via OpenSSH

Once provisioning completes, OpenSSH Server is active on port `2222`. Connect directly from your Linux host:

```bash
ssh -p 2222 username@127.0.0.1
```
*Default password during first boot: `windows`*

You will be greeted by the custom **Windows CoreOS MOTD banner** and enter a native PowerShell 7 session!

---

### Step 7: Push SSH Keys & Remote Provisioning

Run the remote synchronization script from your Linux host to exchange ED25519 public keys and deploy developer toolchains:

```bash
./scripts/host/provision-remote.sh
```

Now you can log in without entering a password:
```bash
ssh winvm
```

---

## 🎯 Next Steps

* [System Optimization & Memory Pruning](System-Optimization-and-Memory-Pruning): Learn how WCOS drops idle RAM to ~530 MB.
* [Package Management with OmniGet](Package-Management-with-OmniGet): Install developer tools and runtimes.
* [Host Systemd Autostart](Host-Systemd-Autostart): Configure WCOS to start automatically on Linux host boot.
* [Autonomous AI Agent Workstation](Autonomous-AI-Agent-Workstation): Launch Claude Code CLI and Antigravity Daemon.
