
# 12. Best Practices

### 12.1 Application Directory Layout

Follow a consistent directory layout to ensure maintainability and compatibility. All non-embedded applications (both official and third-party) are installed on **storage volumes**. Your application sees that directory as `/usr/local/<appid>/`, and the platform resolves it to `/Volume<N>/@apps/<appid>/` on the volume chosen by the user at installation. Write the `/usr/local/<appid>/…` form in your code, service unit, and scripts.

**Standard Directory Layout:**

```
/usr/local/<appid>/              # application-visible path (platform resolves it onto the user-selected volume)
├── <binary>          # Application executable
├── config.ini        # Application configuration file
├── <appid>.lang      # Language file
├── images/           # Icon resources
├── webui.bz2         # Front-end page archive (WebUI applications)
├── nginx/            # Nginx configuration (externally opened applications)
├── init.d/           # Systemd service files
├── data/             # Runtime data (caches, temporary files, writable)
└── logs/             # Application logs
```

> **Note:** These are the paths your application uses. After installation the platform maps `/usr/local/<appid>/` onto the volume the user chose at installation, where the same directory physically lives at `/Volume<N>/@apps/<appid>/`. `*` is documentation notation for that volume number (e.g., Volume1, Volume2) — the platform does **not** expand it, so never write `/Volume*/…` into a compose file, a systemd unit, a lifecycle script, or any other machine-read configuration.

**Data Storage Recommendations:**
- **Runtime data** (`/usr/local/<appid>/data/`) — Application-generated caches, temporary files, and runtime state. This data can be safely regenerated.
- **Logs** (`/usr/local/<appid>/logs/`) — Application log files. Ensure log rotation is configured.
- **User business data** — Persistent business data (documents, media, databases).
  - **Deb applications**: store it in a shared folder (created via `ter_share_add`) so that users can reach it over SMB/NFS.
  - **Docker applications**: store it in the application data root `/Volume<N>/DockerAppData/<appid>/` through volume mounts. Docker applications do not use shared folders.

### 12.2 Data Persistence

**Understanding Data Types:**

| Data Type | Path | Description |
|---|---|---|
| **Runtime Data** | `/usr/local/<appid>/data/` | Caches, temporary files, runtime state (can be regenerated) |
| **User Data (Deb applications)** | `/Volume<N>/<appid>/` (shared folder) | Persistent business data (must survive app upgrades) |
| **User Data (Docker applications)** | `/Volume<N>/DockerAppData/<appid>/` (volume mounts) | Persistent business data (must survive app upgrades) |

**Deb Applications:**

1. **Runtime data** is stored in `/usr/local/<appid>/data/`
2. **User data** must be stored in a shared folder created by the application:
   ```bash
   # In postinst — create a shared folder for user data
   ter_share_add -name <appid> -owner <appid>
   ```
3. To maintain compatibility, the application can create a symbolic link from the shared folder into its own data directory:
   ```bash
   # Deb applications only. The destination uses the application-visible path; the shared-folder side is still pending platform confirmation.
   ln -s <shared_folder_path> /usr/local/<appid>/data
   ```
4. The shared folder `/Volume<N>/<appid>/` is accessible to users via SMB/NFS

**Docker Applications:**

1. Mount configuration and runtime data using host-side paths; the data is placed under the application data root `/Volume<N>/DockerAppData/<appid>/`:
   ```yaml
   volumes:
     - ./config:/config
     - ./cache:/cache
   ```
2. Persistent business data must be stored through volume mounts, which the platform resolves to the application data root `/Volume<N>/DockerAppData/<appid>/`:
   ```yaml
   volumes:
     - ./data:/data
   ```
   Docker applications do **not** use TNAS shared folders: no shared folder is created for them, they must not call `ter_share_add`, and shared-folder mount placeholders (`<shared_folder_path>`) must not appear in a Docker package.
3. Storing data in the container filesystem is prohibited
4. Use separate volumes for configuration and data to support independent backups

> **Note:** These are the paths your application uses. After installation the platform maps `/usr/local/<appid>/` onto the volume the user chose at installation, where the same directory physically lives at `/Volume<N>/@apps/<appid>/`. `*` is documentation notation for that volume number (e.g., Volume1, Volume2) — the platform does **not** expand it, so never write `/Volume*/…` into a compose file, a systemd unit, a lifecycle script, or any other machine-read configuration.
> - Runtime data can be safely deleted without losing user business data
> - User business data must be backed up before app upgrades — the shared folder for Deb applications, the application data root `/Volume<N>/DockerAppData/<appid>/` for Docker applications

