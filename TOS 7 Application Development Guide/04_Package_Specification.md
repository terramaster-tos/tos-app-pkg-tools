
# 4. Package Specification

This section defines the formal specifications for TOS 7 application packages. All applications must comply with this specification.


### 4.1 Application Lifecycle

TOS 7 applications follow a clearly defined lifecycle:

```
  Install ──► Configure ──► Start ──► Running
     │            │            │           │
     │            │            │           ├── Stop ──► Stopped ──► Start (Restart)
     │            │            │
     │            │            └── Crash ──► Auto-restart (if configured)
     │            │
     │            └── Upgrade ──► Stop ──► Install New Version ──► Migrate ──► Start
     │
     └── Uninstall ──► Stop ──► Cleanup ──► Remove
```

**Deb Application Lifecycle Stages:**

| Stage | Trigger | Script/Operation | Expected Behavior |
|---|---|---|---|
| Before Install | `dpkg -i` | `DEBIAN/preinst` | Create user, check prerequisites, create directories |
| Install | `dpkg -i` | Package extraction | Files deployed according to the packaging specification (see Chapter 8); actual installation path on TOS 7 is `/Volume*/@apps/<appid>/` |
| After Install | `dpkg -i` | `DEBIAN/postinst` | Set permissions, enable service, start service |
| Start | `systemctl start` | systemd / init.d | Application process starts |
| Stop | `systemctl stop` | systemd / init.d | Application process gracefully stops |
| Before Uninstall | `dpkg --remove` | `DEBIAN/prerm` | Stop service |
| After Uninstall | `dpkg --remove` | `DEBIAN/postrm` | Clean up user, data, residual files |
| Upgrade | `dpkg -i` (new version) | prerm → Upgrade → postinst | Stop old version, install new version, migrate data, start |

**Docker Application Lifecycle Stages:**

| Stage | Trigger | Operation | Expected Behavior | Additional Notes |
|---|---|---|---|---|
| Install | App Center (user clicks "Install" button) | Pull image, create volumes | Image available, data directories created | Platform automatically executes the installation process; no additional developer intervention required |
| Start | App Center (user clicks "Start" button) / `docker-compose up` | Start container | Service accessible | Users can also manually start via command line, consistent with platform operation logic |
| Stop | App Center (user clicks "Stop" button) / `docker-compose down` | Stop container | Service stopped, data retained | Only stops the container process; mounted data volumes are not deleted |
| Upgrade | App Center (user clicks "Update" button when a new version is available) | Pull new image, rebuild container | Zero-downtime or brief downtime | It is recommended that applications support smooth upgrades to avoid data interruption |
| Uninstall | App Center (user clicks "Uninstall" button) | Remove container, optionally clean up volumes | All resources released | Users can choose whether to retain data volumes to avoid accidental data deletion |

> Note: "App Center" refers to the built-in application management interface of the TOS system. Install/start/stop/upgrade/uninstall operations performed by users through this interface will trigger the corresponding lifecycle processes.


### 4.2 Version Number Specification

#### 4.2.1 Version Number Rules

**Format Rules:**

| Rule | Description |
| :--- | :--- |
| **Allowed characters** | Digits (`0-9`) and dots (`.`) only |
| **Segments** | 1 to 3 numeric segments (e.g., `1`, `1.2`, `1.2.3` are all valid) |
| **Segment length** | No per‑segment length limit; each segment can contain any number of digits |
| **Total length** | Maximum **20 characters** (including dots). Exceeding this will result in rejection |
| **Prohibited** | Alphabetic characters (`v1.2`), hyphens (`1.2.3-beta`), empty segments (`1..2`), or more than 3 segments (`1.2.3.4`) |
| **Beta versions** | Must use the `"beta": true` field in `config.ini`; version number suffixes (e.g., `-beta`, `-rc`, `-alpha`) are **not** supported |

**Comparison Rules (Version Ordering):**

Versions are compared **segment‑by‑segment as numbers**, from left to right:

| Rule | Description |
| :--- | :--- |
| **Numeric comparison** | Each segment is compared as an integer (leading zeros are ignored, e.g., `01.2` equals `1.2`) |
| **Missing segments** | Missing segments are treated as `0` (e.g., `1.2` equals `1.2.0`; `1` equals `1.0.0`) |
| **Comparison result** | The first segment where values differ determines the order |

**Comparison Examples:**

