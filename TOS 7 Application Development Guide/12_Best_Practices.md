
# 12. Best Practices

### 12.1 Application Directory Layout

Follow a consistent directory layout to ensure maintainability and compatibility. All non-embedded applications (both official and third-party) are installed on **storage volumes** at `/Volume*/@apps/<appid>/`.

**Standard Directory Layout:**

```
/Volume*/@apps/<appid>/
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

> **Note:** `*` in `/Volume*/` represents the volume number (e.g., Volume1, Volume2) chosen by the user during installation.

**Data Storage Recommendations:**
- **Runtime data** (`/Volume*/@apps/<appid>/data/`) — Application-generated caches, temporary files, and runtime state. This data can be safely regenerated.
- **Logs** (`/Volume*/@apps/<appid>/logs/`) — Application log files. Ensure log rotation is configured.
- **User business data** — Must be stored in shared folders under `/Volume*/` (e.g., `/Volume*/<appid>/`) for user access via SMB/NFS.

### 12.2 Data Persistence

**Understanding Data Types:**

| Data Type | Path | Description |
|---|---|---|
| **Runtime Data** | `/Volume*/@apps/<appid>/data/` | Caches, temporary files, runtime state (can be regenerated) |
| **User Data** | `/Volume*/<appid>/` (shared folder) | Persistent business data (must survive app upgrades) |

**Deb Applications:**

1. **Runtime data** is stored in `/Volume*/@apps/<appid>/data/`
2. **User data** must be stored in a shared folder created by the application:
   ```bash
   # In postinst — create a shared folder for user data
   ter_share_add -name <appid> -owner <appid>
   ```
3. To maintain compatibility, the application can create symbolic links:
   ```bash
   ln -s /Volume*/<appid> /Volume*/@apps/<appid>/data
   ```
4. The shared folder `/Volume*/<appid>/` is accessible to users via SMB/NFS

**Docker Applications:**

1. Mount configuration and runtime data to `/Volume*/DockerAppData/<appid>/`:
   ```yaml
   Volumes:
     - /Volume*/DockerAppData/<appid>/config:/config
     - /Volume*/DockerAppData/<appid>/cache:/cache
   ```
2. User data must be stored in a shared folder:
   ```yaml
   Volumes:
     - /Volume*/<appid>:/data
   ```
3. Storing data in the container filesystem is prohibited
4. Use separate volumes for configuration and data to support independent backups

> **Note:** `*` in `/Volume*/` represents the volume number (e.g., Volume1, Volume2) chosen by the user during installation.
> - Runtime data can be safely deleted without losing user business data
> - User data (shared folder) must be backed up before app upgrades

### 12.3 Logging

**Deb Applications:**
```bash
# Use systemd journal (recommended)
# All stdout/stderr from the service is automatically captured
# View logs: journalctl -u <appid>

# Or write to file
exec >> /Volume*/@apps/<appid>/logs/app.log 2>&1
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
/Volume*/@apps/<appid>/logs/*.log {
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
       /Volume*/@apps/<appid>/bin/migrate --from "$2"
   fi
   ```
2. Never delete user data during upgrades
3. Back up before modifying configuration formats
4. Migration logic should be reversible to support rollback
5. **Users are advised to store data within `/Volume*/@apps/<appid>/data/` or within `/Volume*/`** to ensure data is not lost after upgrades

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
ReadWritePaths=/Volume*/@apps/<appid>/data /Volume*/@apps/<appid>/logs

> **Note:** Third-party applications must not write application configuration under `/etc`, `/usr`, or `/boot`. Store writable configuration under `/Volume*/@apps/<appid>/data/` (or a dedicated mounted data directory) and list only those application-owned paths in `ReadWritePaths`.

# Network namespace (optional)
# PrivateNetwork=true  # Only when network is not needed

# User namespace
# PrivateUsers=true
```

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

