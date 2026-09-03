# Proxmox VE & Docker Portability Guide

Because **Windows CoreOS (WCOS)** is built on standard VirtIO and UEFI architecture with sparse QCOW2 virtual disks, it can be seamlessly migrated to **Proxmox VE clusters** or run within **Docker container wrappers**.

---

## 🌐 Migrating WCOS to Proxmox VE

Proxmox VE natively uses QEMU/KVM and VirtIO, making WCOS 100% compatible without requiring any driver modifications or sysprep re-imaging.

### Step 1: Create Virtual Machine in Proxmox
Create an empty VM in Proxmox (e.g. VM ID `200`) with matching hardware specifications:

```bash
qm create 200 \
    --name "wcos-node01" \
    --machine q35 \
    --bios ovmf \
    --efidisk0 local-lvm:1,efitype=4m,pre-enrolled-keys=1 \
    --cores 4 \
    --memory 4096 \
    --balloon 2048 \
    --cpu host \
    --scsihw virtio-scsi-single \
    --net0 virtio,bridge=vmbr0,firewall=1 \
    --ostype win10
```

### Step 2: Transfer & Import QCOW2 Virtual Disk
Transfer your built `windows-core.qcow2` virtual disk to the Proxmox host via `scp`:

```bash
scp windows-core.qcow2 root@proxmox.local:/var/lib/vz/template/qemu/wcos.qcow2
```

Import the disk into your Proxmox storage pool (e.g. `local-lvm` or `zfs-pool`):
```bash
qm importdisk 200 /var/lib/vz/template/qemu/wcos.qcow2 local-lvm --format raw
```

### Step 3: Attach Disk and Configure Boot Order
```bash
# Attach the imported volume as scsi0 with discard enabled
qm set 200 --scsi0 local-lvm:vm-200-disk-1,discard=on,ssd=1

# Set boot order to prioritize SCSI disk
qm set 200 --boot order=scsi0

# Start the virtual machine
qm start 200
```

Windows CoreOS boots directly into PowerShell 7 and acquires an IP address from your network's DHCP server!

---

## 🐳 Running WCOS via Docker Container Wrapper

For environments utilizing container orchestrators or Docker Compose, WCOS can run inside a lightweight container wrapper with direct KVM device pass-through (`/dev/kvm`):

### Docker Compose Configuration (`docker-compose.yml`)

```yaml
version: '3.8'

services:
  windows-core:
    image: qemu-desktop-wrapper:latest
    container_name: windows-core
    restart: unless-stopped
    devices:
      - /dev/kvm:/dev/kvm
      - /dev/net/tun:/dev/net/tun
    cap_add:
      - NET_ADMIN
    environment:
      - VM_MEMORY=4096M
      - VM_CORES=4
      - TZ=America/Sao_Paulo
    volumes:
      - ./windows-core.qcow2:/vm/windows-core.qcow2
      - ./config/systemd:/vm/config
    ports:
      - "2222:2222"   # OpenSSH
      - "5985:5985"   # WinRM HTTP
      - "5986:5986"   # WinRM HTTPS
      - "9090:9090"   # Antigravity Daemon
    command: >
      bash -c "
        qemu-system-x86_64 \
          -enable-kvm -machine q35,accel=kvm -cpu host \
          -m 4096 -smp 4 \
          -drive file=/vm/windows-core.qcow2,if=virtio,format=qcow2 \
          -netdev user,id=net0,hostfwd=tcp::2222-:22,hostfwd=tcp::9090-:9090 \
          -device virtio-net-pci,netdev=net0 \
          -display none
      "
```