| Comparison | Result | Reason |
| :--- | :--- | :--- |
| `1.10` vs `1.2` | `1.10` > `1.2` | Second segment: `10` > `2` |
| `2.1` vs `1.9.9` | `2.1` > `1.9.9` | First segment: `2` > `1` |
| `1.2` vs `1.2.0` | Equal | Missing segment treated as `0` |
| `01.1` vs `1.0` | `01.1` > `1.0` | Ignore leading zeros: `1.1` > `1.0` |
| `123` vs `111.3` | `123` > `111.3` | First segment: `123` > `111` |

**Upgrade Constraints:**

| Constraint | Description |
| :--- | :--- |
| **Strictly increasing** | Each newly submitted version **must be greater** than **all** existing historical versions of the same application (regardless of status: published, reviewing, rejected, draft) |
| **Downgrade prohibited** | Version downgrades are strictly prohibited. Submitting a version number lower than or equal to any existing version will be rejected |
| **Re-submission after rejection** | Rejected applications cannot be re-submitted with the same version number. A new, larger version number is required |

**Validation Failure Examples:**

| Attempted Submission | Existing Version(s) | Result |
| :--- | :--- | :--- |
| `1.0` | `1.0` (rejected) | ❌ Rejected (must be > `1.0`) |
| `1.0.1` | `1.0` (published) | ✅ Accepted |
| `1.2` | `1.10` (reviewing) | ❌ Rejected (`1.2` < `1.10`) |
| `2.0.0` | `1.9.9` (rejected) + `1.9.8` (published) | ✅ Accepted (must be > `1.9.9`) |

#### 4.2.2 Version Consistency Across Files

The version number **must be exactly identical** (character‑for‑character) across all of the following locations:

| Location | Field | Example |
| :--- | :--- | :--- |
| Developer Platform (submission form) | `Version To List` | `1.2.3` |
| `config.ini` | `version` | `"version": "1.2.3"` |
| `DEBIAN/control` (Deb apps only) | `Version` | `Version: 1.2.3` |
| GitHub/Gitee Release tag | Tag name | `1.2.3`|

> ⚠️ **Important:** The platform validates consistency upon submission. Any mismatch will result in an automated rejection. The version string in `config.ini` is considered the authoritative source.

#### 4.2.3 Beta Version Management

The platform does not support version number suffixes (e.g., `-beta`, `-rc`, `-alpha`). Use the `beta` flag in `config.ini` to mark beta releases:

| Release Type | `config.ini` Entry | Platform Display |
| :--- | :--- | :--- |
| First beta | `"version": "1.0.0"`, `"beta": true` | `1.0.0` (Beta) |
| Second beta | `"version": "1.0.1"`, `"beta": true` | `1.0.1` (Beta) |
| Stable release | `"version": "1.0.2"`, `"beta": false` | `1.0.2` |

**Beta Management Rules:**

- Multiple beta versions are distinguished by incrementing the patch number (or any higher segment)
- When promoting a beta to stable, simply set `"beta": false`; the version number can remain the same
- The platform will not allow a stable release with a **lower** version number than any previously submitted beta version of the same app

> For detailed beta application workflows, see **Appendix N - Beta Version Application Management**.

#### 4.2.4 Release Asset Naming Specification