> **Scope:** Section [8.2](08_Deb_Development.md#82-general-directory-structure) defines the logical paths used inside a Deb payload, while Section 12.1 and Chapter 10 define `/Volume*/@apps/<appid>/` as the actual installation location for third-party applications on TNAS. The platform owns the mapping between these views; developers must not assume that two independent copies exist. This section documents the runtime paths that developers can rely on and clearly marks optional paths.

#### 12.9.1 Lifecycle View: From Installation to Runtime

The exact footprint depends on the application subtype and its service configuration. `[Required]` means required by the TOS application contract, `[Conditional]` means it exists only when the corresponding feature or systemd directive is used, and `[Platform]` means its implementation path is managed by TOS and must not be hardcoded.

| Stage | Trigger | Paths Created / Modified | Description |
|---|---|---|---|
| Before Install | lifecycle script, when provided | Dedicated user and application-owned directories `[Conditional]` | A directory exists only if the platform or a lifecycle script explicitly creates it |
| Install | App Center / package extraction | `/Volume*/@apps/<appid>/` `[Platform]`; Deb payload uses logical `/usr/local/<appid>/` paths | Deploy static files; mapping is platform-managed |
| After Install | lifecycle script / App Center | Permissions, service registration, WebUI extraction, shared folders `[Conditional]` | `ter_share_add` is required only when the app needs a user-visible shared folder |
| Start | service start | journal entries `[Platform]`; `/var/api/<appid>.sock` for iframe apps `[Required]`; file logs, `/run/<appid>/`, private temp `[Conditional]` | The application or systemd creates only the paths configured for that service |
| Running | continuous | `/Volume*/@apps/<appid>/data/` and `/Volume*/@apps/<appid>/logs/` `[Conditional]`; application-specific state paths `[Conditional]` | Store writable runtime data on the data disk |
| Stop | service stop | Application-owned socket/PID cleanup; systemd-managed runtime directories `[Conditional]` | Remove stale sockets and PID files before the next start |
| Upgrade | package upgrade | Existing runtime and user data retained | Migrate formats without deleting user business data |
| Uninstall / Purge | App Center / dpkg | Package files plus paths explicitly handled by the platform or `postrm` | Do not claim cleanup for a path unless the responsible script or platform contract defines it |
| Shared Data Retention | upgrade / uninstall | `/Volume*/<appid>/` retained | User business data must never be deleted automatically |

#### 12.9.2 Deb Application Runtime Layout (Full Tree)

The following tree separates the TNAS application contract from optional implementation paths:

```
/Volume*/                                # User-selected data volume
├── @apps/<appid>/                       # [Platform] actual third-party app directory
│   ├── config.ini                       # Static application metadata
│   ├── <appid>.lang                     # Static language file
│   ├── bin/                             # Static executables
│   ├── init.d/                          # Static service unit source
│   ├── images/                          # Static icons
│   ├── nginx/                           # Static proxy configuration (external-open only)
│   ├── webui.bz2                        # Static frontend archive (WebUI only)
│   ├── data/                            # Writable runtime data, cache, and state
│   └── logs/                            # Writable application log files
└── <appid>/                             # [Conditional] shared user-data folder
    └── ...                              # Persistent business data, accessible via SMB/NFS

# Conditional host paths; do not assume they exist for every application:
/var/api/<appid>.sock                    # iframe Unix socket; application creates/removes it
/var/lib/<appid>/                        # compatibility state path, only when explicitly created
/var/log/<appid>/                        # compatibility log path, only when explicitly created
/run/<appid>/                            # only with RuntimeDirectory=<appid>
service-private /tmp                     # only with PrivateTmp=true; physical host path is internal
systemd journal                          # storage path is platform-managed; use journalctl
```

> **Deb payload path:** Chapter 8 and the templates use `/usr/local/<appid>/` as the package-internal logical path. On TNAS, the App Center places third-party applications on `/Volume*/@apps/<appid>/`. The platform mapping is an implementation detail; code and cleanup scripts must follow the platform-provided installation context instead of assuming two separate trees.

#### 12.9.3 Per-Path Reference (Deb Applications)

| Path | Requirement | Created By | Contents | Cleanup Responsibility |
|---|---|---|---|---|
| `/Volume*/@apps/<appid>/` | Required | App Center | Static application files and app-owned runtime directories | App Center / package lifecycle |
| `/Volume*/@apps/<appid>/data/` | Required when the app writes runtime state | Application or lifecycle script | Caches, temporary data, databases, state | Application/package policy; preserve across upgrade |
| `/Volume*/@apps/<appid>/logs/` | Required for file logging | Application or lifecycle script | Rotated application logs | Application/logrotate/package policy |
| `/Volume*/<appid>/` | Conditional: user-visible business data | `ter_share_add` or declared `share_folders` | Persistent user data (SMB/NFS) | **Retain across upgrade and uninstall** |
| `/var/api/<appid>.sock` | Required for iframe apps | Application on start | Platform proxy Unix socket, mode `0660` | Application removes stale socket before bind; package removes residue when appropriate |
| `/var/lib/<appid>/` | Optional compatibility path | Lifecycle script/application | Application-specific state | Only delete if the same package owns and documents it |
| `/var/log/<appid>/` | Optional compatibility path | Lifecycle script/application | Application-specific file logs | Rotate and remove only if package-owned |
| `/run/<appid>/` | Conditional on `RuntimeDirectory=<appid>` | systemd | PID files and runtime sockets | systemd removes it when the unit stops |
| Service-private `/tmp` | Conditional on `PrivateTmp=true` | systemd | Isolated temporary files | systemd manages the namespace; do not hardcode its host path |
| systemd journal | Always available to the service | journald | stdout/stderr | Platform-managed; access with `journalctl -u <system_id>` |

> **Service registration:** `systemctl enable` normally creates an enablement link under the selected target (for example, `multi-user.target.wants/`); it does not guarantee `/etc/systemd/system/<system_id>.service`. The platform or lifecycle script must first register the unit from the application directory. Do not hardcode systemd's internal link location as application data.

#### 12.9.4 Docker Application Runtime Layout

Developers control persistent Docker data through bind mounts. Docker Engine also maintains image layers, writable layers, metadata, and logs in its own host-side data root; that location is platform-managed and must not be treated as an application filesystem API.

```
# Developer-controlled host paths:
/Volume*/DockerAppData/<appid>/
├── config/                         # bind mount -> /config (persistent)
└── data/                           # bind mount -> /data (persistent)
/Volume*/<appid>/                   # optional shared user data -> container mount

# Inside the container:
/config, /data                      # persistent only when backed by the mounts above
/tmp, /run                          # tmpfs only when declared in docker-compose.yml
all other writable-layer changes   # ephemeral; lost when the container is removed

# Host-side Docker Engine storage:
Docker data root                    # platform-managed; location varies by installation/storage driver
container logs                      # access with `docker logs`; do not read internal files directly
```

> **Rule:** data kept only inside the container filesystem is lost on container removal. All persistent data **must** be mounted to `/Volume*/DockerAppData/<appid>/` or `/Volume*/<appid>/`.

#### 12.9.5 Key Runtime Guidelines

1. **Do not write application configuration under `/etc`, `/usr`, or `/boot`.** These system directories are protected by `ProtectSystem=strict`, and requesting write access is a permission red line (Section 10.9). Use `/Volume*/@apps/<appid>/data/` for writable configuration and state.
2. **`PrivateTmp=true` is conditional.** When enabled, the service receives an isolated `/tmp`; its physical host path is an implementation detail. Use an application-owned data path when files must survive restart or be shared across services.
3. **`RuntimeDirectory` is conditional.** `/run/<appid>/` exists only when the unit declares `RuntimeDirectory=<appid>` (or the application creates an equivalent path). Do not list it as an unconditional runtime artifact.
4. **Clean the socket before start.** iframe applications **must** run `rm -f /var/api/<appid>.sock` before binding; a stale socket from a previous run causes startup failure (see Section 13.4).
5. **Rotate logs.** Configure logrotate for file-based logs (daily, keep 30, `copytruncate`) or rely on systemd journal (`journalctl -u <system_id>`) / the configured Docker logging driver.
6. **Cleanup must match ownership.** `dpkg --remove` removes package-owned files; `dpkg --purge` additionally runs purge-specific cleanup. A path is deleted only when dpkg, App Center, or the package's `postrm` explicitly owns that cleanup. Do not promise deletion of platform or user paths without such a contract.
7. **Never delete user data on upgrade or uninstall.** Preserve `/Volume*/<appid>/`. Preserve application state needed for upgrade, and regenerate only explicitly documented caches.
8. **Document your runtime footprint.** In your README, declare every path your app creates or writes, the component that creates it, its retention policy, ports, and shared folders.

#### 12.9.6 Application-Declared Runtime File Manifest (Required)

Sections 12.9.1–12.9.5 describe paths that TOS, systemd, or App Center may create around an application. This section covers something different and **mandatory for every submission**: the application itself must declare, in its own README, every file or directory it creates while running. An application must never write to arbitrary, undocumented paths at runtime.

**Why this is required:**
- Prevents applications from scattering undocumented files under `/tmp`, the data directory, or elsewhere
- Gives reviewers and users a clear, verifiable picture of disk usage, log growth, and cleanup behavior
- Makes uninstall/purge cleanup safe — a script must only delete paths that are documented and owned by the package

**Required manifest table** (include in your application's README.md; replace every row with your application's actual paths):

| Path (relative to `/Volume*/@apps/<appid>/data/` unless noted) | Purpose | Format | Created When | Growth Bound / Rotation | Lifecycle |
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
   - `/Volume*/@apps/<appid>/data/tmp/` — an application-owned subdirectory on the data disk, for temp files that must survive a process restart (e.g., resumable downloads) or be inspected for debugging.
3. **Clean up on startup.** Remove temp files left behind by a previous crash (for example `rm -f /Volume*/@apps/<appid>/data/tmp/*.part`) before creating new ones.
4. **Bound temp file growth.** Document a maximum size or count for every temp path and enforce it in code; unbounded temp accumulation is not acceptable.

**Rules for runtime-generated configuration files:**

1. Runtime-generated or runtime-merged configuration (resolved settings, generated tokens/certificates, etc.) must live under `/Volume*/@apps/<appid>/data/`, never inside the static package tree — files there can be overwritten or removed on upgrade.
2. Never write generated configuration under `/etc` (Section 12.9.5 #1).
3. Configuration containing secrets (tokens, passwords) must be `600`, owned by `<appid>:<appid>`.

**Rules for log files:**

1. Log files must live under `/Volume*/@apps/<appid>/logs/` (or the systemd journal) and appear in the manifest table with their rotation policy (Section 12.3).
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
- [ ] File logs are written under `/Volume*/@apps/<appid>/logs/` (or a documented compatibility path) and rotated
- [ ] `postrm` deletes only package-owned paths explicitly created by this application
- [ ] Shared folders (`/Volume*/<appid>/`) are **never** deleted by scripts; cleanup code checks whether a path is a symlink (e.g., `data/` linked per Section 12.2) before recursive delete
- [ ] Docker persistent data is mounted to `/Volume*/DockerAppData/<appid>/` or `/Volume*/<appid>/`; Docker Engine internal paths are not hardcoded
- [ ] README declares paths, creators, permissions, retention, ports, and shared folders


← [Previous: Package Signing](11_Package_Signing.md) &nbsp;&nbsp;|&nbsp;&nbsp; [Next: Local Testing & Debugging](13_Local_Testing.md) → &nbsp;&nbsp;|&nbsp;&nbsp; [📖 Back to Contents](../README.md)
