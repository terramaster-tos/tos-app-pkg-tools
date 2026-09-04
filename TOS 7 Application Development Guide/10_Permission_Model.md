
# 10. Permission Model

### 10.1 SPC Overview

TOS 7 introduces the **SPC (System Permission Control)** system, which follows the principle of least privilege and governs application system access behavior:

- Applications cannot directly modify system files or obtain root privileges; all permission requests must be submitted through platform APIs
- Developers must clearly specify application permission requirements in the permission declaration. Applications can only obtain corresponding access permissions after platform approval.
- Any behavior that bypasses SPC permission checks is prohibited; such applications will fail review or be delisted.

### 10.2 Overview

TOS7 follows the **Principle of Least Privilege**. Applications can only request the minimum permissions necessary for operation. TOS7 applications interact with the **SPC (System Permission Control)** system. Applications must:
- Declare permission requirements in the permission declaration (Section 10.7)
- Not bypass SPC permission checks
- Use platform APIs for permission requests instead of directly modifying system files

The platform provides a structured permission model for both Deb and Docker applications.

### 10.3 User and Group Model

**⚠️ Root permissions for application users are strictly prohibited.** All applications must run as a dedicated non-root user.

**Deb Applications:**

| Scenario | User | Description | Configuration Requirement |
|---|---|---|---|
| Dedicated User | `<appid>` | Must be used. The platform automatically creates this user during installation with non‑root privileges and assigns a UID. | **Mandatory** |

> **Mandatory Requirement:** All Deb applications must set the `user` field in `config.ini` to a dedicated user name (e.g., `<appid>`). The platform will create the corresponding system user during installation, and the application will run with that user's privileges. Running as root is strictly prohibited.
>
> **⚠️ Important:** Developers MUST NOT manually create the user in lifecycle scripts (e.g., `preinst`). The developer's only responsibility regarding the user is to **set the user name** in `config.ini` and ensure it matches the `User=` field in the systemd service file.

**Docker Applications:**

| Scenario | User | Description |
|---|---|---|
| Non-root | `UID:GID` (e.g., `1000:1000`) | **Must be used.** Specified via the `user` field in compose. |

### 10.4 File System Permissions

**Standard Directory Permissions for Deb Applications:**

| Path | Owner | Permissions | Description |
|---|---|---|---|
| `/Volume*/@apps/<appid>/` | `<appid>:<appid>` | `755` | Application directory (service read-only) |
| `/Volume*/@apps/<appid>/bin/` | `<appid>:<appid>` | `755` | Executables |
| `/Volume*/@apps/<appid>/config/` | `<appid>:<appid>` | `750` | Configuration files (read-only for service) |
| `/Volume*/@apps/<appid>/site/` | `<appid>:<appid>` | `755` | Web UI files |
| `/Volume*/@apps/<appid>/data/` | `<appid>:<appid>` | `750` | Runtime data (read-write) |
| `/Volume*/@apps/<appid>/logs/` | `<appid>:<appid>` | `750` | Application logs (read-write) |

> **Note 1:** `*` in `/Volume*/` represents the volume number (e.g., Volume1, Volume2) chosen by the user during installation.

> **Note 2:** Application binaries and configuration should be read-only for the service user. Only data and log directories should be writable.

> **Note 3: Data Types**
> - **Runtime data** (`/Volume*/@apps/<appid>/data/`) — Application-generated caches, temporary files, and runtime state. This data is managed by the application and can be safely regenerated.
> - **User data** (shared folder created via `ter_share_add`) — Persistent business data (documents, photos, databases). This data must be stored in a shared folder under `/Volume*/` to allow user access via SMB/NFS.

### 10.5 Network Permissions

| Permission | Deb Applications | Docker Applications | Description |
|---|---|---|---|
| Bind Port | Bind specified port in service config | Map port in compose | Must not conflict with system ports |
| Access Local Services | Allowed by default | Use `network_mode: host` or explicit linking | Minimize network exposure |
| Outbound Connections | Allowed | Allowed | Outbound is unrestricted |

### 10.6 Shared Folder Access

TNAS shared folders are the primary data access mechanism. Applications requiring access to user data must:

1. **Create a shared folder** via `ter_share_add`:
```bash
ter_share_add -name <appid>-data -owner <appid>
```

2. **Or request access to existing shared folders** by joining the `allusers` group:
```bash
usermod -aG allusers <appid>
```

3. **Docker applications** mount shared folders via volumes:
```yaml
Volumes:
  - /Volume*/<shared_folder>:/data:rw    # Read-write access
  - /Volume*/<shared_folder>:/media:ro   # Read-only access
```

