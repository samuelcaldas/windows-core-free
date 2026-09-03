---
layout: home

hero:
  name: Windows CoreOS
  text: Free Windows Server Core Distribution
  tagline: Ultra-lightweight headless Windows Server Core RS5 for Linux KVM, Proxmox, and Autonomous AI Agents. Drops idle RAM to ~530 MB.
  image:
    src: /hero.svg
    alt: Windows CoreOS Logo
  actions:
    - theme: brand
      text: Get Started →
      link: /guides/Getting-Started
    - theme: alt
      text: Architecture
      link: /guides/Architecture-and-Hardware
    - theme: alt
      text: GitHub Releases
      link: https://github.com/samuelcaldas/windows-coreos/releases

features:
  - icon: 📉
    title: ~530 MB Idle RAM
    details: Reclaims over 75% of RAM compared to stock Windows Server by eliminating nested Hyper-V, Defender, SysMain, and telemetry bloatware.
  - icon: 🔑
    title: OpenSSH & PowerShell 7
    details: Native headless management over SSH with ED25519 keys, PowerShell 7 default shell, ProxyJump tunnels, and WinRM remoting.
  - icon: 🤖
    title: Autonomous AI Agent Node
    details: Pre-configured execution environment for Google Antigravity Daemon (port 9090), Claude Code CLI, and OpenAI Codex CLI.
  - icon: 📦
    title: OmniGet Package Engine
    details: Universal multi-source package manager with Ninite bundles, zero-downtime hot-swap binary updates, and curated stacks.
  - icon: 🏎️
    title: Linux KVM & VirtIO Native
    details: Paravirtualized VirtIO SCSI with TRIM discard, VirtIO Net, UEFI OVMF firmware, and instant QCOW2 snapshots.
  - icon: 🖥️
    title: Modular Desktop Environment
    details: Optional WinXShell desktop, Microsoft WinFile, and WezTerm GPU terminal consuming less than 30MB additional RAM.
---

<div class="vp-doc" style="margin-top: 3rem;">

## 📊 Live RAM Footprint Benchmark

<div class="dashboard-widget">
<div class="benchmark-grid">
<div class="stat-card">
<div class="stat-header">
<span class="stat-title">Stock Windows Server 2019 Core</span>
<span class="badge-stock">Stock OS</span>
</div>
<div class="stat-value">
~2,100 <span class="stat-unit">MB RAM</span>
</div>
<div class="progress-track">
<div class="progress-fill stock" style="width: 100%;"></div>
</div>
</div>
<div class="stat-card highlight">
<div class="stat-header">
<span class="stat-title">Windows CoreOS (WCOS)</span>
<span class="badge-optimized">75% Reduction</span>
</div>
<div class="stat-value text-neon">
~530 <span class="stat-unit">MB RAM</span>
</div>
<div class="progress-track">
<div class="progress-fill optimized" style="width: 25.2%;"></div>
</div>
</div>
</div>

<div class="table-wrapper">
<table>
<thead>
<tr>
<th>Component / Service</th>
<th>Stock Windows Server 2019</th>
<th>Windows CoreOS (WCOS)</th>
<th>Reclaimed Memory</th>
</tr>
</thead>
<tbody>
<tr>
<td><strong>Windows Defender</strong> (<code>MsMpEng.exe</code>)</td>
<td>Active (Real-time disk scanner)</td>
<td>Removed via DISM</td>
<td><code>~250 MB</code></td>
</tr>
<tr>
<td><strong>Nested Hyper-V Roles</strong> (<code>vmms.exe</code>)</td>
<td>Enabled by default</td>
<td>Decommissioned</td>
<td><code>~220 MB</code></td>
</tr>
<tr>
<td><strong>Superfetch / SysMain</strong></td>
<td>Active background caching</td>
<td>Disabled</td>
<td><code>~100 MB</code></td>
</tr>
<tr>
<td><strong>Telemetry & Error Reporting</strong></td>
<td>Active background collection</td>
<td>Disabled & Blocked</td>
<td><code>~80 MB</code></td>
</tr>
<tr>
<td><strong>Svchost Splitting</strong></td>
<td>~60 split processes</td>
<td>Consolidated</td>
<td><code>~250 MB</code></td>
</tr>
</tbody>
</table>
</div>
</div>

---

## ⚡ Quick Start: 3 Commands to Boot

From any headless Ubuntu/Debian host:

```bash
# 1. Clone with submodules & prepare host environment
git clone --recurse-submodules https://github.com/samuelcaldas/windows-coreos.git
cd windows-coreos && ./scripts/host/setup-host.sh --download-iso

# 2. Build unattended boot media & assemble VirtIO drivers
./scripts/host/build-iso.sh

# 3. Boot virtual machine in KVM
./scripts/host/run-vm.sh
```

Connect via SSH once installed:
```bash
ssh -p 2222 username@127.0.0.1
```

---

## 🌐 Network Topology & Port Map

<div class="table-wrapper">
  <table>
    <thead>
      <tr>
        <th>Service</th>
        <th>Guest Port</th>
        <th>Forwarded Host Port</th>
        <th>Purpose</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td><strong>OpenSSH Server</strong></td>
        <td><code>22</code></td>
        <td><code>2222</code></td>
        <td>Direct CLI access & autonomous agent orchestration</td>
      </tr>
      <tr>
        <td><strong>WinRM (HTTP/HTTPS)</strong></td>
        <td><code>5985</code> / <code>5986</code></td>
        <td><code>5985</code> / <code>5986</code></td>
        <td>PowerShell Remoting (<code>Enter-PSSession</code>, Ansible)</td>
      </tr>
      <tr>
        <td><strong>Antigravity Daemon</strong></td>
        <td><code>9090</code></td>
        <td><code>9090</code></td>
        <td>Headless Remote Control (<code>agy-daemon</code>)</td>
      </tr>
      <tr>
        <td><strong>RDP Console (Optional)</strong></td>
        <td><code>3389</code></td>
        <td><code>3389</code></td>
        <td>Fallback graphical debugging & recovery</td>
      </tr>
    </tbody>
  </table>
</div>

---

## ⚖️ Legal Disclaimer & Official ISO Notice

::: tip LEGAL NOTICE & UPSTREAM ISO REQUIREMENT
**Windows CoreOS is an open-source automation layer distributed under the MIT License.**
This repository DOES NOT redistribute, host, or mirror proprietary Microsoft Windows binaries, ISO installation media, or product keys. Users must obtain their own legitimate copy of Microsoft Hyper-V Server 2019 from official Microsoft channels.

*Microsoft, Windows, Windows Server, Hyper-V, and PowerShell are registered trademarks of Microsoft Corporation.*
:::

</div>
