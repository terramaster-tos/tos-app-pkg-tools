
# 9. Docker Development

### 9.1 Overview

Docker applications run in containers managed by the TOS 7 Docker Engine.

> **Prerequisite:** Docker Engine is not pre-installed in TOS 7. It is provided as an application in the TOS App Center and must be installed and enabled by the user. When users install a Docker-based application, the platform automatically checks for Docker Engine and prompts installation if it is missing or disabled — no additional action is required from the developer.

**Core Requirements:**
- Must provide a `docker-compose.yml` compatible with Compose Spec 3.8+
- Data must be persisted to NAS-accessible directories via volume mounts
- **Privileged mode is strictly prohibited**
- **System reserved ports (22, 80, 443, 445, 3306, 5050, 5432, 6379, 8181, 8443) must not be occupied** — full list: Appendix B of Chapter 20 / §12.8


### 9.2 Package Structure (`.tar.gz` Archive)

The Docker application is submitted as a `.tar.gz` archive. The archive must contain exactly the following files at the root level:

```
<appid>.tar.gz
├── config.ini
├── <appid>.lang
├── <appid>.svg
└── docker-compose.yml
```

**File descriptions:**

| File | Required | Description |
|------|----------|-------------|
| `config.ini` | ✅ Yes | Application metadata configuration |
| `<appid>.lang` | ✅ Yes | Multilingual file — the documented baseline is the 26-language set defined in 8.5.1 (supersets allowed; fewer than 26 languages is only a reminder and never a rejection reason). In every language section included, `name` / `auth` / `descript` must be non-empty; untranslated content is filled with English (see 8.5.3) |
| `<appid>.svg` | ✅ Yes | Application icon (SVG format) |
| `docker-compose.yml` | ✅ Yes | Container orchestration configuration |

> **Important Notes:**
> - The `config.ini.icon` field must point to `/images/icons/<appid>.svg`. The platform handles the mapping during installation.
> - The package name follows the recommended format defined in [Section 4.2.4](04_Package_Specification.md#424-release-asset-naming-specification): `<appid>.tar.gz`
> - For Docker applications with a UI, the `docker-compose.yml` must include the `x-app-meta` section (see Section 9.3).
> - For Docker applications without a UI, the `x-app-meta` section is not required.



#### 9.2.1 Docker-specific `config.ini` Fields

**Field ownership:** `config.ini`, `app.lang` and the icon file follow the complete specifications in Chapter 8 — §8.4 (fields), §8.5 (`app.lang`) and §8.6 (icon) — and apply to Docker applications in exactly the same way. This section documents only what differs for Docker applications; do not treat §8.4.2 as a Deb-only list of fields to be redefined here.

**1) `depend` — required for Docker applications**

| Field | Type | Required | Description | Detailed Description |
|---|---|---|---|---|
| `depend` | []string | ✅ Yes | Dependency application list | Must contain `DockerEngine`. Additional App IDs of other App Center applications that this application depends on may be appended. Dependencies are resolved by App ID and installed in list order; circular dependencies are prohibited. Example: `["DockerEngine", "<app_id>"]`. |

**Rules:**
- `depend` **must contain `DockerEngine`** — a Docker application cannot run without the container runtime, and the platform uses this list to install and start it first.
- Additional elements are **App IDs** of other applications published in the same App Center; do not put image names, container names or free-text descriptions in the list.
- Dependencies are installed **in list order**; a circular dependency between applications is prohibited and will be rejected.
- If a declared dependency cannot be installed, the installation of this application is aborted with an explicit error rather than started in a degraded state.
- **Deb applications never use this field** — they declare dependencies in the `Depends` field of `DEBIAN/control` (Chapter 5 · §5.2, §8.13). `depend` exists for Docker applications only.

**2) Common fields shared with §8.4.2:** `id`, `icon`, `publisher`, `exec`, `version`, `help`, `category`, `platform`, `application_type`, `user` are required for Docker as well, while `low_version` stays optional; all of them keep the meaning, type and required status defined in §8.4.2; for a Docker application `application_type` must be `"docker"`. In addition, `compose_project` is **required** for a Docker application and must be left empty for a Deb application (§8.4.2). UI-related fields follow §9.3 (`x-app-meta`) instead of the Deb `path` / `open_path` / `type` fields.

**3) Minimal example:**

