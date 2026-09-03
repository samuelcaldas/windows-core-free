# Package Management with OmniGet (og)

**Windows CoreOS (WCOS)** integrates **OmniGet (`og`)** as its official, multi-source package manager. OmniGet is designed specifically for headless Windows environments, zero-touch CI/CD pipelines, and autonomous AI agents.

---

## 🛍️ What is OmniGet?

[OmniGet](https://github.com/samuelcaldas/omniget) is a lightweight, universal package management engine implemented in PowerShell 7 Core. It provides:

* **5 Package Providers**: Ninite dynamic bundling, GitHub Releases, Direct Vendor installers, Distro Recipes, and NPM.
* **Hot-Swap In-Use Binary Replacement**: Updates locked executables and running services without kicking active users or killing SSH sessions.
* **Zero-Reboot Windows Installer Suppression**: Bypasses Windows Restart Manager prompts (`MSIRESTARTMANAGERCONTROL=Disable`).
* **Interactive ANSI TUI**: Full-screen arrow-key navigation interface and searchable package directory.
* **Standardized Path Placement**: Enforces enterprise filesystem standards (`C:\Program Files\<App>`), strictly prohibiting cluttered root `C:\` directories.

---

## ⚡ OmniGet CLI Quick Reference

OmniGet is available globally on the system `PATH` via `og`:

| Command | Description | Example |
| :--- | :--- | :--- |
| `og search <query>` | Search available packages across all providers | `og search git` |
| `og install <app>` | Silently install an application | `og install python` |
| `og update <app>` | Hot-swap upgrade application safely | `og update pwsh` |
| `og upgrade` | Update all installed packages | `og upgrade` |
| `og preset <name>` | Install curated stack bundle | `og preset DevStack` |
| `og list` | List installed applications and versions | `og list` |
| `og info <app>` | Display detailed package metadata | `og info node` |
| `og` | Launch interactive terminal UI (TUI) | `og` |

---

## 📦 Available Presets

WCOS comes with pre-configured software stacks that can be installed with a single command:

```powershell
og preset DevStack
```

* **`DevStack`**: Complete developer environment (Git, GitHub CLI, Node.js LTS, Python 3.12, .NET SDK, Docker CLI).
* **`Browsers`**: Google Chrome, Mozilla Firefox, Microsoft Edge.
* **`Minimal`**: Lightweight essentials (7-Zip, Notepad++, Git, PowerShell 7).
* **`Utilities`**: System administration tools (Process Hacker, Sysinternals Suite, Everything).
* **`SystemShells`**: WinXShell desktop environment, Microsoft WinFile, WezTerm.
* **`AIStack`**: Google Antigravity CLI, Anthropic Claude Code CLI, OpenAI Codex CLI.

---

## 🔄 Zero-Downtime Hot-Swap Upgrades

A major pain point in standard Windows administration is that running executables (such as `pwsh.exe` during an SSH session) cannot be overwritten because Windows locks open files (`ERROR_SHARING_VIOLATION`).

OmniGet implements atomic in-use rotation:
1. Detects if target executable `target.exe` is locked by a running process.
2. Moves locked binary to `target.exe.old_<timestamp>`. (Windows allows renaming running executables).
3. Writes the new binary into the destination path.
4. Registers `MoveFileExW` with `MOVEFILE_DELAY_UNTIL_REBOOT` to remove the `.old` file on next system start.
5. Suppresses MSI reboots using `REBOOT=ReallySuppress` and `MSIRESTARTMANAGERCONTROL=Disable`.

This allows upgrading PowerShell 7 or Git live over SSH without losing the terminal session!

---

## 📁 Filesystem & Installation Directory Standard

OmniGet enforces strict adherence to Windows enterprise directory standards:

* **64-bit Applications**: Installed strictly under `C:\Program Files\<VendorOrToolName>` (e.g., `C:\Program Files\Git`, `C:\Program Files\nodejs`, `C:\Program Files\OmniGet`).
* **32-bit Applications**: Installed under `C:\Program Files (x86)\<VendorOrToolName>`.
* **Global System State & Databases**: Reside in `C:\ProgramData\OmniGet`.
* **User Data & Configurations**: Reside in `%APPDATA%` or `%USERPROFILE%\.<tool>`.
* **Strict Prohibition of Root `C:\` Directories**: Applications are NEVER installed directly to `C:\` (e.g. `C:\Tools`, `C:\Python` are forbidden).