### 12.3 Logging

**Deb Applications:**
```bash
# Use systemd journal (recommended)
# All stdout/stderr from the service is automatically captured
# View logs: journalctl -u <appid>

# Or write to file
exec >> /usr/local/<appid>/logs/app.log 2>&1
```

**Docker Applications:**
```yaml
services:
  myapp:
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"
```

> **Note:** Each container log file is limited to 10MB, with 3 files retained, for a total log size cap of 30MB.

**Best Practices:**
- Use structured logging (JSON format recommended)
- Include timestamp, level, and context in every log entry
- Rotate logs to prevent disk exhaustion
- Never log sensitive information (passwords, tokens, personal data)

**Log Retention and Cleanup:**

| Log Type | Maximum Retention | Cleanup Method |
|---|---|---|
| Application Logs (files) | 30 days | Logrotate: daily rotation, retain 30 files |
| Systemd Journal | Managed by platform | Automatically managed via journald limits |
| Docker Container Logs | 10MB per file, 3 files total | Docker logging driver configuration |

**Logrotate Configuration:**
```
/usr/local/<appid>/logs/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
}
```

### 12.4 Resource Limits

| Resource | Deb Applications (systemd) | Docker Applications (compose) |
|---|---|---|
| Memory | `MemoryMax=512M` | `memory: 512M` |
| CPU | `CPUQuota=200%` | `cpus: '2.0'` |
| File Descriptors | `LimitNOFILE=65536` | N/A (container level) |
| Processes | `LimitNPROC=256` | N/A (container level) |
| Disk | N/A (use quotas) | Volume size limit |

**Guidelines:**
- Set resource limits based on expected workload, not maximum possible usage
- Reserve a 20-30% peak buffer on top of typical usage
- Document resource requirements in README.md

### 12.5 Health Checks

**Deb Applications:**
```ini
# In systemd service file
[Unit]
StartLimitBurst=5
StartLimitIntervalSec=60

[Service]
Restart=on-failure
RestartSec=10
WatchdogSec=30
```

**Docker Applications:**
```yaml
services:
  myapp:
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
```

### 12.6 Upgrades and Migration

**Deb Applications:**
1. Always check for old versions in `postinst`:
   ```bash
   if [ -n "$2" ]; then
       # Upgrading from $2 — run migration
       /usr/local/<appid>/bin/migrate --from "$2"
   fi
   ```
2. Never delete user data during upgrades
3. Back up before modifying configuration formats
4. Migration logic should be reversible to support rollback
5. **Store application state under `/usr/local/<appid>/data/`, and user-visible business data in a shared folder (Deb applications)**, so that data is not lost after upgrades

**Docker Applications:**
1. Use an entrypoint script to detect and migrate old data formats:
   ```bash
   #!/bin/bash
   if [ -f /config/version ]; then
       OLD_VERSION=$(cat /config/version)
       if [ "$OLD_VERSION" != "$NEW_VERSION" ]; then
           /app/migrate.sh "$OLD_VERSION" "$NEW_VERSION"
       fi
   fi
   echo "$NEW_VERSION" > /config/version
   ```
2. Test upgrade paths for at least the last 2 major versions

### 12.7 Security Hardening

**Deb Applications:**
```ini
[Service]
# Drop all capabilities, add only required ones
AmbientCapabilities=CAP_NET_BIND_SERVICE
NoNewPrivileges=true

# File system protection
ProtectSystem=strict
ProtectHome=true
# Write access is limited to the application's own data and log directories.
# systemd does not expand wildcards, so list real absolute paths only.
ReadWritePaths=/usr/local/<appid>/data /usr/local/<appid>/logs

# Network namespace (optional)
# PrivateNetwork=true  # Only when network is not needed

# User namespace
# PrivateUsers=true
```

> **Note:** Third-party applications must not write outside their own application directory — `/etc`, `/boot`, and `/usr` locations other than `/usr/local/<appid>/` are off limits. Because `ProtectSystem=strict` mounts `/usr` read-only, the application's own writable directories must be listed explicitly in `ReadWritePaths`: use `/usr/local/<appid>/data` and `/usr/local/<appid>/logs` (Section 12.2). `ReadWritePaths` accepts **real absolute paths only** - neither systemd nor the platform expands wildcards.

