# System Optimization & Memory Pruning

This document details the techniques and scripts used by **Windows CoreOS (WCOS)** to reduce idle RAM consumption from **~2.1 GB** on stock Windows Server 2019 down to **~530 MB** without breaking developer toolchains or stability.

---

## 📊 RAM Comparison Benchmark

```
Stock Windows Server 2019 Core (Fresh Boot)
[████████████████████████████████████████] ~2,100 MB RAM

Windows CoreOS (WCOS) after Optimization
[██████████] ~530 MB RAM (75% RAM Reduction!)
```

| Component / Subsystem | Stock Windows Server 2019 | Windows CoreOS (WCOS) | Reclaimed RAM |
| :--- | :--- | :--- | :--- |
| **Windows Defender Antivirus** (`MsMpEng.exe`) | Active & scanning | Removed / Decommissioned | ~220 MB - 350 MB |
| **Nested Hyper-V Virtualization** (`vmms.exe`) | Active | Decommissioned (`hypervisorlaunchtype=off`) | ~180 MB - 250 MB |
| **SysMain / Superfetch** | Active | Disabled | ~80 MB - 150 MB |
| **Telemetry & CEIP** (`DiagTrack`) | Active | Disabled & Blocked | ~40 MB - 70 MB |
| **Windows Error Reporting** (`WerSvc`) | Active | Disabled | ~30 MB - 50 MB |
| **Svchost Process Splitting** | 1 process per service (~60 processes) | Consolidated via registry | ~200 MB - 300 MB |
| **Unneeded Server Roles** | Active | Pruned via DISM | ~150 MB - 250 MB |

---

## 🛠️ Optimization Components (`Optimize-System.ps1`)

The guest optimization orchestrator executes several targeted phases:

### 1. Complete Removal of Windows Defender (`MsMpEng`)
On a virtualized dev box running inside a trusted Linux host, real-time antivirus disk scanning causes severe I/O lag and consumes ~250MB RAM. WCOS removes it via DISM:
```powershell
Uninstall-WindowsFeature -Name Windows-Defender, Windows-Defender-Features -Restart:$false
```
Additionally, registry policies disable all residual Defender services:
```powershell
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" -Name "DisableAntiSpyware" -Value 1 -Force
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -Name "DisableRealtimeMonitoring" -Value 1 -Force
```

---

### 2. Nested Hyper-V Decommissioning (`Disable-HyperV.ps1`)
Because WCOS runs inside Linux KVM, running Hyper-V inside the guest creates nested hypervisor conflicts and wastes CPU cycles.
```powershell
# Deactivate boot hypervisor launch
& bcdedit.exe /set hypervisorlaunchtype off

# Remove Hyper-V feature
Disable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -NoRestart
```
All background Hyper-V management services (`vmms`, `vmicvss`, `vmicguestinterface`, `vmicheartbeat`) are stopped and disabled.

---

### 3. Service Host Consolidation (`SvcHostSplitThresholdInKB`)
Windows 10 / Server 2016+ splits every system service into its own `svchost.exe` process if the machine has more than 3.5 GB of RAM. This improves crash isolation on multi-user desktops, but consumes hundreds of megabytes of process overhead.

WCOS consolidates related services back into shared `svchost` containers:
```powershell
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control" `
    -Name "SvcHostSplitThresholdInKB" -Value 0x7FFFFFFF -Type DWord -Force
```

---

### 4. Telemetry, Tracking & Diagnostic Lockdown
WCOS stops and disables diagnostic tracking services:
* `DiagTrack` (Connected User Experiences and Telemetry)
* `dmwappushservice` (WAP Push Message Routing Service)
* `WerSvc` (Windows Error Reporting Service)
* `WbioSrvc` (Windows Biometric Service)
* `MapsBroker` (Downloaded Maps Manager)

---

### 5. Dan Pollock Zero-Route (`0.0.0.0`) Hosts Blocklist (`Update-HostsBlocklist.ps1`)
WCOS deploys Dan Pollock's trusted zero-route hosts blocklist directly to `C:\Windows\System32\drivers\etc\hosts`:
* Blocks over **13,000+ known ad, telemetry, tracking, and malware domains**.
* Maps domains to `0.0.0.0` (zero-route drop) instead of `127.0.0.1`, eliminating connection timeout delays and CPU overhead.
* Updates can be triggered anytime from the Linux host:
  ```bash
  ./scripts/host/update-hosts.sh
  ```

---

## 🔍 Live Verification & Profiling

To inspect memory utilization live from your Linux host:

```bash
ssh winvm "powershell -Command \"
    \$os = Get-CimInstance Win32_OperatingSystem
    \$total = [math]::Round(\$os.TotalVisibleMemorySize / 1024, 1)
    \$free  = [math]::Round(\$os.FreePhysicalMemory / 1024, 1)
    \$used  = [math]::Round((\$os.TotalVisibleMemorySize - \$os.FreePhysicalMemory) / 1024, 1)
    Write-Host \\\"RAM Usage: Used: \$used MB / Total: \$total MB (Free: \$free MB)\\\" -ForegroundColor Green
\""
```

To view the top RAM consuming processes:
```bash
ssh winvm "powershell -Command \"Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 10 Name, Id, @{Name='RAM (MB)'; Expression={[math]::Round(\$_.WorkingSet64 / 1MB, 2)}} | Format-Table -AutoSize\""
```