When uploading application packages to GitHub/Gitee Releases, the package file must follow the naming conventions below. (See [Chapter 15 · Step 3](15_Publishing_Process.md#step-3-create-a-release-and-upload-package-assets) for detailed naming and format requirements.)

**Important:** Version numbers are **not** included in package file names. The version is specified through the Release tag/version when creating the Release. The platform will read the version from the Release metadata and verify it against the `version` field in `config.ini`.

| Application Type | Package Format | Naming Convention | Example |
| :--- | :--- | :--- | :--- |
| Deb (Single Package) | `.deb` file | `<app_id>_<platform>.deb` | `myapp_x86_64.deb` |
| Deb (Dual Package) | `.tar.gz` archive | `<app_id>_<platform>.tar.gz` | `myapp_x86_64.tar.gz` |
| Docker Application | `.tar.gz` archive | `<app_id>.tar.gz` | `myapp.tar.gz` |

**Field Definitions:**

- `<app_id>`: Must exactly match the `id` field in `config.ini` (case‑sensitive)
- `<platform>`: Must exactly match the `platform` field in `config.ini` (`x86_64` or `aarch64`)

**Release Tag Requirement:**

- The Release tag/version **must** exactly match the `version` field in `config.ini` (the platform automatically strips an optional `v` prefix for comparison)
- **Examples:**
  - If `config.ini.version = "1.0.0"`, the Release tag can be `1.0.0` or `v1.0.0` (both accepted)
  - If `config.ini.version = "1.2.3"`, the Release tag **cannot** be `1.2` or `1.2.3-beta`
- Mismatches between the Release version and `config.ini.version` will result in automated rejection


### 4.3 Upgrades

**Deb Application Upgrades:**
- During upgrade, `preinst` receives `$1 = "upgrade"` parameter
- `postinst` receives `$1 = "configure"` parameter, with `$2` being the old version number
- Use `$2` to detect the old version and perform data migration
- Never delete user data during the upgrade process; only modify configuration formats or migrate data structures
- Users store persistent business data in the `/Volume*/<appid>/` shared folder, which is created by the application via `ter_share_add`. The platform will not delete or overwrite user data in this shared folder during application upgrades or reinstallation
- Runtime data (caches, temporary files) is stored in `/Volume*/@apps/<appid>/data/` and can be safely regenerated
- It is recommended not to store data in system common directories such as `/etc`, `/var`, `/usr/bin`, as these directories may be overwritten by system updates or application upgrades, leading to data loss

```bash
# Example: postinst with migration logic
case "$1" in
    configure)
        if [ -n "$2" ]; then
            # Upgrading from version $2
            if dpkg --compare-versions "$2" lt "2.0.0"; then
                # Migrate v1.x configuration format to v2.x
                /usr/local/<appid>/bin/migrate.sh "$2"
            fi
        else
            # Fresh install
            echo "Fresh install"
        fi
        ;;
esac
```


**Docker Application Upgrades:**
- Pull new image tags
- Rebuild containers using existing volume mounts
- Preserve data across upgrades through persistent volumes
- Include migration logic in the application entry script if needed

### 4.4 Compatibility Matrix

| TOS Version | Base System | glibc | Python3 | Docker | Node.js |
|---|---|---|---|---|---|
| TOS 7.0 | Ubuntu 22.04-compatible | 2.35 | 3.10 | 20.10+ | 18.x |
| TOS 7.x | Ubuntu 22.04-compatible | 2.35 | 3.10 | 20.10+ (or higher) | 18.x (or higher) |

> **Note:** Node.js versions are for reference within Docker containers only. Deb applications must not directly depend on them.

> **Important:** Applications must declare the minimum TOS version requirement via the `low_version` field in config.ini. The platform will automatically filter out incompatible devices.

> **TOS 7.x Minor Version Compatibility:** The TOS 7.x minor version series (including 7.1 and above) will maintain ABI/API compatibility for core dependencies (glibc/Python3/Docker/Node.js), compatible with the Ubuntu 22.04-compatible root filesystem. Applications developed for TOS 7.0 will run without additional adaptation.

**TOS 7 Minor Version Compatibility:**
- The `low_version` field must specify the minimum required TOS version
- When submitting updates, test on the latest TOS 7 minor version

### 4.5 Case Sensitivity Specification

TOS employs a root filesystem compatible with Ubuntu Linux, and the filesystem is strictly case-sensitive. All applications must follow the rules below:

| Element | Rule |
|---|---|
| Filenames | Strictly match case. `config.ini` ≠ `Config.ini` ≠ `CONFIG.INI` |
| Directory names | Strictly match case. `/images/icons/` ≠ `/Images/Icons/` |
| config.ini key names | All key names must be lowercase. `"version"` correct, `"Version"` incorrect |
| Application ID (`id`) | Strictly match case. `MyApp` ≠ `myapp`. Cannot be modified after creation |
| Systemd service name | Must strictly match, case-sensitive |


**Prohibited:** Using case variants of the same file or directory within a single application package. This causes "file not found" and "service start failure" errors on Linux.


### 4.6 Cross-Platform Line Ending Specification (CRLF to LF)

All scripts and configuration files running on the TOS system (Linux environment) **must use LF (`\n`) as the line ending**. Using Windows default CRLF (`\r\n`) line endings is prohibited.

#### Impact

- Script execution errors: `bad interpreter: No such file or directory`
- Configuration file parsing failures (e.g., systemd service files, Nginx configurations)
- Interpreter paths incorrectly recognized as non-existent binaries like `/bin/bash\r`

#### Mandatory Requirements

1. All `.sh` / `.py` / `.ini` / `.lang` / `.service` / `.conf` files must be converted to LF line endings before submission
2. Deb package build scripts must include automatic conversion logic to prevent CRLF from being introduced during the build process

#### Recommended Fixes

##### Option 1: Automatic Conversion in Build Script (Recommended)

```python
import os

def convert_crlf_to_lf(file_path):
    with open(file_path, "rb") as f:
        content = f.read()
    content = content.replace(b"\r\n", b"\n")
    with open(file_path, "wb") as f:
        f.write(content)

# Before packaging, iterate over all files that need conversion
for root, _, files in os.walk("your_app_source/"):
    for name in files:
        if name.endswith((".sh", ".py", ".ini", ".lang", ".service", ".conf")):
            convert_crlf_to_lf(os.path.join(root, name))
```

##### Option 2: Local Development Tool Configuration

- **VS Code**: Click `CRLF` in the bottom-right status bar, switch to `LF`, then save
- **Git Global Configuration** (prevent subsequent files from being auto-converted to CRLF):

```bash
git config --global core.autocrlf input
```

### 4.7 Runtime Filesystem Layout

> **Scope:** Sections 4.1–4.6 and Chapter 8 define the **static** package structure — the files shipped inside the `.deb`/`.tar.gz`. This section defines the **runtime footprint**: which additional files and directories appear on the TOS system after the application is installed and running. For the full per-path reference, lifecycle table, and self-review checklist, see [Section 12.9](12_Best_Practices.md#129-runtime-filesystem-layout).

**Path model:** Deb payloads use logical `/usr/local/<appid>/` paths as defined in Chapter 8, while App Center installs third-party applications on the user-selected data volume at `/Volume*/@apps/<appid>/`. The mapping is platform-managed; developers must not assume that both paths are independent physical copies.

An application's footprint is divided into three categories that are treated differently on uninstall:

| Category | Location | Examples | Uninstall Behavior |
|---|---|---|---|
| **Static install files** | `/Volume*/@apps/<appid>/` (logical Deb payload path: `/usr/local/<appid>/`) | config.ini, bin/, init.d/, nginx/, webui.bz2 | Managed by App Center/package lifecycle |
| **Application runtime data** | `/Volume*/@apps/<appid>/data`, `/Volume*/@apps/<appid>/logs` | State, caches, logs, temporary data | Preserve required state across upgrade; remove only under an explicit cleanup policy |
| **User business data** | `/Volume*/<appid>/` (shared folder) | documents, media, databases | **Never auto-deleted**; retained across upgrades and uninstall |

**Runtime paths and conditions:**

| Path | Requirement / Creator | Purpose | Cleanup |
|---|---|---|---|
| `/Volume*/@apps/<appid>/data`, `/Volume*/@apps/<appid>/logs` | Application/lifecycle script, when used | Writable state and logs on the data disk | Follow the documented package policy |
| `/Volume*/<appid>/` | `ter_share_add` or `share_folders`, when user-visible data is needed | User business data (SMB/NFS) | **Retained** (never auto-deleted) |
| `/var/api/<appid>.sock` | Required for iframe apps; created by the application | Unix socket for platform proxy (mode `0660`) | Remove stale socket before bind and clean package-owned residue |
| `/var/lib/<appid>/`, `/var/log/<appid>/` | Optional compatibility paths; must be explicitly created | App-specific state or logs | Delete only when package-owned and documented |
| `/run/<appid>/` | Only with `RuntimeDirectory=<appid>` | PID files and runtime sockets | systemd-managed |
| Service-private `/tmp` | Only with `PrivateTmp=true` | Isolated temporary files | systemd-managed; physical host path is internal |
| systemd enablement links | Platform/lifecycle script | Service boot registration | Platform/package-managed; do not assume a fixed `/etc/systemd/system/<id>.service` path |
| `/Volume*/DockerAppData/<appid>/` | Docker apps | Persistent config & data volumes | Kept unless user chooses to remove volumes |

**Key rules:**

1. `/etc`, `/usr`, and `/boot` are protected system directories. Third-party applications must not store writable application configuration there; use the application data directory on `/Volume*/`.
2. `PrivateTmp=true` and `RuntimeDirectory=<appid>` create conditional systemd-managed runtime views. Do not document their paths as unconditional artifacts.
3. iframe applications must remove stale `/var/api/<appid>.sock` before binding.
4. Never delete user data in `/Volume*/<appid>/` on upgrade or uninstall. Delete runtime data only when its owner and retention policy are explicitly defined.
5. Docker application persistence must use volume mounts under `/Volume*/`. Docker Engine's host-side data root is platform-managed and must not be hardcoded or described as a container path.
6. Every application must additionally declare, in its own README, every file it creates at runtime (temp files, generated config, logs, caches) using the required manifest template — see [Section 12.9.6](12_Best_Practices.md#1296-application-declared-runtime-file-manifest-required). Applications must not write to undocumented, arbitrary paths — especially `/tmp` — at runtime.

---

← [Previous Chapter: Quick Start](03_Quick_Start.md) &nbsp;&nbsp;|&nbsp;&nbsp; [Next Chapter: ABI Compatibility](05_ABI_Compatibility.md) → &nbsp;&nbsp;|&nbsp;&nbsp; [📖 Back to Table of Contents](../README.md)
