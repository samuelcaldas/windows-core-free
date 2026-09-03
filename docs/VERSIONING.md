# Windows CoreOS (WCOS) — Versioning Policy & Bumping Guide

This document defines the versioning conventions, release lifecycles, and step-by-step bumping procedures for **Windows CoreOS (WCOS)**.

---

## 1. Semantic Versioning 2.0.0 (SemVer)

Windows CoreOS strictly adheres to **[Semantic Versioning 2.0.0](https://semver.org/)**:

```text
v<MAJOR>.<MINOR>.<PATCH>
```

- **`MAJOR` (e.g. `v2.0.0`)**: Incompatible architectural changes, major underlying Windows OS base release shifts (e.g., migrating from Windows Server 2019 to Server 2025), breaking answer file schema overhauls, or breaking CLI changes.
- **`MINOR` (e.g. `v1.1.0`)**: Backwards-compatible feature additions, new provisioning scripts, added presets in OmniGet, new provider integrations, or enhanced desktop shell recipes.
- **`PATCH` (e.g. `v1.0.1`)**: Backwards-compatible bug fixes, typo corrections, security patch adjustments, documentation updates, or minor performance optimizations.

---

## 2. Single Source of Truth: Git Tags

In accordance with modern git-native workflows, WCOS uses **Annotated Git Tags** (`v*`) as the sole authority for release versions. There is no separate `VERSION` text file that can fall out of synchronization with Git history.

---

## 3. Step-by-Step Version Bumping Instructions

### For Developers & AI Agents

Follow these steps sequentially to create and release a new version of Windows CoreOS:

#### Step 1: Pre-Release Verification & Testing
Before creating any release tag, verify that:
1. All changes are merged into the default branch `master`.
2. The working tree is completely clean (`git status` reports `nothing to commit, working tree clean`).
3. Active VM verification tests pass (OpenSSH connectivity, PowerShell 7 runtime, OmniGet CLI).

```bash
git checkout master
git fetch origin && git rebase origin/master
git status
```

#### Step 2: Determine Current & Next Version
Check the latest existing tag in the repository:

```bash
# View the most recent version tag
git describe --tags --abbrev=0 2>/dev/null || echo "v1.0.0"
```

Choose the next version number based on SemVer rules (e.g. `v1.0.1` for patch, `v1.1.0` for minor, `v2.0.0` for major).

#### Step 3: Create an Annotated Git Tag
Create an annotated tag with a concise summary of the release:

```bash
# Example: Bumping to v1.1.0
git tag -a v1.1.0 -m "release: Windows CoreOS v1.1.0 - brand overhaul and release automation"
```

#### Step 4: Push the Tag to GitHub
Push the tag to the upstream remote repository:

```bash
git push origin v1.1.0
```

---

## 4. Automated Release Pipeline (GitHub Actions)

Pushing a tag matching the pattern `v*` automatically triggers the **GitHub Release Workflow** (`.github/workflows/release.yml`).

### What the Release Workflow Automates:
1. **Validation**: Runs shell and PowerShell lint checks on all provisioning scripts in `scripts/guest/` and `scripts/host/`.
2. **Packaging**:
   - Generates `wcos-scripts.zip`: A portable standalone bundle of all host and guest automation scripts.
   - Generates `wcos-oemdrv-template.zip`: Pre-configured `autounattend.xml` and bootstrap templates.
3. **Changelog Generation**: Extracts commit history between the previous tag and the new tag using GitHub's release notes generator.
4. **GitHub Release Publication**: Creates the official release entry on GitHub and attaches the packaged zip assets.

### Manual Trigger (`workflow_dispatch`)
The release workflow can also be triggered manually from the GitHub web interface or via `gh` CLI:

```bash
# Trigger release workflow manually for testing
gh workflow run release.yml -f tag_name="v1.1.0"
```