```json
{
  "id": "<appid>",
  "icon": "/images/icons/<appid>.svg",
  "publisher": "publisher name",
  "exec": true,
  "version": "<app_version>",
  "low_version": "<low_version>",
  "category": ["Utilities"],
  "platform": "x86_64",
  "user": "<app_user>",
  "application_type": "docker",
  "depend": ["DockerEngine"]
}
```

> The icon path, id and version values must match the archive contents described in §9.2.

### 9.3 docker-compose.yml Specification

```yaml
version: "3.8"
services:
  <appid>:
    image: <registry>/<image>:<tag>  
    container_name: <container_name>
    restart: unless-stopped
    ports:
      - "<host_port>:<container_port>"
    volumes:
      - ./data:/data
    environment:
      - TZ=Asia/Shanghai   # optional — the container reads the host timezone by default
    user: "1000:1000"

x-app-meta:
  web:
    port: <host_port>
    protocol: http
```

> **Note:** Compose files are static configurations with no dynamic parameter matching.

> **Named volumes:** a named volume is *referenced* in the service (`<appid>-data:/data`) but must be *declared* under the top-level `volumes:` key — a service-level reference alone is not enough:
>
> ```yaml
> services:
>   <appid>:
>     volumes:
>       - <appid>-data:/data
>
> volumes:
>   <appid>-data:
>     driver: local
> ```
>
> ⛔ **A named volume referenced in a service (`name:/container/path`) MUST also be declared under the top-level `volumes:` key. Missing the declaration makes Compose reject the whole project before pulling any image (`service "x" refers to undefined volume "y"`), and App Center installation fails immediately.** Bind mounts (`./data:/data`, `/data:/data`) need no top-level declaration — see Rule 4 below.

**Rules:**

1. **Version**: Must be compatible with Compose Spec 3.8 or higher
2. **x-app-meta**: For Docker applications with a UI, the `x-app-meta` tag must be a top‑level key in the `docker-compose.yml` file, containing `web.port` (Web UI port) and `web.protocol` (request protocol, typically `http`).
   ```yaml
   x-app-meta:
     web:
       port: 8080
       protocol: http
   ```
3. **Comments**: `#` comments are supported in the `docker-compose.yml` file (a comment must be preceded by a space, e.g., `port: 8080 # Web UI port`). However, **comments must not appear inside a `volumes` or `ports` sequence** — keep the items of those sequences contiguous and place any comment above the key or outside the sequence (see the note below the example).
   ```yaml
   volumes:
     - ./config:/config
     - ./data:/data

   ports:
     - "8080:8080"
   ```
   > **Note (pending R&D reproduction confirmation):** our own testing shows that with no comment inside the `volumes` / `ports` sequence, the owner of the mounted host directory is `1000:0` as expected; with a comment inside the sequence, the platform's compose parsing resolves the host-side bind path incorrectly and the owner becomes `0:0`. Until R&D reproduces and confirms this, treat "no comments inside the `volumes` / `ports` sequence" as the required practice. 
4. **Data Persistence**: All data directories must be persisted through a volume mount — either a **bind mount** (recommended) or a **named volume**. Data stored only inside the container, with no mount at all, will be lost when the container is removed.

   **Host-side volume path syntax (supported forms):** The platform does **not** expand `/Volume*/`. Write the host side of every bind mount in one of the forms below; the data is placed under the application data root `/Volume<N>/DockerAppData/<appid>/`.

   | Compose syntax | Type | Host-side meaning | Data location |
   |---|---|---|---|
   | `./data:/data` | Bind Mount | Host relative path | `/Volume1/DockerAppData/<appid>/data` |
   | `/data:/data` | Bind Mount | Host absolute path | `/Volume1/DockerAppData/<appid>/data` |
   | `/Volume1/app/data:/data` | Bind Mount | Host absolute path | `/Volume1/DockerAppData/<appid>/data` |
   | `app-data:/data` | Named Volume | Docker-managed volume; **must also be declared under the top-level `volumes:` key** | Docker-managed: `/var/lib/docker/volumes/<project>_<name>/` — **not** under `/Volume<N>/DockerAppData/<appid>/` |
   | `/data` | Anonymous Volume | No source; Docker creates it | Docker-managed, not under the application data root; not visible to the user and not cleaned up by "delete data" |
   | `type: tmpfs` | tmpfs | In-memory filesystem | In memory only — lost when the container is recreated |

   ⛔ **Never write `/Volume*/…` in a compose file, a systemd unit, a lifecycle script, or any other machine-read configuration.** The platform does not resolve `*`: the literal directory `/Volume*` is created, and your data is written there instead of the application data root.

   **Bind mount vs named volume — where the data ends up, and whether it can be cleaned up:**
   - A **bind mount** (`./data:/data`, `/data:/data`, `/Volume1/app/data:/data`) is resolved onto the application data root `/Volume<N>/DockerAppData/<appid>/…`, so the data is visible in the file manager and is removed when the user uninstalls the app and explicitly chooses to delete data (see Section 9.6.4). **This is the recommended form.**
   - A **named volume** (`<appid>-data:/data`) is supported, but it must be declared under the top-level `volumes:` key (see the note under the §9.3 template), and its data lives in Docker's own volume store (`/var/lib/docker/volumes/<project>_<name>/`) — **not** under `/Volume<N>/DockerAppData/<appid>/`. With the default `clean=false`, uninstalling keeps the volume (`compose down` does not remove volumes by default); with `clean=true`, the platform additionally calls `cleanComposeVolumes` (Section 9.6.4). Either way the data is not under the application data root and is not reachable from the App Center file manager, so **prefer a bind mount** unless the image explicitly requires a named volume.
   - An **anonymous volume** (`/data`) and **tmpfs** give you no control over the data location either; use them only for disposable data.

   **Relative-path base:** in `./data:/data`, the `.` is resolved against the directory that contains the `docker-compose.yml` file — the standard Compose behaviour, where relative host paths are resolved against the Compose project directory. The platform then places the resolved directory under the application data root, so the same compose file works no matter which volume the user picks at installation.

