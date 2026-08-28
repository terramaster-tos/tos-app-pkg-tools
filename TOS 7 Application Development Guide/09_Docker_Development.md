
# 9. Docker Development

### 9.1 Overview

Docker applications run in containers managed by the TOS 7 Docker Engine.

> **Prerequisite:** Docker Engine is not pre-installed in TOS 7. It is provided as an application in the TOS App Center and must be installed and enabled by the user. When users install a Docker-based application, the platform automatically checks for Docker Engine and prompts installation if it is missing or disabled — no additional action is required from the developer.

**Core Requirements:**
- Must provide a `docker-compose.yml` compatible with Compose Spec 3.8+
- Data must be persisted to NAS-accessible directories via volume mounts
- **Privileged mode is strictly prohibited**
- **System core ports (22, 80, 443, 8181, 5050) must not be occupied**


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
| `<appid>.lang` | ✅ Yes | Multilingual file (14 languages) |
| `<appid>.svg` | ✅ Yes | Application icon (SVG format) |
| `docker-compose.yml` | ✅ Yes | Container orchestration configuration |

> **Important Notes:**
> - The `config.ini.icon` field must point to `/images/icons/<appid>.svg`. The platform handles the mapping during installation.
> - The package name follows the format defined in [Chapter 4.2.1](04_Package_Specification.md#421-release-asset-naming-specification): `<appid>.tar.gz`
> - For Docker applications with a UI, the `docker-compose.yml` must include the `x-app-meta` section (see Section 9.3).
> - For Docker applications without a UI, the `x-app-meta` section is not required.



### 9.3 docker-compose.yml Specification

```yaml
version: "3.8"
services:
  <appid>:
    image: <registry>/<image>:<tag>  # Images limited to Docker Hub only
    container_name: <appid>
    restart: unless-stopped
    ports:
      - "<host_port>:<container_port>"
    environment:
      - TZ=Asia/Shanghai
    user: "1000:1000"

x-app-meta:
  web:
    port: <host_port>
    protocol: http
```

> **Note:** Compose files are static configurations with no dynamic parameter matching.

**Rules:**

1. **Version**: Must be compatible with Compose Spec 3.8 or higher
2. **x-app-meta**: For Docker applications with a UI, the `x-app-meta` tag must be a top‑level key in the `docker-compose.yml` file, containing `web.port` (Web UI port) and `web.protocol` (request protocol, typically `http`).
   ```yaml
   x-app-meta:
     web:
       port: 8080
       protocol: http
   ```
3. **Comments**: You can add comments in the `docker-compose.yml` file. In YAML, comments start with `#` and must be preceded by a space (e.g., `port: 8080 # Web UI port`). Comments may also appear on their own line. 
4. **Data Persistence**: All data directories must be mounted to host paths. Data stored only inside the container will be lost when the container is removed.
5. **Port Mapping**:
   - Disabled ports: 22, 80, 443, 8181, 5050 (system services)
   - Recommended range: 8000-19999
   - Verify that the selected port is not in use on the TNAS before submission
6. **Privileged Mode**: **Strictly prohibited**. The `user` field must be used to specify UID/GID.
7. **Timezone**: Default configuration `TZ=Asia/Shanghai`. Users may modify as needed.
    Do not leave the timezone empty — inconsistent timestamps can cause data corruption in time-sensitive applications.
8. **Container Name**: **Optional.** This field is **not required** for TOS applications. 
   It is **recommended to omit** this field to allow Docker Compose to 
   auto-generate unique container names (format: `<compose_project>_<service>_<replica>`). 
   Explicitly setting `container_name` can cause naming conflicts in multi-container 
   applications.
9. **Restart Policy**: Use `unless-stopped` for normal services
10. **Network Mode**: `network_mode: host` is **strictly prohibited**, except for system-level network tools. System-level network tools must clearly state the rationale at submission and may only use it after approval. Regular applications are strictly prohibited. Using host network mode breaks container isolation and poses security risks. Use port mapping instead:
   ```yaml
   ports:
     - "8080:8080"
   ```

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

#### config.ini

```json
{
  "id": "myapp-docker",
  "icon": "/images/icons/myapp-docker.svg",
  "publisher": "Developer Name",
  "exec": true,
  "open path": true,
  "help": "https://github.com/example/myapp/wiki",
  "version": "1.0.0",
  "recommend": false,
  "beta": false,
  "low_version": "TOS7.0",
  "category": ["Utilities"],
  "relation": ["docker", "DockerEngine"],
  "platform": "x86_64",
  "official": "https://example.com",
  "application_type": "docker",
  "compose_project": "myapp-docker",
  "all_user_display": true,
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

**Implication for Developers**: As long as users do not select "Delete data simultaneously" during uninstall, uninstallation and reinstallation will **never** touch `/Volume*/DockerAppData/<appID>`. Application data (including database files) can be safely retained across reinstallations.


← [Previous: Deb Development](08_Deb_Development.md) &nbsp;&nbsp;|&nbsp;&nbsp; [Next: Permission Model](10_Permission_Model.md) → &nbsp;&nbsp;|&nbsp;&nbsp; [📖 Back to Contents](../README.md)
