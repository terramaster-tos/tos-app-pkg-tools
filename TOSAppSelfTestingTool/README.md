# TOSAppSelfTestingTool User Guide (English)

> **Audience**: Third-party TOS app developers, including those **without a TOS NAS device**
> **Tool version**: v1.0.3 (beta), check with `./TOSAppSelfTestingTool -v` · [This release](https://github.com/terramaster-tos/tos-app-pkg-tools/releases/tag/v1.0.3-beta)
> **Applicable platform**: TOS 7.0 and above
> **中文版**: see [README_zh-CN.md](README_zh-CN.md)

---

## 1. Introduction

TOSAppSelfTestingTool lets you **self-test your app package before submitting it to the TOS App Center**:

- ✅ **Check (`-c`)**: validates a `.deb` package, a Docker app package (`.tar.gz`), or a pre-packaging app directory against the TOS packaging specification — file validity, `config.ini` fields, icons, language files, compose configuration, etc. **Read-only**: nothing is modified or installed.
- ✅ **Install verification (`-i`, TOS device only)**: runs "check + install" as one flow for Docker app packages, installing the app exactly the way the App Center does, to verify it **actually installs and starts**.
- ✅ **Supported**: Docker app packages (`-c` check + `-i` install verification), single-package deb apps (`-c` check), pre-packaging app directories (`-c` check)
- ⚠️ **Not supported (yet)**: dual-package deb apps (Dual-Package Mode; whole-archive checking to be added in a later release); `-i` install verification currently supports Docker app packages only
- ❌ **Not its role**: it does not replace App Center review

**Why use it?** TOS does not support manually installing Docker-type apps — even if you own a TOS device, there is no ordinary way to verify whether your Docker package installs correctly. The `-i` option of this tool fills exactly that gap. Developers **without** a TOS device can still run the full specification check (`-c`) on any Linux environment and fix all issues before submission.

---

## 2. Requirements

This is a **Linux command-line tool**. It cannot run natively on Windows / macOS.

### 2.1 Environments vs. Features

| Environment | `-c` Check | `-i` Install | Who it's for |
|---|---|---|---|
| TOS device (NAS) | ✅ | ✅ | Developers with a device — full verification |
| Ubuntu / generic Linux (x86_64 / ARM64) | ✅ | ❌ | Developers without a TOS device, CI pipelines |

> Why `-i` requires TOS: the install target is the TOS DockerEngine app directory (`<volume>/@apps/DockerEngine/application/<app_id>`), which the tool auto-detects. This directory layout only exists on TOS devices.

### 2.2 Prerequisites

| Requirement | Needed for | Symptom if missing |
|---|---|---|
| Tool build matching the host architecture | always | `cannot execute binary file` / `Exec format error` |
| root privileges (`sudo`) | `-i` only (on TOS) | `-c` needs no elevation |
| DockerEngine installed on device | `-i` only | "docker not found" message, exit code 2 |
| `xz` / `zstd` decompression tools | checking **.deb** packages | explicit "decompression tools missing" error (environment issue, not a package issue) |
| Network access to the image registry | `-i` image pull only | install fails at the 62% stage, unrelated to the tool itself |

---

## 3. Get the Tool and Pick the Right Build

### 3.1 Download

All releases are published on the repo Releases page: **https://github.com/terramaster-tos/tos-app-pkg-tools/releases**

Current release **v1.0.3 (beta)** — download links (verified working):

| File | Download link (v1.0.3-beta) |
|---|---|
| `TOSAppSelfTestingTool_amd64` | https://github.com/terramaster-tos/tos-app-pkg-tools/releases/download/v1.0.3-beta/TOSAppSelfTestingTool_amd64 |
| `TOSAppSelfTestingTool_arm64` | https://github.com/terramaster-tos/tos-app-pkg-tools/releases/download/v1.0.3-beta/TOSAppSelfTestingTool_arm64 |
| `SHA256SUMS` | https://github.com/terramaster-tos/tos-app-pkg-tools/releases/download/v1.0.3-beta/SHA256SUMS |

Download directly from the command line (on Ubuntu / TOS):

```bash
# x86_64 machines
wget https://github.com/terramaster-tos/tos-app-pkg-tools/releases/download/v1.0.3-beta/TOSAppSelfTestingTool_amd64

# ARM machines
wget https://github.com/terramaster-tos/tos-app-pkg-tools/releases/download/v1.0.3-beta/TOSAppSelfTestingTool_arm64

# (optional) fetch checksums and verify integrity
wget https://github.com/terramaster-tos/tos-app-pkg-tools/releases/download/v1.0.3-beta/SHA256SUMS
sha256sum -c --ignore-missing SHA256SUMS
```

> Notes:
> - To **pin a specific version**, use the `releases/download/<version-tag>/<asset>` form shown above — e.g. `releases/download/v1.0.3-beta/TOSAppSelfTestingTool_amd64`
> - The `releases/latest/download/<asset>` form will start working once a **non-prerelease (stable)** version is published. While the current release is marked beta/pre-release, `latest` resolves to nothing and returns 404 — always use the pinned links during the beta phase
> - These links work only if the release asset names match the table exactly (do not add version suffixes to asset file names when publishing)

### 3.2 Pick the Right Architecture

Two builds are provided by CPU architecture. **They must match your host architecture**:

| File | Architecture | Typical hosts |
|---|---|---|
| `TOSAppSelfTestingTool_amd64` | x86-64 | Most Ubuntu dev machines / CI / x86 TNAS models |
| `TOSAppSelfTestingTool_arm64` | AArch64 | ARM-based TNAS models / ARM servers and boards |

**Confirm your architecture** (inside a Linux environment):

```bash
uname -m
# x86_64  → use the amd64 build
# aarch64 → use the arm64 build
```

Optionally verify the downloaded binary:

```bash
file TOSAppSelfTestingTool_amd64
# should show: ELF 64-bit ... x86-64
```

---

## 4. Deployment

### 4.1 Ubuntu / Generic Linux (no TOS device — start here)

```bash
# 1) Make it executable (required once)
chmod +x TOSAppSelfTestingTool_amd64

# 2) Verify it runs
./TOSAppSelfTestingTool_amd64 -v

# 3) For .deb package checks, install decompression tools
sudo apt install xz-utils zstd
```

Once `-v` prints a version, deployment is done — continue with Section 5.

### 4.2 TOS Device Owners (full verification)

**Option A — scp (recommended)**

From Windows PowerShell / CMD:

```
scp TOSAppSelfTestingTool_amd64 username@NAS_IP:/Volume1/your_folder/
```

**Option B — SMB shared folder**

Type `\\NAS_IP` in the Windows File Explorer address bar and drop the tool into any shared folder.

**SSH in and finish setup:**

```bash
# From Windows PowerShell or CMD
ssh username@NAS_IP

# Go to the folder where you put the tool (adjust the path)
cd /Volume1/your_folder/

# Required on first deployment
chmod +x TOSAppSelfTestingTool_amd64

# Verify
./TOSAppSelfTestingTool_amd64 -v
```

> Note: files copied via an SMB share may lose the executable bit. If `chmod +x` doesn't fix a `Permission denied` error, re-transfer with scp.

---

## 5. `-c / --check`: Validate a Package

### 5.1 Supported Inputs

| Form | Example | What is checked |
|---|---|---|
| `.deb` package | `-c yourapp_1.0.0_amd64.deb` | Full check: file content + deb format (unpacking, metadata consistency, etc.) |
| Docker package | `-c docker_qbittorrent.tar.gz` | Full check: file content + package structure |
| Pre-packaging directory | `-c ./my_app/` | Directory contents only (config.ini fields, icons, language files, compose, service config); no package-format checks |

> ⚠️ **Dual-package deb archives are not supported as a whole (yet).** In Dual-Package Mode (a source deb + a data deb packed into one `<appid>_<platform>.tar.gz`, see Development Guide Chapter 8), feeding that archive to `-c` fails: the tool classifies it as a Docker package candidate and errors out because no docker-compose.yml exists at the top level. See "How to test a dual-package app" below.

**How to test a dual-package app (current version):**

- **The data package (`<appid>.deb`) can be fully checked**: `-c yourapp.deb` — most review-critical items (config.ini fields, icons, language files, webui, nginx config) live in the data package, so this covers the main submission risks
- **The source deb** (a generic deb without config.ini) will fail `-c` with a "config.ini missing" style error — expected behavior, not a defect in your package
- Cross-package rules (data package `Depends` on the source package, `system_id` matching the source package's service file, `config.ini.package` matching the data package, etc.) are **not** cross-validated by the tool yet — verify them manually per Development Guide sections 8.13/8.17
- Whole-archive checking and dual-package install verification (`-i`) will require a later release

### 5.2 Output Examples (English output, v1.0.3)

> The tool prints **English by default** (`-l en`). Samples below reproduce the built-in English messages of v1.0.3; exact wording and rule ordering may vary slightly depending on the package under test — your own run output is authoritative.

**① All checks passed** (single line, exit code 0):

```
$ ./TOSAppSelfTestingTool -c docker_AdGuardHome-v0.107.77.tar.gz
check passed
```

**② Blocking issues found** (check runs to completion, all issues listed, exit code 1):

```
$ ./TOSAppSelfTestingTool -c bad_docker.tar.gz
ERROR [C10] config.ini: missing required field 'relation'
ERROR [C25] config.ini: docker app relation must include 'docker' and 'DockerEngine'
check failed: 2 blocking / 0 warnings
```

**③ Advisory items only** (still passes, exit code 0):

```
$ ./TOSAppSelfTestingTool -c warn_docker.tar.gz
WARN  [D20] extra.txt: docker package should not contain extra top-level entries
check passed: 1 warnings
```

**④ Checking an already-installed app directory** (adds an advisory note that does not affect the verdict):

```
$ ./TOSAppSelfTestingTool -c /Volume1/@apps/DockerEngine/application/AdGuardHomeDocker
check passed
this directory is an installed form (not a pre-package directory): the install flow rewrites config.ini
and unpacks webui; findings reflect the post-install layout and do not mean the package itself is
non-conforming
```

To see the same output in Chinese, add `-l zh-cn` (see Section 8).

### 5.3 Notes

- The check is **read-only**: nothing is installed, built, or modified
- Checking `.deb` packages requires `xz`/`zstd` on the host; when missing, the tool explicitly reports "decompression tools missing" — an environment issue, not a package issue

---

## 6. `-i / --install`: Install Verification (TOS device only, Docker packages only)

### 6.1 Prerequisites

- **Docker app packages only (`docker_*.tar.gz`)**; passing a `.deb` or a directory fails immediately (exit code 2):

```
$ ./TOSAppSelfTestingTool -i yourapp_1.0.0_amd64.deb
yourapp_1.0.0_amd64.deb is a deb package: install currently supports docker app packages (.tar.gz) only; deb is not supported
```

- Run as **root** (`sudo`)
- DockerEngine must be installed on the device; the install location is auto-detected, no manual configuration needed
- Install directory: `<volume>/@apps/DockerEngine/application/<app_id>` (app_id comes from config.ini inside the package)

### 6.2 Execution Flow (single progress stream, percentage per step)

```
$ sudo ./TOSAppSelfTestingTool -i docker_AdGuardHome-v0.107.77.tar.gz
[ 10%] [##------------------] extracting package -> /Volume1/@apps/DockerEngine/application/.install-staging-...
[ 20%] [####----------------] checking file integrity
[ 25%] [#####---------------] checking field conformance
[ 35%] [#######-------------] checking compose project name adguardhome
[ 41%] [########------------] moving to the install dir -> /Volume1/@apps/DockerEngine/application/AdGuardHomeDocker
[ 48%] [#########-----------] writing docker-compose.yml
[ 62%] [############--------] pulling images and syncing share folder ownership
[ 77%] [###############-----] creating containers
[ 83%] [################----] updating app access path and install data
[ 91%] [##################--] running post-install
[100%] [####################] starting containers
installed: AdGuardHomeDocker, compose project adguardhome, install dir /Volume1/@apps/DockerEngine/application/AdGuardHomeDocker
```

The flow has two stages:

1. **Check stage** (10%–25%): the package is unpacked to a staging directory and fully checked — on success it proceeds silently; **on the first issue it aborts immediately and never touches an existing installation**
2. **Install stage** (35%–100%): only after passing does it land in the real install directory (overwriting any previous install), then installs and starts via the compose flow

**When the check fails (fail-fast, first issue only)**:

```
$ sudo ./TOSAppSelfTestingTool -i bad_docker.tar.gz
[ 10%] [##------------------] extracting package
[ 20%] [####----------------] checking file integrity
[ 25%] [#####---------------] checking field conformance
ERROR [C10] config.ini: missing required field 'relation'
check failed, installation aborted
```

### 6.3 Post-install Processing (automatic, identical to App Center behavior)

- Auto-avoids compose project name / container name conflicts (`xxx` → `xxx_1`) and rewrites config.ini and compose accordingly
- If containers run as a non-root user, ownership of mounted/shared directories is automatically reassigned to that user to avoid runtime permission errors
- Reads the access port from compose `x-app-meta.web` and writes the access path back into config.ini
- Writes install metadata so the installed app is fully recognized by the App Center

### 6.4 Failure Behavior

| Failure stage | Output & leftovers |
|---|---|
| Blocking issue at check | First error + `check failed, installation aborted`; existing installation untouched |
| Image pull failure (62%) | Single-line error, then abort; unpacked directory deleted |
| Container creation failure (77%) | Single-line error; unpacked directory deleted |
| Container start failure (100%) | Single-line error + `installed (not started): ...`; **install directory retained** for troubleshooting / manual start |
| Post-install failure (91%) | Single-line error; install directory retained, container not started |

Image pull failure example (no network):

```
[ 62%] [############--------] pulling images and syncing share folder ownership
install failed: Error response from daemon: failed to resolve reference "docker.io/adguard/adguardhome:v0.107.77": ...
```

> Failure messages print the bare error only; everything after `install failed:` is the raw docker / system error.

---

## 7. Exit Codes

| Exit code | Meaning |
|---|---|
| 0 | Check passed / install succeeded |
| 1 | Blocking issue found / install failed |
| 2 | Could not complete (invalid usage or environment problem — not a package issue) |

Exit codes are CI-friendly (e.g., branch on `$?` after the check step).

---

## 8. Recommended Self-Test Workflow

```
Package
  │
  ▼
-c check (Ubuntu / TOS) ──────── failed → fix issues listed → repackage
  │ passed
  ▼
Have a TOS device?
  ├─ Yes → -i install verification (sudo) ─── failed → troubleshoot → repackage
  │         │ install completes, app visible in App Center, app reachable
  └─ No ────┘
  ▼
Submit for review per "TOS 7 Application Development Guide" Chapter 15 (Publishing Process)
```

Quick command reference:

```bash
# Version / help
./TOSAppSelfTestingTool -v
./TOSAppSelfTestingTool -h

# Output language: en (default) / zh-cn
./TOSAppSelfTestingTool -l zh-cn -c /path/docker_qbittorrent.tar.gz

# Export a markdown check report to a directory (-o / --output, alias -out / --out)
./TOSAppSelfTestingTool -c /path/docker_qbittorrent.tar.gz -o ./reports/

# Pre-submission check (pick any of the three forms)
./TOSAppSelfTestingTool -c /path/docker_qbittorrent.tar.gz
./TOSAppSelfTestingTool -c /path/yourapp_1.0.0_amd64.deb
./TOSAppSelfTestingTool -c /path/pre-packaging_app_directory/

# Install a Docker package with progress (root required, TOS only)
sudo ./TOSAppSelfTestingTool -i /path/docker_qbittorrent.tar.gz

# Overwrite install: just run -i again on the same package (old install is cleaned then reinstalled)

# Check an already-installed app directory on the device
./TOSAppSelfTestingTool -c /Volume1/@apps/DockerEngine/application/qbittorrent
```

**About output language (`-l/--language`)**: the tool's output is **English by default** (`en`) — global developers need no extra settings; pass `-l zh-cn` for Chinese. Any other value is rejected ("unsupported language"; only en / zh-cn are supported).

---

## 9. FAQ

**Q: `cannot execute binary file` / `Exec format error`?**
Architecture mismatch. Run `uname -m` and switch to the matching build (amd64 ↔ x86_64, arm64 ↔ aarch64).

**Q: `Permission denied`?**
Missing `chmod +x`; or the executable bit was lost via an SMB copy — re-transfer with scp and `chmod +x` again.

**Q: "decompression tools xz/zstd missing" during a check?**
A host environment issue, not a package issue. Install and retry: `sudo apt install xz-utils zstd`.

**Q: `-i` says "docker not found: /VolumeN/@apps/DockerEngine/..."?**
DockerEngine is not installed, or its install location doesn't match the `<volume>/@apps/DockerEngine/dockerd/bin/` convention.

**Q: What can I verify without a TOS device?**
The **full specification check** via `-c` on Ubuntu. Install verification (`-i`) needs a TOS device; we strongly recommend borrowing one before submission — it noticeably lowers the chance of review rejection.

**Q: Can I see check results before deciding to install?**
Run `-c` first (lists all issues), then `-i`. The install flow itself also runs a check first and aborts on the first issue.

**Q: Are there leftover directories after a failed install?**
Pull/create failure (62%/77%) → the unpacked directory is deleted automatically, no leftovers; start/post-install failure (91%/100%) → the full install directory is retained for troubleshooting or a manual retry.

**Q: Is `.deb` installation supported?**
Not yet — current `-i` supports Docker app packages only. `.deb` checking (`-c`) is unaffected.

**Q: Can a dual-package deb archive (source deb + data deb in one tar.gz) be checked as a whole?**
Not in the current version (v1.0.3). Workaround: run `-c` on the **data package deb** alone (most review-critical items live there), and verify cross-package rules manually per Development Guide sections 8.13/8.17. Checking the source deb alone fails with a "config.ini missing" style error — expected. Whole-archive checking and dual-package install verification are planned for a later release.

**Q: Is the tool output in English or Chinese?**
**English by default** (`en`); pass `-l zh-cn` for Chinese. The exported markdown report (`-o/--output`) follows the same language setting.

---

## 10. Feedback

For issues not covered by this guide, please open an Issue in this repository, including: tool version (`-v` output), host environment (`uname -a`), and the full command with its output.