5. **Port Mapping**:
   - Disabled ports: 22, 80, 443, 445, 3306, 5050, 5432, 6379, 8181, 8443 (system services — full list: Appendix B of Chapter 20 / §12.8)
   - Recommended range: 8000-19999
   - Verify that the selected port is not in use on the TNAS before submission
6. **Privileged Mode**: **Strictly prohibited**. The `user` field must be used to specify UID/GID.
7. **Timezone**: The container reads the host system timezone — explicitly setting `TZ` is **not required** for Docker applications (`TZ=Asia/Shanghai` in the examples above is illustrative and optional). If you do set a timezone, keep timestamps consistent to avoid data corruption in time-sensitive applications.
8. **Container Name**: You are free to set a custom name, provided it is globally unique on the Docker daemon. Duplicate names will result in runtime errors.
9. **Restart Policy**: Use `unless-stopped` for normal services
10. **Network Mode**: `network_mode: host` is **strictly prohibited**, except for system-level network tools. System-level network tools must clearly state the rationale at submission and may only use it after approval. Regular applications are strictly prohibited. Using host network mode breaks container isolation and poses security risks. Use port mapping instead:
   ```yaml
   ports:
     - "8080:8080"
   ```
11. **Shared Folders**: Docker applications do **not** participate in the TNAS shared-folder mechanism. Unlike Deb applications, no shared folder is created for a Docker application, it must not call `ter_share_add` or declare `share_folders`, and shared-folder mount placeholders (`<shared_folder_path>`) must not appear in `docker-compose.yml`. All persistent business data stays inside the container and must be stored through volume mounts, which the platform resolves to the application data root `/Volume<N>/DockerAppData/<appid>/`.

### 9.4 Image and Security Requirements

1. **Image Source (Docker Hub Only)**: **All Docker images must come from Docker Hub. Non-Docker Hub images will be rejected outright.** Images must be hosted on **Docker Hub** (hub.docker.com). Other image registries (such as ghcr.io, quay.io, self-hosted private registries, etc.) are currently not supported.

   | Priority | Source | Example |
   |---|---|---|
   | 1 (Preferred) | Docker Hub official project images | `nginx`, `postgres` |
   | 2 | Docker Hub verified publishers | Docker Hub images with Verified badge |
   | 3 | Docker Hub well-known community images | `linuxserver/jellyfin` |
   | ❌ Rejected | Images from non-Docker Hub sources | Private registries, ghcr.io, quay.io, etc. |
   | ❌ Rejected | Unverified personal images on Docker Hub | Docker Hub images with few pulls, no documentation |

   > **Mandatory Requirement:** Images must be hosted on Docker Hub. Image source will be verified during review. Using non-Docker Hub images will result in immediate rejection.

   Images from non-Docker Hub sources or unverified Docker Hub images will be rejected during security review.