> **Important:** Applications must not directly modify shared folder permissions. Use the TOS shared folder management API or let users manually configure access permissions.


### 10.6.1 Permission Request Process

When an application requires access to shared folders:

1. **Dedicated Application Folder** (Recommended):
   - Create via `ter_share_add` in postinst
   - Application has full read-write permissions
   - No user authorization required

2. **User Shared Folders** (Authorization Required):
   - Application requests `allusers` group membership
   - User authorizes folder access through TOS shared folder settings
   - Application declares read-only or read-write requirements in the permission declaration

3. **Permission Format**:
   ```yaml
   # Docker volumes
   - /Volume*/<shared_folder>:/data:rw   # Read-write access
   - /Volume*/<shared_folder>:/media:ro  # Read-only access
   ```

### 10.7 System Resource Limits

**Application Installation Path**

Third-party applications are completely installed on **storage volumes** (data disks) at `/Volume*/@apps/<appid>/`, **not on the system disk (/)**.

- `*` represents the volume number (e.g., Volume1, Volume2, etc.) chosen by the user during installation.
- **All application files** — including binaries, configuration files, logs, scripts, and web UI files — are stored under `/Volume*/@apps/<appid>/`.
- Only a lightweight **registration/entry record** (used by TOS to recognize installed applications) resides on the system disk. This record occupies negligible space and does not pose any capacity concern.
- Only system-built-in applications reside on the system disk (`/usr/local/system_app_data/`).

> ✅ **For third-party developers:** Since your entire application (including program files, configs, and logs) is installed on the data disk, **system disk capacity is not a concern for your app**. All business data should also be stored on data disks (`/Volume*/`), which have no capacity limits.

**Default Resource Quotas by Application Type:**

| Application Type | CPU Limit | Memory Limit | Examples |
|---|---|---|---|
| Media Server | 200% (2 cores) | 2048M | Jellyfin, Plex, Emby |
| Download Manager | 100% (1 core) | 512M | Aria2, qBittorrent |
| Utilities | 50% | 256M | File Manager, Text Editor |
| Web Service | 100% (1 core) | 512M | CMS, Blog, Wiki |
| Database | 200% (2 cores) | 2048M | MySQL, PostgreSQL, Redis |
| Security | 50% | 256M | Firewall, Antivirus |

The above are platform defaults. Developers may request higher limits in the permission declaration with reasonable justification.

**Deb Applications (via systemd):**
```ini
[Service]
# Memory limit
MemoryMax=512M
# CPU quota (200% = 2 cores)
CPUQuota=200%
# File descriptor limit
LimitNOFILE=65536
# Process count limit
LimitNPROC=256
```

**Docker Applications (via compose):**
```yaml
services:
  myapp:
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 512M
        reservations:
          cpus: '0.5'
          memory: 128M
```

### 10.8 Permission Declaration

> 📝 **Note:** The following table is an **example** showing how to document your application's permission requirements. Replace the values (port numbers, file paths, usernames) with those actually used by your application.

For transparency, applications should document their permission requirements in README.md:

| Permission | Justification |
|---|---|
| Network: Port `<your-port>` | Web UI access |
| File System: `<your-data-path>` | Runtime data storage |
| User: `<your-appid>` (system user) | Isolated service execution |
| Shared Folder: None | No user data access required |

> **Runtime file manifest:** This table declares *permissions*. You must additionally declare every file/directory your application *creates at runtime* (temp files, generated config, logs, caches) in the required manifest — see [Section 12.9.6](12_Best_Practices.md#1296-application-declared-runtime-file-manifest-required).


### 10.9 Permission Red Lines (Automatic Rejection)

The following permission requests will result in **automatic rejection**:

| Violation | Description |
|---|---|
| Root Execution | Requesting `root` user to run the application (including setting `User=root` in systemd service files, and not specifying the `user` field in Docker, which defaults to running as root) |
| Privileged Mode | Requesting `--privileged` Docker mode |
| System Directory Write | Requesting write access to system directories such as `/etc/`, `/usr/`, `/boot/` |
| Cross-App Data Access | Requesting access to other applications' data directories |
| Unrestricted Network Access | Requesting `network_mode: host` without written reasonable justification (only available to system-level network tools) |
| Excessive Port Exposure | Requesting more ports than functionally required |


← [Previous: Docker Development](09_Docker_Development.md) &nbsp;&nbsp;|&nbsp;&nbsp; [Next: Package Signing](11_Package_Signing.md) → &nbsp;&nbsp;|&nbsp;&nbsp; [📖 Back to Contents](../README.md)