**Docker Applications:**
```yaml
services:
  myapp:
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE  # Only when binding to ports below 1024
    read_only: true
    tmpfs:
      - /tmp
      - /run
```

> **Required (all submissions must include):**
> - `NoNewPrivileges=true`
> - `ProtectSystem=strict`
> - `ProtectHome=true`
> - `ReadWritePaths` (explicit paths only)
> - Non-root `User`/`Group`
>
> **Recommended (strongly suggested):**
> - `AmbientCapabilities` (only needed capabilities)
> - `LimitNOFILE`, `LimitNPROC`
> - `PrivateTmp=true`
> - `PrivateDevices=true`
>
> **Optional (advanced hardening):**
> - `PrivateNetwork=true` (only when network is not needed)
> - `PrivateUsers=true`
> - `MemoryDenyWriteExecute=true`

### 12.8 Application Port Allocation

**Rules:**
1. Prioritize selecting ports within the recommended range **8000-19999** (12,000 ports total, greatly reducing conflict probability)
2. If the recommended range ports are occupied, **49152-65535 (dynamic port range)** can be used as an alternative.
3. Check commonly used ports to avoid conflicts before selection; make ports configurable via environment variables
4. Document port usage in README.md

**Port Range Description:**
- **8000-19999**: The recommended port range for TOS 7 applications, avoiding system core service ports (such as 22/80/443/8181), with ample capacity to meet the port needs of the vast majority of applications
- **49152-65535**: IANA-defined dynamic/private port range, suitable for temporary or backup scenarios

**Common Port Reference (Avoid Using):**

| Port | Application |
|---|---|
| 22 | SSH |
| 80 | TOS Web (HTTP) |
| 443 | TOS Web (HTTPS) |
| 445 | SMB |
| 3306 | MySQL |
| 5050 | TOS Daemon |
| 5432 | PostgreSQL |
| 6379 | Redis |
| 8096 | Jellyfin |
| 8181 | TOS Nginx |
| 8443 | TOS HTTPS |
| 9000 | Portainer |
| 9090 | Prometheus |

---

### 12.9 Runtime Filesystem Layout