2. **Image Size**: Use multi-stage builds or Alpine base images to reduce size.
3. **Sensitive Information**: Hardcoding passwords, tokens, or secrets in images or compose files is prohibited. Use environment variables or `.env` files.
4. **Security Scanning**: Run `docker scan` or `trivy` before submission to check for known vulnerabilities.
5. **User Permissions**: **Running as root is strictly prohibited, and `--privileged` mode is strictly prohibited.** A non-root user must be specified via the `user` field.

### 9.5 Complete Example

**Application Overview:**
- ID: `myapp-docker`
- Type: Docker application
- Image: `linuxserver/myapp:latest`
- Port: 8080
- Dependency: DockerEngine

> **Dependency rule:** a Docker application **must** declare `DockerEngine` in the `config.ini` `depend` field. If it also depends on another App Center application, add that application's App ID to the same list. Dependencies are installed in list order; circular dependencies are rejected. For the full field definition see **§9.2.1** (Docker-specific `config.ini` fields) and the common fields in §8.4.2.

#### config.ini

```json
{
  "id": "myapp-docker",
  "icon": "/images/icons/myapp-docker.svg",
  "publisher": "publisher name",
  "exec": true,
  "open_path": true,
  "help": "https://github.com/example/myapp/wiki",
  "version": "1.0.0",
  "recommend": false,
  "beta": false,
  "low_version": "TOS7.0",
  "category": ["Utilities"],
  "depend": ["DockerEngine"],
  "platform": "x86_64",
  "user": "1000:1000",
  "official": "https://example.com",
  "application_type": "docker",
  "compose_project": "myapp-docker",
  "allow_open_in_mobile": false
}
```
- `<platform>`: Must exactly match the `platform` field in `config.ini` and must be one of the two supported values (`x86_64` or `aarch64`). It does not accept multiple values or `all`. For multi-architecture support, each target architecture must be submitted as a separate build, and the package file name must include the appropriate architecture suffix.

#### docker-compose.yml

```yaml
version: "3.8"
services:
  myapp-docker:
    image: linuxserver/myapp:1.0.0
    container_name: myapp-docker
    restart: unless-stopped
    ports:
      - "8080:8080"
    volumes:
      - ./data:/data
    environment:
      - TZ=Asia/Shanghai
      - PUID=1000
      - PGID=1000

x-app-meta:
  web:
    port: 8080
    protocol: http
```

**Multi-container Service Startup Order:**
For applications with multiple services (e.g., Web + Database):
```yaml
services:
  app-db:
    image: postgres:16
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5
  app-web:
    image: myapp:1.0.0
    depends_on:
      app-db:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
```
- Use `depends_on` with `condition: service_healthy` to ensure correct startup order
- Health checks must be defined for every service
- Platform validation: all services must be healthy before the application is shown as "Running"

**Health Check Failure Handling:**
- After 3 consecutive health check failures, the container is marked as `unhealthy`.
- The Application Center will change the application status to "Not Enabled", and users need to manually click to enable it.
- TOS 7 does not have a built-in Docker restart policy; if needed, developers should configure the required restart policy in `docker-compose.yml` themselves.
- If the container encounters runtime errors, users can view the error logs through the Container Manager application.

### 9.6 Lifecycle Operations (Install / Upgrade / Uninstall)

This section describes the actual technical implementation of Docker application lifecycle operations on the TOS platform, based on internal platform behavior. Understanding these details is crucial for designing data backup and migration strategies.

#### 9.6.1 Installation

**Entry Chain**: `POST /app/install` → `BatchInstall` → `AppCenter.AutoInstall` → `Docker.AutoInstall`

The platform executes the following steps sequentially (this is **not** `docker-compose up -d`):

| Stage | Operation | Details |
|---|---|---|
| Download | Package download | Downloaded to `/usr/www/pkgs/<appID>.<ext>` with retry logic |
| Extract | Archive extraction | Extracted to `<InstallPath>/@apps/DockerEngine/application/<appID>`; existing directory is removed first; single subdirectory is flattened automatically |
| Project Name | Compose project resolution | Reads `compose_project` from `config.ini`; appends `_1/_2...` if project name conflicts; rewrites both `config.ini` and YAML accordingly |
| Write Compose | Write compose file | Writes `docker-compose.yml` to the application directory |
| Pull Images | **`compose pull`** | Pulls required images; resolves container user UID and runs `chown` on shared directories (DockerAppData and compose-mounted host paths) |
| Clean Residue | **`compose down`** | Cleans up old containers after container name conflict resolution |
| Create | **`compose create`** | Creates containers without starting them |
| Finalize | Post-install tasks | Writes `install_data.json`, registers watcher, executes `post-install` script |
| Start | **`compose start`** | Starts containers after 100% progress broadcast |

