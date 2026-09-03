# Brand Identity & Visual Assets

This document summarizes the brand guidelines, visual identity standards, color palettes, and vector assets of **Windows CoreOS (WCOS)**. For the exhaustive manual, refer to [`docs/branding/MANUAL.md`](https://github.com/samuelcaldas/windows-coreos/blob/master/docs/branding/MANUAL.md).

---

## 🎨 Official Brand Palette

The WCOS color scheme combines dark server aesthetics with modern neon cyan accents:

| Color Role | Color Name | Hex Code | RGB | Visual Swatch | Usage |
| :--- | :--- | :--- | :--- | :---: | :--- |
| **Primary Surface** | Midnight Navy | `#0B132B` | `rgb(11, 19, 43)` | ⬛ | Terminal background, dark UI canvas |
| **Secondary Surface**| Slate Void | `#1E293B` | `rgb(30, 41, 59)` | ⬛ | Cards, borders, elevated components |
| **Brand Accent** | Cyber Cyan | `#00F5D4` | `rgb(0, 245, 212)` | 🟦 | Prompts, icons, badges, cursor |
| **Ecosystem Primary**| Windows Core Blue | `#0078D4` | `rgb(0, 120, 212)`| 🟦 | Primary buttons, official branding |
| **Vibrant Accent** | Deep Azure | `#00D2FF` | `rgb(0, 210, 255)`| 🟦 | Gradients, active focus states |
| **Success Status** | Emerald Status | `#10B981` | `rgb(16, 185, 129)`| 🟩 | Node online, passing checks |

---

## 📁 Vector Assets Catalog (`docs/branding/assets/`)

| Asset | Preview / Link | Description | Primary Use Case |
| :--- | :--- | :--- | :--- |
| **Horizontal Logo** | [`wcos-logo-horizontal.svg`](https://raw.githubusercontent.com/samuelcaldas/windows-coreos/master/docs/branding/assets/wcos-logo-horizontal.svg) | Master horizontal logo with icon, logotype, badge, and tagline | Documentation headers, README banners |
| **Square Logo** | [`wcos-logo-square.svg`](https://raw.githubusercontent.com/samuelcaldas/windows-coreos/master/docs/branding/assets/wcos-logo-square.svg) | 1:1 square icon | Profile avatars, app icons |
| **Hex Core Icon** | [`wcos-icon.svg`](https://raw.githubusercontent.com/samuelcaldas/windows-coreos/master/docs/branding/assets/wcos-icon.svg) | Isometric server cube inside hexagon with neon `W` prompt | Favicons, bullet points, system trays |
| **Distro Badge** | [`wcos-badge.svg`](https://raw.githubusercontent.com/samuelcaldas/windows-coreos/master/docs/branding/assets/wcos-badge.svg) | Dual-tone status shield badge | README header shields |

---

## 🖥️ Terminal Banner & MOTD (`motd.txt`)

Windows CoreOS renders an ASCII/ANSI brand banner upon user login via OpenSSH and PowerShell 7:

```
  ____   ____ ___  ____ _____ 
 / __ \ / __ `__ \/ __ `/ __ \
/ /_/ // / / / / / /_/ / / / /
\____//_/ /_/ /_/\__,_/_/ /_/ 

   __      ___           _                     _____               ____   _____ 
   \ \    / (_)         | |                   / ____|             / __ \ / ____|
    \ \  / / _ _ __   __| | _____      _____ | |     ___  _ __ ___| |  | | (___  
     \ \/ / | | '_ \ / _` |/ _ \ \ /\ / / __|| |    / _ \| '__/ _ \ |  | |\___ \ 
      \  /  | | | | | (_| | (_) \ V  V /\__ \| |___| (_) | | |  __/ |__| |____) |
       \/   |_|_| |_|\__,_|\___/  \_/\_/ |___/ \_____\___/|_|  \___|\____/|_____/ 
                                                                                
  • Distro : Windows CoreOS (WCOS) [Build 17763.737]
  • Kernel : Windows Server Core RS5 x64 (Headless)
  • Host   : Linux KVM / QEMU Virtual Machine
  • Shell  : PowerShell 7.6.5 Core (Default)
  • Docs   : https://github.com/samuelcaldas/windows-coreos
```

This banner is stored in `C:\ProgramData\ssh\banner.txt` and invoked by PowerShell 7's global profile (`profile.ps1`).

---

## ✍️ Brand Naming Conventions

* **Full Formal Name**: **Windows CoreOS**
* **Short Name / Acronym**: **WCOS**
* **Tagline**: *Free Windows Server Core Distribution*
* **Prohibited Naming**: Never refer to the project simply as "CoreOS" without context, to avoid confusion with the Linux container distribution (Red Hat CoreOS).