> **Scope:** Section [8.2](08_Deb_Development.md#82-general-directory-structure) defines the paths used inside a Deb payload, and Section 12.1 and Chapter 10 define where those paths end up on TNAS. The path your application uses is `/usr/local/<appid>/`; the platform resolves it onto the user-selected data volume at `/Volume<N>/@apps/<appid>/`. The platform owns that mapping; developers must not assume that two independent copies exist. This section documents the runtime paths that developers can rely on and clearly marks optional paths.

#### 12.9.1 Lifecycle View: From Installation to Runtime

The exact footprint depends on the application subtype and its service configuration. `[Required]` means required by the TOS application contract, `[Conditional]` means it exists only when the corresponding feature or systemd directive is used, and `[Platform]` means its implementation path is managed by TOS and must not be hardcoded.

| Stage | Trigger | Paths Created / Modified | Description |
|---|---|---|---|
| Before Install | lifecycle script, when provided | Dedicated user and application-owned directories `[Conditional]` | A directory exists only if the platform or a lifecycle script explicitly creates it |
| Install | App Center / package extraction | `/usr/local/<appid>/` `[Platform]` — the platform resolves it onto the user-selected volume | Deploy static files; mapping is platform-managed |
| After Install | lifecycle script / App Center | Permissions, service registration, WebUI extraction, shared folders `[Conditional, Deb applications]` | `ter_share_add` is required only when a Deb application needs a user-visible shared folder |
| Start | service start | journal entries `[Platform]`; `/var/api/<appid>.sock` for iframe apps `[Required]`; file logs, `/run/<appid>/`, private temp `[Conditional]` | The application or systemd creates only the paths configured for that service |
| Running | continuous | `/usr/local/<appid>/data/` and `/usr/local/<appid>/logs/` `[Conditional]`; application-specific state paths `[Conditional]` | Store writable runtime data on the data disk |
| Stop | service stop | Application-owned socket/PID cleanup; systemd-managed runtime directories `[Conditional]` | Remove stale sockets and PID files before the next start |
| Upgrade | package upgrade | Existing runtime and user data retained | Migrate formats without deleting user business data |
| Uninstall / Purge | App Center / dpkg | Package files plus paths explicitly handled by the platform or `postrm` | Do not claim cleanup for a path unless the responsible script or platform contract defines it |
| Shared Data Retention | upgrade / uninstall | `/Volume<N>/<appid>/` (Deb applications) and `/Volume<N>/DockerAppData/<appid>/` (Docker applications) retained | User business data must never be deleted automatically |

#### 12.9.2 Deb Application Runtime Layout (Full Tree)

The following tree separates the TNAS application contract from optional implementation paths:

```
/usr/local/<appid>/                     # [Required] application directory, as your app sees it
├── config.ini                       # Static application metadata
├── <appid>.lang                     # Static language file
├── bin/                             # Static executables
├── init.d/                          # Static service unit source
├── images/                          # Static icons
├── nginx/                           # Static proxy configuration (external-open only)
├── webui.bz2                        # Static frontend archive (WebUI only)
├── data/                            # Writable runtime data, cache, and state
└── logs/                            # Writable application log files

# Physical mapping (for reference only — never write these into your application):
/Volume<N>/@apps/<appid>/                # [Platform] the directory above, resolved onto the volume the user chose
/Volume<N>/<appid>/                      # [Conditional, Deb applications] shared user-data folder, accessible via SMB/NFS

# Conditional host paths; do not assume they exist for every application:
/var/api/<appid>.sock                    # iframe Unix socket; application creates/removes it
/var/lib/<appid>/                        # legacy compatibility path (not required); use /usr/local/<appid>/data/
/var/log/<appid>/                        # legacy compatibility path (not required); use /usr/local/<appid>/logs/
/run/<appid>/                            # only with RuntimeDirectory=<appid>
service-private /tmp                     # only with PrivateTmp=true; physical host path is internal
systemd journal                          # storage path is platform-managed; use journalctl
```

> **Path mapping:** `/usr/local/<appid>/` is the path your application uses everywhere — code, service unit, lifecycle scripts, configuration. On TNAS the App Center resolves that directory onto the user-selected data volume, where it physically lives at `/Volume<N>/@apps/<appid>/`. The mapping is platform-managed: it is one directory, not two copies. Do not hardcode the physical form — a developer cannot know which volume a user will choose.

#### 12.9.3 Per-Path Reference (Deb Applications)

| Path | Requirement | Created By | Contents | Cleanup Responsibility |
|---|---|---|---|---|
| `/usr/local/<appid>/` | Required | App Center | Static application files and app-owned runtime directories | App Center / package lifecycle |
| `/usr/local/<appid>/data/` | Required when the app writes runtime state | Application or lifecycle script | Caches, temporary data, databases, state | Application/package policy; preserve across upgrade |
| `/usr/local/<appid>/logs/` | Required for file logging | Application or lifecycle script | Rotated application logs | Application/logrotate/package policy |
| `/Volume<N>/<appid>/` | Conditional (Deb applications): user-visible business data | `ter_share_add` or declared `share_folders` | Persistent user data (SMB/NFS) | **Retain across upgrade and uninstall** |
| `/var/api/<appid>.sock` | Required for iframe apps | Application on start | Platform proxy Unix socket, mode `0660` | Application removes stale socket before bind; package removes residue when appropriate |
| `/var/lib/<appid>/` | Legacy compatibility path — **not required**; use `/usr/local/<appid>/data/` instead | Lifecycle script/application | Application-specific state | Only delete if the same package owns and documents it |
| `/var/log/<appid>/` | Legacy compatibility path — **not required**; use `/usr/local/<appid>/logs/` instead | Lifecycle script/application | Application-specific file logs | Rotate and remove only if package-owned |
| `/run/<appid>/` | Conditional on `RuntimeDirectory=<appid>` | systemd | PID files and runtime sockets | systemd removes it when the unit stops |
| Service-private `/tmp` | Conditional on `PrivateTmp=true` | systemd | Isolated temporary files | systemd manages the namespace; do not hardcode its host path |
| systemd journal | Always available to the service | journald | stdout/stderr | Platform-managed; access with `journalctl -u <system_id>` |

> **Service registration:** `systemctl enable` normally creates an enablement link under the selected target (for example, `multi-user.target.wants/`); it does not guarantee `/etc/systemd/system/<system_id>.service`. The platform or lifecycle script must first register the unit from the application directory. Do not hardcode systemd's internal link location as application data.

#### 12.9.4 Docker Application Runtime Layout

Developers control persistent Docker data through bind mounts. Docker Engine also maintains image layers, writable layers, metadata, and logs in its own host-side data root; that location is platform-managed and must not be treated as an application filesystem API.

```
# Developer-controlled host paths:
/Volume<N>/DockerAppData/<appid>/
├── config/                         # bind mount -> /config (persistent)
└── data/                           # bind mount -> /data (persistent)
# Docker applications do not use TNAS shared folders — all persistent data lives above.

# Inside the container:
/config, /data                      # persistent only when backed by the mounts above
/tmp, /run                          # tmpfs only when declared in docker-compose.yml
all other writable-layer changes   # ephemeral; lost when the container is removed

# Host-side Docker Engine storage:
Docker data root                    # platform-managed; location varies by installation/storage driver
container logs                      # access with `docker logs`; do not read internal files directly
```

> **Rule:** data kept only inside the container filesystem is lost on container removal. All persistent data **must** be mounted to a host path; the platform places it under the application data root `/Volume<N>/DockerAppData/<appid>/`. Docker applications do not use TNAS shared folders. Use one of the supported host-side forms in Chapter 9 §9.3 — never `/Volume*/…`.

#### 12.9.5 Key Runtime Guidelines

1. **Do not write outside your own application directory.** `/etc`, `/boot`, and `/usr` locations other than `/usr/local/<appid>/` are protected by `ProtectSystem=strict`, and requesting write access to them is a permission red line (Section 10.9). Use `/usr/local/<appid>/data/` for writable configuration and state.
2. **`PrivateTmp=true` is conditional.** When enabled, the service receives an isolated `/tmp`; its physical host path is an implementation detail. Use an application-owned data path when files must survive restart or be shared across services.
3. **`RuntimeDirectory` is conditional.** `/run/<appid>/` exists only when the unit declares `RuntimeDirectory=<appid>` (or the application creates an equivalent path). Do not list it as an unconditional runtime artifact.
4. **Clean the socket before start.** iframe applications **must** run `rm -f /var/api/<appid>.sock` before binding; a stale socket from a previous run causes startup failure (see Section 13.4).
5. **Rotate logs.** Configure logrotate for file-based logs (daily, keep 30, `copytruncate`) or rely on systemd journal (`journalctl -u <system_id>`) / the configured Docker logging driver.
6. **Cleanup must match ownership.** `dpkg --remove` removes package-owned files; `dpkg --purge` additionally runs purge-specific cleanup. A path is deleted only when dpkg, App Center, or the package's `postrm` explicitly owns that cleanup. Do not promise deletion of platform or user paths without such a contract.
7. **Never delete user data on upgrade or uninstall.** Preserve `/Volume<N>/<appid>/` (Deb applications) and `/Volume<N>/DockerAppData/<appid>/` (Docker applications). Preserve application state needed for upgrade, and regenerate only explicitly documented caches.
8. **Document your runtime footprint.** In your README, declare every path your app creates or writes, the component that creates it, its retention policy, ports, and shared folders.

#### 12.9.6 Application-Declared Runtime File Manifest (Required)

Sections 12.9.1–12.9.5 describe paths that TOS, systemd, or App Center may create around an application. This section covers something different and **mandatory for every submission**: the application itself must declare, in its own README, every file or directory it creates while running. An application must never write to arbitrary, undocumented paths at runtime.

**Why this is required:**
- Prevents applications from scattering undocumented files under `/tmp`, the data directory, or elsewhere
- Gives reviewers and users a clear, verifiable picture of disk usage, log growth, and cleanup behavior
- Makes uninstall/purge cleanup safe — a script must only delete paths that are documented and owned by the package

**Required manifest table** (include in your application's README.md; replace every row with your application's actual paths):

| Path (relative to `/usr/local/<appid>/data/` unless noted) | Purpose | Format | Created When | Growth Bound / Rotation | Lifecycle |
|---|---|---|---|---|---|
| `config/runtime.json` | Resolved runtime configuration merged from user settings | JSON | On first start; rewritten on config change | < 1 MB | Persistent — survives restart and upgrade |
| `cache/thumbnails/` | Generated thumbnail cache | Image files | On demand | Capped at 500 MB, LRU eviction | Regenerable — safe to delete |
| `tmp/<pid>-*.part` | In-progress download/transcode temp file | Binary | On job start | Removed when job completes or on next start | Temporary — cleaned automatically |
| `logs/app.log` | Application log | Structured text | On start | Daily rotation, keep 30 days | Persistent, rotated |
| `/var/api/<appid>.sock` | Platform proxy socket | Unix socket | On start | N/A | Removed before each start |

**Rules for `/tmp`:**

1. **Do not write directly to the shared system `/tmp`.** A path shared with other host processes cannot be audited or safely cleaned up by your `postrm`.
2. Use one of two application-owned alternatives instead:
   - `PrivateTmp=true` in the systemd unit — the service gets an isolated `/tmp` that systemd wipes automatically on stop (Section 12.9.5 #2); use it for short-lived temp files that do not need to survive a restart.
   - `/usr/local/<appid>/data/tmp/` — an application-owned subdirectory on the data disk, for temp files that must survive a process restart (e.g., resumable downloads) or be inspected for debugging.
3. **Clean up on startup.** Remove temp files left behind by a previous crash (for example `rm -f /usr/local/<appid>/data/tmp/*.part`) before creating new ones.
4. **Bound temp file growth.** Document a maximum size or count for every temp path and enforce it in code; unbounded temp accumulation is not acceptable.

**Rules for runtime-generated configuration files:**

1. Runtime-generated or runtime-merged configuration (resolved settings, generated tokens/certificates, etc.) must live under `/usr/local/<appid>/data/`, never inside the static package tree — files there can be overwritten or removed on upgrade.
2. Never write generated configuration under `/etc` (Section 12.9.5 #1).
3. Configuration containing secrets (tokens, passwords) must be `600`, owned by `<appid>:<appid>`.

**Rules for log files:**

1. Log files must live under `/usr/local/<appid>/logs/` (or the systemd journal) and appear in the manifest table with their rotation policy (Section 12.3).
2. Do not write logs into `/tmp` — they are silently lost whenever `PrivateTmp` recycles its namespace.

#### 12.9.7 Runtime Footprint Checklist (Self-Review)

Before submission, verify:

- [ ] All static files are declared in the package structure (Section 8.2)
- [ ] Every runtime path names its creator: platform, lifecycle script, systemd, or application
- [ ] Lifecycle scripts create only the optional directories the application actually uses and assign the dedicated user
- [ ] The service unit is registered by the platform or lifecycle script before `systemctl enable/start`; no fixed `/etc/systemd/system/<system_id>.service` path is assumed
- [ ] iframe services clean stale `/var/api/<appid>.sock` before binding
- [ ] `/run/<appid>/` is documented only when `RuntimeDirectory=<appid>` is configured
- [ ] Service-private `/tmp` is documented only when `PrivateTmp=true` is configured
- [ ] The application's own runtime file manifest (Section 12.9.6) is documented in README, listing every path it creates
- [ ] The application never writes temp files directly to the shared system `/tmp`; it uses `PrivateTmp` or an app-owned `data/tmp/` directory, and cleans up stale temp files on start
- [ ] Runtime-generated configuration lives under `data/`, never under `/etc` or the static package tree
- [ ] File logs are written under `/usr/local/<appid>/logs/` (or a documented compatibility path) and rotated
- [ ] `postrm` deletes only package-owned paths explicitly created by this application
- [ ] Shared folders (`/Volume<N>/<appid>/`, Deb applications) are **never** deleted by scripts; cleanup code checks whether a path is a symlink (e.g., `data/` linked per Section 12.2) before recursive delete
- [ ] Docker persistent data is mounted through volume mounts (the platform resolves them to `/Volume<N>/DockerAppData/<appid>/`); Docker Engine internal paths are not hardcoded, and the package declares no shared folder
- [ ] README declares paths, creators, permissions, retention, ports, and shared folders


← [Previous: Package Signing](11_Package_Signing.md) &nbsp;&nbsp;|&nbsp;&nbsp; [Next: Local Testing & Debugging](13_Local_Testing.md) → &nbsp;&nbsp;|&nbsp;&nbsp; [📖 Back to Contents](../README.md)