**Key Point**: Installation executes **pull → down → create → start**, not `up -d`.

**Installed Directory Contents (for reference):**

After a successful installation, `<InstallPath>/@apps/DockerEngine/application/<appID>/` contains:

```
<appID>/
├── config.ini            # from the submission package
├── <appid>.lang          # from the submission package
├── <appid>.svg           # from the submission package (see Section 9.2 for the icon requirement)
├── docker-compose.yml    # written / rewritten by the platform (handles project-name conflicts)
└── install_data.json     # generated by the platform at install time
```

> **Do not include `install_data.json` in your submission package.** It is created by the platform during installation (see the Finalize stage above). Seeing it on the device means the installation completed normally.
>
> **Legacy applications:** applications published before the SVG requirement may still carry a raster icon (for example `<appid>.png`) in this directory. Such files are legacy artefacts and are left untouched by the platform — they do **not** mean that raster icons are accepted. **All new submissions must use a transparent-background SVG icon** (see Section 8.6 and Chapter 16).

#### 9.6.2 Upgrade

**Current Status: Docker applications do NOT support platform upgrades.**

- **Backend**: `Docker Controller.Update` explicitly returns the error `"update not supported for docker apps"` (`controller.go:44-47`). `POST /app/update` and `POST /app/update_all` both call this controller and thus fail for Docker apps.
- **Frontend**: The "Update" button is hidden via `v-if` condition: `detailInfo.application_type !== 'docker'` (`app-detail.vue:173`).

**Conclusion**:
- There is no `pull + up -d` upgrade path.
- To "upgrade" a Docker application, users must **uninstall and then reinstall** the application (which triggers the `AutoInstall` flow).

#### 9.6.3 Uninstallation

**Entry Chain**: `DELETE /app/remove` → `BatchRemove` (with `clean` parameter) → `UninstallApp` → `UninstallOptions.CleanData` → `Docker.UninstallApp` (dispatches to `composeUninstall` if `docker-compose.yml` exists, otherwise `legacyUninstall`).

**Compose Application Uninstall**:

| Stage | Operation |
|---|---|
| Down | `compose down` (**does not remove volumes by default**). If `clean=true`, adds `--rmi all` and calls `cleanComposeVolumes`. |
| Post | Executes `post-uninstall -id <appID>`. |
| Clean Config | Deletes the configuration directory `<VolumeN>/@apps/DockerEngine/application/<appID>` (config.ini, compose files, etc.). |
| Finalize | `unwatchComposeProject` removes the watcher. |

**Legacy Application Uninstall** (installed via `docker run`):
- Executes `docker stop` and `docker rm -f` to remove containers.
- If `clean=true`, runs `docker rmi -f` to remove images.
- **No data directories are deleted under any circumstances.**

#### 9.6.4 Data Retention Policy (DockerAppData)

| Scenario | DockerAppData Result |
|---|---|
| Uninstall `clean=false` (Default) | **Retained**. `down` does not delete bind mounts or named volumes. |
| Uninstall `clean=true` (Compose) | **Only** compose mount paths matching `/Volume*/DockerAppData/<appID>/...` are deleted (`os.RemoveAll`). **Named volumes are NOT deleted** (`down` does not include `-v`). Volumes mounted to other paths are NOT deleted. |
| Uninstall `clean=true` (Legacy) | No data is deleted; only images are removed. |
| Reinstall / Overwrite Install | Only the configuration directory `@apps/.../application/<appID>` is cleaned. `DockerAppData` remains untouched. |

> **Note:** The `/Volume*/DockerAppData/<appID>/...` pattern in the table above is the platform's **internal** match pattern. You do **not** write it in `docker-compose.yml` — the platform resolves your host-side volume path (see Section 9.3, Rule 4) to that location, so bind mounts written as `./config:/config` are still cleaned up correctly when the user chooses to delete data.

**Implication for Developers**: As long as users do not select "Delete data simultaneously" during uninstall, uninstallation and reinstallation will **never** touch the application data root `/Volume<N>/DockerAppData/<appID>/`. Application data (including database files) can be safely retained across reinstallations.


← [Previous: Deb Development](08_Deb_Development.md) &nbsp;&nbsp;|&nbsp;&nbsp; [Next: Permission Model](10_Permission_Model.md) → &nbsp;&nbsp;|&nbsp;&nbsp; [📖 Back to Contents](../README.md)
