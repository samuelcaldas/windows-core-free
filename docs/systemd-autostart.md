# Systemd Autostart & Host Service Management Guide

This guide documents the host-level **systemd service** configuration for the Windows CoreOS (WCOS) VM (`windows-core`), enabling zero-touch automatic startup on Ubuntu host boot, background process supervision, and clean ACPI shutdown orchestration.

---

## 1. Overview & Architecture

When running Windows CoreOS (WCOS) as a virtualized development guest on an Ubuntu host, managing the VM via systemd ensures:
- **Automatic Boot on Host Startup**: The VM automatically initializes when Ubuntu starts, without requiring an interactive login.
- **Process Supervision & Restart on Failure**: Systemd monitors the QEMU process (`windows-core`) and restarts it automatically if unexpected crashes occur.
- **Graceful ACPI Shutdown on Host Shutdown/Reboot**: When the Ubuntu host powers off or reboots, systemd triggers an ACPI power button event to the guest, allowing Windows CoreOS to flush disk caches and shut down cleanly.
- **Non-Root Execution**: Runs under the user account (`samuelcaldas`) with access to `/dev/kvm` through the `kvm` supplementary group.

```
+-------------------------------------------------------------------+
|                        Ubuntu Linux Host                          |
|                                                                   |
|   systemd (PID 1)                                                 |
|       │                                                           |
|       ▼                                                           |
|   windows-core.service                                            |
|       │                                                           |
|       ├── ExecStart: run-vm.sh --foreground                       |
|       │     └─► qemu-system-x86_64 (KVM + VirtIO + UEFI)         |
|       │             │                                             |
|       │             └─► Windows CoreOS (WCOS) Guest (port forwards)|
|       │                   - SSH: 2222 -> 22                       |
|       │                   - WinRM: 5985/5986 -> 5985/5986         |
|       │                   - Daemon: 9090 -> 9090                  |
|       │                                                           |
|       └── ExecStop: run-vm.sh --stop                              |
|             └─► ACPI system_powerdown via QEMU monitor socket     |
+-------------------------------------------------------------------+
```

---

## 2. Service Unit Specification (`windows-core.service`)

The unit file is installed at `/etc/systemd/system/windows-core.service` (templated from `config/systemd/windows-core.service`):

```ini
[Unit]
Description=Windows Server Core Headless Development VM (QEMU/KVM)
Documentation=https://github.com/samuelcaldas/windows-core
After=network.target network-online.target
Wants=network-online.target

[Service]
Type=simple
User=samuelcaldas
Group=samuelcaldas
SupplementaryGroups=kvm
WorkingDirectory=/home/samuelcaldas/repos/windows-core
ExecStart=/home/samuelcaldas/repos/windows-core/scripts/host/run-vm.sh --foreground
ExecStop=/home/samuelcaldas/repos/windows-core/scripts/host/run-vm.sh --stop
Restart=on-failure
RestartSec=10s
TimeoutStopSec=60s
KillMode=control-group
PIDFile=/home/samuelcaldas/repos/windows-core/.windows-core-qemu.pid

[Install]
WantedBy=multi-user.target
```

### Key Parameters:
- **`Type=simple`**: QEMU runs directly in foreground mode (`exec "${QEMU_ARGS[@]}"`), allowing systemd to track the exact process lifecycle.
- **`ExecStop`**: Executes `run-vm.sh --stop`, which sends `system_powerdown` to the QEMU UNIX monitor socket (`.windows-core-monitor.sock`) to trigger a clean Windows guest shutdown.
- **`TimeoutStopSec=60s`**: Allows Windows Core up to 60 seconds to finish flushing filesystem journals and terminating background services before forcing termination.

---

## 3. Management Script (`scripts/host/setup-service.sh`)

The repository includes dual orchestrator scripts in **Bash** (`setup-service.sh`) and **PowerShell 7** (`setup-service.ps1`) to manage the service lifecycle without manual systemd commands.

### Installation & Autostart Activation
```bash
# Install unit, reload systemd daemon, enable on boot, and start the VM
./scripts/host/setup-service.sh --install

# Or install and enable on boot without starting immediately
./scripts/host/setup-service.sh --install-only
```

*PowerShell 7 equivalent:*
```powershell
./scripts/host/setup-service.ps1 -Install
```

### Checking Status & Boot Enablement
```bash
./scripts/host/setup-service.sh --status
```
Example output:
```text
[SUCCESS] windows-core.service is ACTIVE and RUNNING.
  - Autostart on boot: ENABLED

● windows-core.service - Windows Server Core Headless Development VM (QEMU/KVM)
     Loaded: loaded (/etc/systemd/system/windows-core.service; enabled; preset: enabled)
     Active: active (running)
```

### Live Logs & Monitoring
```bash
# Follow live systemd journal logs
./scripts/host/setup-service.sh --logs
```

### Service Controls
```bash
# Gracefully stop the VM (ACPI powerdown)
./scripts/host/setup-service.sh --stop

# Start the VM
./scripts/host/setup-service.sh --start

# Restart the VM
./scripts/host/setup-service.sh --restart

# Enable / Disable autostart on host boot
./scripts/host/setup-service.sh --enable
./scripts/host/setup-service.sh --disable

# Completely uninstall and remove the systemd service
./scripts/host/setup-service.sh --uninstall
```

---

## 4. Troubleshooting & Diagnostics

### Inspecting Systemd Journal Logs
```bash
journalctl -u windows-core.service -n 100 --no-pager
```

### Verifying QEMU Monitor Socket
During runtime, the monitor UNIX socket is located at:
```bash
ls -l /home/samuelcaldas/repos/windows-core/.windows-core-monitor.sock
```

### Testing ACPI Powerdown Manually
```bash
python3 -c "import socket; s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM); s.connect('/home/samuelcaldas/repos/windows-core/.windows-core-monitor.sock'); s.sendall(b'system_powerdown\n'); s.close()"
```
