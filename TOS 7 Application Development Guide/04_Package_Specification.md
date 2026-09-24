
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
| Install | `dpkg -i` | Package extraction | Files deployed according to the packaging specification (see Chapter 8); the application sees the directory as `/usr/local/<appid>/`, and the platform resolves it to `/Volume<N>/@apps/<appid>/` on the user-selected data volume |
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

> Note: "App Center" refers to the built-in application management interface of the TOS system. Install/start/stop/upgrade/uninstall operations performed by users through this interface will trigger the corresponding lifecycle processes.In the current TOS version, upgrade is not supported for Docker applications.(See [Chapter 9 · Section 6](09_Docker_Development.md#96-lifecycle-operations-install-upgrade-uninstall) for implementation details and data retention policies.)


### 4.2 Version Number Specification

#### 4.2.1 Version Number Rules

> **Platform behaviour (current):** The Developer Platform **does not validate the version number**. Non-standard formats, duplicate versions, and version numbers that do not increase are **not rejected**. The platform simply reads the `version` field from `config.ini` and displays it in the App Center. The rules below are therefore **recommendations for compatibility**, not submission requirements.

**Why the format still matters — update detection:**

The TOS App Center currently determines whether an update is available by **comparing version numbers numerically, segment by segment**. This is a functional dependency rather than a submission rule:

- If the new version is **numerically greater** than the installed one, users see the update prompt.
- If it is **not greater** (equal, lower, or not numerically comparable such as `v2` or `1.0.0-rc1`), the update may **not be detected** — the package is still accepted, but it may never reach existing users.

**Recommended format:**

| Rule | Description |
| :--- | :--- |
| **Characters** | Digits (`0-9`) and dots (`.`) are recommended. Letters and hyphens (e.g. `v1.2`, `1.2.3-beta`) cannot be compared numerically and may break update detection |
| **Segments** | 1 to 3 numeric segments (e.g., `1`, `1.2`, `1.2.3`) |
| **Segment length** | No per-segment length limit; each segment can contain any number of digits |
| **Total length** | No length limit is enforced. Keeping the version string short (the previous limit was 20 characters) is still recommended |
| **Beta versions** | Use the `"beta": true` field in `config.ini` to mark beta releases. Suffixes such as `-beta` / `-rc` / `-alpha` are not rejected, but they break numeric comparison |

**Comparison Rules (Version Ordering):**

Versions are compared **segment-by-segment as numbers**, from left to right:

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

**Submission Outcomes (accepted vs. update-detected):**

| Submitted Version | Existing Version(s) | Outcome |
| :--- | :--- | :--- |
| `1.0` | `1.0` (published) | ✅ Accepted — but users already on `1.0` are shown no update |
| `1.2` | `1.10` (published) | ✅ Accepted — but **not** recognised as an update (`1.2` < `1.10`) |
| `1.0.1` | `1.0` (published) | ✅ Accepted — update prompt shown |
| `2.0.0` | `1.9.9` (published) | ✅ Accepted — update prompt shown |
| `1.0.0-rc1` | `1.0.0` (published) | ✅ Accepted — numeric comparison is unreliable; the update may not be detected |

#### 4.2.2 Version Consistency Across Files

The platform **does not** compare the version numbers inside a package against each other, and it does not require them to match. The version is read from `config.ini`.

| Location | Field | Read by |
| :--- | :--- | :--- |
| `config.ini` | `version` | The Developer Platform and the TOS App Center — this is the version **displayed to users** |
| `DEBIAN/control` (Deb apps only) | `Version` | The Debian package manager (`dpkg`) — this is the version **recorded by the system** |

> **Still recommended: keep them consistent.** A mismatch causes no rejection, but it does cause a confusing installation — users would see one version in the App Center while `dpkg -l` reports another, which complicates upgrades and support.
>
> **Keep `DEBIAN/control` `Version` non-decreasing.** At the `dpkg` level, installing a package whose `Version` is lower than the installed one is refused (downgrade protection). This is package-manager behaviour and is independent of the Developer Platform.
>
> **Version source:** the version is not entered manually on the Developer Platform, and the GitHub/Gitee Release tag is **not** used to determine it — it always comes from the `version` field inside the package you select.

#### 4.2.3 Beta Version Management

Beta status is controlled by the `beta` flag in `config.ini`, not by the version string:

| Release Type | `config.ini` Entry | Platform Display |
| :--- | :--- | :--- |
| First beta | `"version": "1.0.0"`, `"beta": true` | `1.0.0` (Beta) |
| Second beta | `"version": "1.0.1"`, `"beta": true` | `1.0.1` (Beta) |
| Stable release | `"version": "1.0.2"`, `"beta": false` | `1.0.2` |

**Beta Management Notes:**

- Version suffixes such as `-beta`, `-rc`, or `-alpha` are **not rejected**, but they break numeric comparison. Use the `"beta": true` field instead so beta builds are still recognised as new versions by beta users.
- Multiple beta versions are distinguished by increasing the numeric part (recommended: increment the patch segment).
- When promoting a beta to stable, set `"beta": false`. The version number can remain unchanged; if you do increase it, beta users are also offered the update.
- A stable release whose version number is lower than a previously submitted beta build will not be offered to users still on that beta build as an update.

> For detailed beta application workflows, see **Appendix M - Beta App Management**.

#### 4.2.4 Release Asset Naming Specification

When uploading application packages to GitHub/Gitee Releases, name the package files as follows. The **recommended** names are listed below. What the platform actually relies on is the **file extension**: a `.deb` file is treated as a single Deb package, and a `.tar.gz` archive as a dual-package Deb archive or a Docker package (matching the application type you declared when creating the application). (See [Chapter 15 · Step 3](15_Publishing_Process.md#step-3-create-a-release-and-upload-package-assets) for the full upload workflow.)

**The platform does not validate the package file name.** It no longer checks `<app_id>` or `<platform>` against the file name. Package identity is verified *after* the package is downloaded and parsed: the platform compares the `id`, `platform`, and package type inside `config.ini` with the application information you entered when creating the application. The recommended names below are therefore optional — they mainly make it easier for you to pick the correct asset from the list.

**Version numbers:** the version is read from the `version` field inside `config.ini`. It does not need to be part of the file name, and the file name is **no longer** matched against a manually entered version number.

| Application Type | Package Format | Recommended Name | Example |
| :--- | :--- | :--- | :--- |
| Deb (Single Package) | `.deb` file | `<app_id>_<platform>.deb` | `myapp_x86_64.deb` |
| Deb (Dual Package) | `.tar.gz` archive | `<app_id>_<platform>.tar.gz` | `myapp_x86_64.tar.gz` |
| Docker Application | `.tar.gz` archive | `<app_id>.tar.gz` | `myapp.tar.gz` |

**Field Definitions:**

- `<app_id>`: Recommended to match the `id` field in `config.ini` (case‑sensitive)
- `<platform>`: Recommended to match the `platform` field in `config.ini` and be one of the two supported values (`x86_64` or `aarch64`). It does not accept multiple values or `all`. For multi-architecture support, each target architecture must be submitted as a separate build, and it helps to include the architecture suffix in the file name so the correct asset is easy to pick when submitting. The platform does not read the architecture from the file name — it verifies the architecture after parsing the package.

**Release Tag:**

- Every version you intend to submit must be published as a Release with a tag. When you submit a version, you select that tag on the Developer Platform, and the platform downloads the package from that Release for review.
- The tag does **not** have to match the `version` field in `config.ini`. Naming the tag after the version (e.g. `1.0.0` or `v1.0.0`) is recommended for readability, but any tag is accepted.
- The version itself always comes from `config.ini` inside the package, never from the tag.


### 4.3 Upgrades

**Deb Application Upgrades:**
- During upgrade, `preinst` receives `$1 = "upgrade"` parameter
- `postinst` receives `$1 = "configure"` parameter, with `$2` being the old version number
- Use `$2` to detect the old version and perform data migration
- Never delete user data during the upgrade process; only modify configuration formats or migrate data structures
- Users store persistent business data in the `/Volume<N>/<appid>/` shared folder, which is created by the application via `ter_share_add`. The platform will not delete or overwrite user data in this shared folder during application upgrades or reinstallation
- Runtime data (caches, temporary files) is stored in `/usr/local/<appid>/data/` and can be safely regenerated
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
- Preserve data across upgrades through persistent volumes (the platform resolves them to the application data root `/Volume<N>/DockerAppData/<appid>/`)
- Include migration logic in the application entry script if needed
- Docker applications do **not** use TNAS shared folders: no shared folder is created for them, and all persistent business data stays in the container's volume mounts

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

**Path model:** `/usr/local/<appid>/` is the **path your application uses** — write it in your `config.ini`, service unit, lifecycle scripts, and program code. When the application is installed, the platform maps that directory onto the user-selected data volume, where it physically lives at `/Volume<N>/@apps/<appid>/`. `/Volume*/@apps/<appid>/` is **documentation notation for the resolved location on disk**; a developer cannot know in advance which volume a user will choose, so it must never be written into an application. Both views refer to the same files — the mapping is platform-managed, and developers must not assume that two independent physical copies exist.

An application's footprint is divided into three categories that are treated differently on uninstall:

| Category | Location | Examples | Uninstall Behavior |
|---|---|---|---|
| **Static install files** | `/usr/local/<appid>/` (physical location: `/Volume<N>/@apps/<appid>/`) | config.ini, bin/, init.d/, nginx/, webui.bz2 | Managed by App Center/package lifecycle |
| **Application runtime data** | `/usr/local/<appid>/data`, `/usr/local/<appid>/logs` | State, caches, logs, temporary data | Preserve required state across upgrade; remove only under an explicit cleanup policy |
| **User business data (Deb applications)** | `/Volume<N>/<appid>/` (shared folder created via `ter_share_add`) | documents, media, databases | **Never auto-deleted**; retained across upgrades and uninstall |
| **User business data (Docker applications)** | `/Volume<N>/DockerAppData/<appid>/` (volume mounts) | databases, media, documents | Retained unless the user chooses to delete data on uninstall |

**Runtime paths and conditions:**

| Path | Requirement / Creator | Purpose | Cleanup |
|---|---|---|---|
| `/usr/local/<appid>/data`, `/usr/local/<appid>/logs` | Application/lifecycle script, when used | Writable state and logs on the data disk | Follow the documented package policy |
| `/Volume<N>/<appid>/` | Deb applications only: `ter_share_add` or `share_folders`, when user-visible data is needed | User business data (SMB/NFS) | **Retained** (never auto-deleted) |
| `/var/api/<appid>.sock` | Required for iframe apps; created by the application | Unix socket for platform proxy (mode `0660`) | Remove stale socket before bind and clean package-owned residue |
| `/var/lib/<appid>/`, `/var/log/<appid>/` | Legacy compatibility paths; **not required**. The documented location for application state and logs is `/usr/local/<appid>/data` and `/usr/local/<appid>/logs` | App-specific state or logs | Delete only when package-owned and documented |
| `/run/<appid>/` | Only with `RuntimeDirectory=<appid>` | PID files and runtime sockets | systemd-managed |
| Service-private `/tmp` | Only with `PrivateTmp=true` | Isolated temporary files | systemd-managed; physical host path is internal |
| systemd enablement links | Platform/lifecycle script | Service boot registration | Platform/package-managed; do not assume a fixed `/etc/systemd/system/<id>.service` path |
| `/Volume<N>/DockerAppData/<appid>/` | Docker apps | Persistent config & data volumes | Kept unless user chooses to remove volumes |

**Key rules:**

1. `/etc`, `/boot`, and `/usr` locations other than `/usr/local/<appid>/` are protected system directories. Third-party applications must not store writable application configuration there; use the application data directory `/usr/local/<appid>/data/`, which the platform resolves onto the data disk.
2. `PrivateTmp=true` and `RuntimeDirectory=<appid>` create conditional systemd-managed runtime views. Do not document their paths as unconditional artifacts.
3. iframe applications must remove stale `/var/api/<appid>.sock` before binding.
4. Never delete user data in `/Volume<N>/<appid>/` (Deb applications) or `/Volume<N>/DockerAppData/<appid>/` (Docker applications) on upgrade or uninstall. Delete runtime data only when its owner and retention policy are explicitly defined.
5. Docker application persistence must use volume mounts, which the platform resolves to the application data root `/Volume<N>/DockerAppData/<appid>/`. Docker Engine's host-side data root is platform-managed and must not be hardcoded or described as a container path. Docker applications do not use TNAS shared folders.
6. Every application must additionally declare, in its own README, every file it creates at runtime (temp files, generated config, logs, caches) using the required manifest template — see [Section 12.9.6](12_Best_Practices.md#1296-application-declared-runtime-file-manifest-required). Applications must not write to undocumented, arbitrary paths — especially `/tmp` — at runtime.

---

← [Previous Chapter: Quick Start](03_Quick_Start.md) &nbsp;&nbsp;|&nbsp;&nbsp; [Next Chapter: ABI Compatibility](05_ABI_Compatibility.md) → &nbsp;&nbsp;|&nbsp;&nbsp; [📖 Back to Table of Contents](../README.md)
