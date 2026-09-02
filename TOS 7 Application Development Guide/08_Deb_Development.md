# 8. Deb Development Specification

### 8.1 Overview

Deb applications are native packages that run directly on the TOS 7 host system. They follow standard Debian packaging specifications, adapted for TOS service management and platform integration.

TOS 7 Deb applications are divided into **three subtypes** based on whether they have a frontend page and how it is opened:

| Subtype | Use Case | Opening Method | Backend Communication |
|---|---|---|---|
| **WebUI Internal Open** | Backend is a local executable service, frontend is a static WebUI | TOS desktop embedded iframe | Unix Socket + Platform Proxy |
| **WebUI External Open** | Backend is a local executable service, frontend is a static WebUI | New browser tab | Nginx Reverse Proxy + HTTP Port |
| **No UI Service** | Background service without an interface | No frontend page | As needed (no mandatory requirements) |

**Subtype Selection Mandatory Constraints:**

| Application Characteristic | Required Subtype |
|---|---|
| Has Web UI and must open within the TOS desktop | WebUI Internal Open (iframe) |
| Has Web UI and must open in a browser tab | WebUI External Open (new tab) |
| No frontend / background daemon service | No UI Service |
| Needs to access device filesystem via TOS File Manager | WebUI Internal or External Open — if the application requires users to select file paths in the TOS File Manager, it must provide a WebUI (either internal or external) to embed the file picker component. |

TOS 7 Deb applications support **two packaging methods**:

| Packaging Method | Use Case | Description |
|---|---|---|
| **Method 1: Single-Package Mode** | New applications developed from scratch | Developers develop directly according to TOS 7.0 specifications, integrating all files into a single deb package |
| **Method 2: Dual-Package Mode (also called Archive Mode)** | Applications with existing generic standard deb packages | The original application package (deb source package) remains unchanged, with an additional data package (`<appid>.deb`) conforming to TOS 7.0 specifications provided; both are packaged into a tar.gz archive for submission |

**Dual-Package Mode Applicability Rules:**

| Scenario | Must Use | Must Not Use |
|---|---|---|
| Existing generic standard deb package, complex build | Dual-package mode | — |
| New application developed from scratch | — | Not recommended to use dual-package mode — unless there is a special reason (such as needing to separate configuration from binaries), new applications developed from scratch should use single-package mode. |
| Simple binary program, no existing packaging | — | Dual-package mode (should use single-package mode) |
| Third-party upstream Debian packages | Dual-package mode | — |

**Dual-Package Mode Mandatory Constraints:**

- **Version Consistency:** The `Version` fields of the data package and source package must be exactly the same; inconsistencies result in immediate rejection.
- **Content Restrictions:** The data package (`<appid>.deb`) **must not contain any binary files**, otherwise it will be immediately rejected.
- **Installation Order:** Automatically guaranteed by the APT repository dependency mechanism (data package `Depends` on the source package); no additional configuration required.
- **Source Package Independence:** The deb source package must be independently installable on the TOS 7.0 system using the `dpkg -i` command.
- **Dependency Declaration:** The `Depends` field in the deb data package metadata must include the deb source package, preferably specifying the version as well, to maintain healthy dependency relationships.

### 8.2 General Directory Structure

All Deb application files are installed under the `/usr/local/<app_id>/` directory:

```
/usr/local/<app_id>/
├── config.ini                    # 【Required】Core application configuration file
├── bin/
│   └── <binary_name>             # 【Required】Backend executable
├── <app_id>.lang                 # 【Required】Multilingual configuration file
├── images/
│   └── icons/
│       └── <icon_file>.svg       # 【Required】Application icon
├── init.d/
│   └── <system_id>.service       # 【Required】Systemd service unit file
├── webui.bz2                     # 【Required for WebUI applications】Frontend page archive
├── nginx/                        # 【Required only for external open】
│   └── <app_id>.conf             # Nginx configuration file
├── <app_id>.env                  # 【Optional】Environment variable configuration file
└── depends/                      # 【Optional】Dependency file directory
    ├── bin/                      # Executable files
    ├── lib/                      # Dynamic libraries (.so)
    ├── etc/                      # Configuration files
    ├── data/                     # Runtime data (databases/cache/state)
    └── logs/                     # Logs
```

**Mandatory Correspondences:**

```text
config.ini.id              == <app_id>
config.ini.package         == Package in DEBIAN/control
config.ini.system_id       == systemd service unit ID (without .service suffix)
config.ini.icon            == "/images/icons/<icon_file>.svg"
config.ini.path            == "/<app_id>/" (WebUI Internal Open)
```

**Requirements:**
1. Application files are installed to `/usr/local/<app_id>/`.
2. The `<app_id>.lang` filename must correspond to `config.ini.id`.
3. The icon file path must correspond to `config.ini.icon`.
4. The systemd service unit ID must match `system_id` in `config.ini`.
5. The binary package name `Package` in the deb metadata must match `package` in `config.ini`.
6. The service must be able to be started, stopped, and queried for status via `<system_id>.service`.

### 8.3 Three Subtypes in Detail

**The three subtypes are mutually exclusive — each application belongs to only one:**

| Subtype | config.ini Required Fields | Key Identifier |
|---|---|---|
| **iframe (Internal Open)** | `type`, `path` | `"type": "iframe"`, `"open_path": false` |
| **External Open (New Tab)** | `path` | `"open_path": true` (do not include `type` field) |
| **No UI Service** | No page-related fields | Do not include `path`, `open_path`, or `type` fields |

> **Mutual Exclusion Rule:** `type` and `open_path` must not appear together — iframe uses `"type": "iframe"`; external open uses `"open_path": true`; no UI uses neither. Mixing them will result in undefined behavior and rejection during review.

#### 8.3.1 WebUI Internal Open (iframe Embedding)

For applications where the backend is a local executable service, the frontend is a static WebUI, opened within the TOS desktop as an embedded iframe.

**Directory Structure:**

```
/usr/local/<app_id>/
├── config.ini
├── bin/
│   └── <binary_name>
├── <app_id>.lang
├── webui.bz2                     # 【Required】Frontend page archive
├── images/
│   └── icons/
│       └── <icon_file>.svg
├── init.d/
│   └── <system_id>.service
├── <app_id>.env                  # 【Optional】Environment variable configuration file
└── depends/                      # 【Optional】Dependency file directory
    ├── bin/                      # Executable files
    ├── lib/                      # Dynamic libraries (.so)
    ├── etc/                      # Configuration files
    ├── data/                     # Runtime data (databases/cache/state)
    └── logs/                     # Logs
```

**config.ini Minimal Configuration:**

```json
{
  "id": "<app_id>",
  "icon": "/images/icons/<icon_file>.svg",
  "exec": true,
  "version": "<app_version>",
  "category": ["Utilities"],
  "platform": "x86_64",
  "system_id": "<system_id>",
  "package": "<deb_package_name>",
  "application_type": "deb",
  "path": "/<app_id>/",
  "type": "iframe"
}
```

**Core Requirements:**

1. The `type` field must be `"iframe"`.
2. The `path` field format is `"/<app_id>/"`.
3. `webui.bz2` is a fixed filename and must not be changed to any other name.
4. The deb package must contain an executable program, located at `/usr/local/<app_id>/bin/<binary_name>`.
5. The `config.ini.package` field specification must strictly conform to the Debian package `package` specification.
6. The backend service provides HTTP interfaces externally via Unix Socket and must listen on `/var/api/<app_id>.sock` on startup.
7. `/var/api` must be auto-created if it does not exist; old socket files must be cleaned up before startup.
8. Socket file permissions must allow platform proxy access.
9. Frontend requests to backend interfaces must go through the platform proxy path, with the fixed format `/v2/proxy/<app_id>`.
10. Frontend requests must carry the platform authentication headers, including `X-Csrf-Token` and `Cookie` in the request headers.

**Socket File Specification:**
- Permission mode: `0660` (owner and group read/write)
- Owner: `<appid>:<appid>` (matches the service user)
- Supports HTTP keep-alive connections
- Supports at least 100 concurrent connections
- Idle connection timeout: 30 seconds

7. Frontend requests to backend interfaces must go through the platform proxy path: `/v2/proxy/<app_id>/<api_name>`.
8. Frontend requests must carry the platform authentication headers.

**CORS and Preflight Request Configuration:**
The backend must handle CORS preflight requests (OPTIONS method) for the platform proxy. Allow the following:
- Origin: TOS Web origin
- Methods: GET, POST, PUT, DELETE, OPTIONS
- Headers: Content-Type, X-Csrf-Token, Cookie
- Credentials: true

#### 8.3.2 WebUI External Open (New Tab)

For applications where the backend is a local executable service, the frontend is a static WebUI, opened in a new browser tab.

**Directory Structure:**

```
/usr/local/<app_id>/
├── config.ini
├── bin/
│   └── <binary_name>
├── <app_id>.lang
├── webui.bz2                     # 【Required】Frontend page archive
├── images/
│   └── icons/
│       └── <icon_file>.svg
├── nginx/
│   └── <app_id>.conf             # 【Required】Nginx configuration file
├── init.d/
│   └── <system_id>.service
├── <app_id>.env                  # 【Optional】Environment variable configuration file
└── depends/                      # 【Optional】Dependency file directory
    ├── bin/                      # Executable files
    ├── lib/                      # Dynamic libraries (.so)
    ├── etc/                      # Configuration files
    ├── data/                     # Runtime data (databases/cache/state)
    └── logs/                     # Logs
```

**config.ini Minimal Configuration:**

```json
{
  "id": "<app_id>",
  "icon": "/images/icons/<icon_file>.svg",
  "exec": true,
  "version": "<app_version>",
  "category": ["Utilities"],
  "platform": "x86_64",
  "system_id": "<system_id>",
  "package": "<deb_package_name>",
  "application_type": "deb",
  "path": "http://${ip}:8686",
  "open_path": true
}
```

**Core Requirements:**

1. `open_path` must be `true`.
2. The `path` field must correspond to the nginx configuration file route and resolve to the externally provided HTTP interface.
3. The application package must include an nginx configuration file `<app_id>.conf`, whose filename must correspond to `config.ini.id`.
4. The backend directly listens on `<listen_port>` to provide HTTP interfaces.
5. The deb package must contain an executable program, located at `/usr/local/<app_id>/bin/<binary_name>`.
6. The `config.ini.package` field specification must strictly conform to the Debian package `package` specification.

**Port Listening Rules:**
- **Must** listen on `0.0.0.0` (all network interfaces); listening only on `127.0.0.1` is forbidden. Listening only on the loopback address prevents external access.
- **Must not** occupy system reserved ports (22, 80, 443, 8181, 5050)
- Recommended port range: 8000-19999

**Nginx Configuration File Template:**

Create at `/usr/local/<app_id>/nginx/<app_id>.conf`:

```nginx
location /<app_id>/ {
    proxy_pass http://127.0.0.1:<listen_port>/;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

**Nginx Configuration Management Requirements:**
- Configuration file permissions: `644` (owner read/write, group and others read-only)
- Configuration file must be placed at `/usr/local/<app_id>/nginx/<app_id>.conf`
- The platform Nginx `include` directive loads configurations in alphabetical order; port conflicts between applications are resolved by using unique ports — two applications cannot share the same port
- Log rotation: Nginx access/error logs are managed by the platform; do not write your own nginx logs
- Must not include `server {}` blocks; only use `location /<app_id>/ {}` blocks

#### 8.3.3 No UI Service

For background service applications without an interface.

**Directory Structure:**

```
/usr/local/<app_id>/
├── config.ini
├── bin/
│   └── <binary_name>
├── <app_id>.lang
├── images/
│   └── icons/
│       └── <icon_file>.svg
├── init.d/
│   └── <system_id>.service
├── <app_id>.env                  # 【Optional】Environment variable configuration file
└── depends/                      # 【Optional】Dependency file directory
    ├── bin/                      # Executable files
    ├── lib/                      # Dynamic libraries (.so)
    ├── etc/                      # Configuration files
    ├── data/                     # Runtime data (databases/cache/state)
    └── logs/                     # Logs
```

**config.ini Minimal Configuration:**

```json
{
  "id": "<app_id>",
  "icon": "/images/icons/<icon_file>.svg",
  "exec": true,
  "version": "<app_version>",
  "category": ["Utilities"],
  "platform": "x86_64",
  "system_id": "<system_id>",
  "package": "<deb_package_name>",
  "application_type": "deb"
}
```

**Core Requirements:**

1. No UI applications do not need frontend-related fields such as `path`, `type`, `open_path`, `resize`, `maxmin`, `width`, `height`.
2. The `webui.bz2` frontend archive is not required.
3. The `nginx/` directory is not required.
4. The deb package must contain an executable program, located at `/usr/local/<app_id>/bin/<binary_name>`.
5. The `config.ini.package` field specification must strictly conform to the Debian package `package` specification.

**Status Reporting Requirements:**
No UI applications must report their running status so that the platform can detect failures:
- The systemd service unit `Type` should be `simple` or `forking`
- Use systemd's `ExecStartPost` to confirm successful startup
- The App Center displays "Running"/"Stopped"/"Abnormal" based on the systemd service status
- On failure, systemd auto-restart (configured in the service file) handles recovery

### 8.4 Core Configuration File — config.ini

config.ini is the core metadata file, defining the application's identity, display information, runtime attributes, and dependency relationships. It is the key basis for platform validation and App Center display.

> **Important:** The file extension is `.ini`, but the content must be in **strict JSON format**. Do not add comments, use single quotes, trailing commas, or any syntax errors.

> **Format Note:** The `.ini` file extension is a company historical convention (maintaining filename consistency with the legacy configuration system), but the parser processes it as JSON format. Developers must write using JSON syntax, otherwise automatic validation will fail.

#### 8.4.1 Standard Template

Below is the config.ini standard template, divided into three independent examples by application subtype. Developers should choose the corresponding template based on their application type. **Choose one of the three; do not mix.**

> **Must Read: Field Mutual Exclusion Relationships**
>
> | Application Type | Required Fields | Forbidden Fields |
> |---|---|---|
> | WebUI Internal Open (iframe) | `type: "iframe"` + `path: "/<id>/"` | `open_path` |
> | WebUI External Open (New Tab) | `open_path: true` + `path: "http://${ip}:<port>"` | `type` |
> | No UI Service | — | `type`, `open_path`, `path` |

---

**Template 1: WebUI Internal Open (iframe Embedding)**

```json
{
  "id": "dev-myapp",
  "icon": "/images/icons/dev-myapp.svg",
  "publisher": "Developer Name",
  "exec": true,
  "type": "iframe",
  "path": "/dev-myapp/",
  "resize": true,
  "maxmin": true,
  "width": 1180,
  "height": 680,
  "help": "https://example.com/docs",
  "version": "1.0.0",
  "recommend": false,
  "beta": false,
  "low_version": "TOS7.0",
  "category": ["Utilities"],
  "depend": [],
  "relation": [],
  "platform": "x86_64",
  "official": "https://example.com",
  "application_type": "deb",
  "system_id": "dev-myapp",
  "package": "dev-myapp",
  "user": "dev-myapp",
  "all_user_display": true,
  "allow_open_in_mobile": false
}
```

**Template 2: WebUI External Open (New Tab)**

```json
{
  "id": "dev-myapp",
  "icon": "/images/icons/dev-myapp.svg",
  "publisher": "Developer Name",
  "exec": true,
  "open_path": true,
  "path": "http://${ip}:8686",
  "help": "https://example.com/docs",
  "version": "1.0.0",
  "recommend": false,
  "beta": false,
  "low_version": "TOS7.0",
  "category": ["Utilities"],
  "depend": [],
  "relation": [],
  "platform": "x86_64",
  "official": "https://example.com",
  "application_type": "deb",
  "system_id": "dev-myapp",
  "package": "dev-myapp",
  "user": "dev-myapp",
  "all_user_display": true,
  "allow_open_in_mobile": false
}
```

**Template 3: No UI Service**

```json
{
  "id": "dev-myapp",
  "icon": "/images/icons/dev-myapp.svg",
  "publisher": "Developer Name",
  "exec": true,
  "help": "https://example.com/docs",
  "version": "1.0.0",
  "recommend": false,
  "beta": false,
  "low_version": "TOS7.0",
  "category": ["Utilities"],
  "depend": [],
  "relation": [],
  "platform": "x86_64",
  "official": "https://example.com",
  "application_type": "deb",
  "system_id": "dev-myapp",
  "package": "dev-myapp",
  "user": "dev-myapp",
  "all_user_display": true,
  "allow_open_in_mobile": false
}
```

#### 8.4.2 Field Reference

| Field | Type | Required | Description | Detailed Description |
|---|---|---|---|---|
| `id` | string | ✅ Yes | Application unique identifier | Globally unique on the platform; must not duplicate any listed application. Character set: lowercase letters (a-z), digits (0-9), and hyphens (-). Must start with a letter. Maximum length: 50 characters. Recommended format: developer-account-identifier-app-business-name or reversed-domain-app-name. Examples: dev-admin-monitor, com-douyin-service. Prohibited pure generic system keywords: docker, bin, var, api, usr, root, admin, system, service, etc. Cannot be modified after creation. |
| `icon` | string | ✅ Yes | Icon path | Relative path within the repository. Must follow the `/images/icons/<id>.svg` format. The icon file must exist at this path. |
| `publisher` | string | ✅ Yes | Publisher name | The developer or organization name displayed in the App Center. Example: `"Kevin"`, `"LinuxServer.io"`. |
| `path` | string | Conditionally Required | Application access address | **The `path` field is mutually exclusive by scenario: iframe uses `/<app_id>/`; external open uses `http://${ip}:<port>`; no UI is left empty.** Must use the `${ip}` placeholder (e.g., `http://${ip}:8686`). The system automatically replaces `${ip}` with the TNAS LAN IP. **Hardcoding a fixed IP or domain is prohibited.** Non-80/443 ports: `http://${ip}:<port>`. WebUI Internal Open (iframe): `/<app_id>/`. No UI application: set to `""` or omit this field. Required when `exec=true`. |
| `exec` | bool | ✅ Yes | Whether there is an executable service | Whether the application supports start/stop operations. `true`: App Center displays start/stop buttons; `false`: display only, no lifecycle control. |
| `open_path` | bool | Conditionally Required | Whether to open in a new tab | Controls how the application is opened: `true` = new browser tab; `false` or omitted = TOS desktop embedded iframe. External open applications must set this to `true`. **Mutually exclusive with `type`; must not be set simultaneously.** |
| `type` | string | Conditionally Required | Application open type | Set to `"iframe"` for WebUI Internal Open (iframe embedding). **⚠️ Mutually exclusive with `open_path`; must not be set simultaneously.** External open or no UI applications do not set this field. |
| `resize` | bool | No | Whether the window is resizable | Only effective when `open_path=false`. Controls whether the application popup can be resized. Default `false`. |
| `maxmin` | bool | No | Whether the window can be maximized/minimized | Only effective when `open_path=false`. Controls whether the application popup supports maximize/minimize. Default `false`. |
| `width` | int | No | Default window width | Only effective when `open_path=false`. The width of the application page when opened, default 1180. |
| `height` | int | No | Default window height | Only effective when `open_path=false`. The height of the application page when opened, default 680. |
| `help` | string | No | Help documentation URL | Link to help documentation, wiki, or community tutorials. Leave empty if none. |
| `version` | string | ✅ Yes | Application version number | Follows semantic versioning. Each submission must be unique and incremented. Example: `"1.0.0"`, `"2.3.1"`. |
| `recommend` | bool | ✅ Yes | Whether the application is recommended | `recommend` — Recommendation flag, uniformly set by platform operations after review based on application quality. **Developers must always set this to `false` when submitting.** This field is managed by the platform; developers must not modify it to `true` on their own. |
| `beta` | bool | ✅ Yes | Whether it is a beta version | `true` = beta version, only shown to test users; `false` = stable version, shown to all users. |
| `low_version` | string | ✅ Yes | Minimum supported TOS version | The minimum TOS version on which the application can run normally. Must be `TOS7.0` or higher. Format: `"TOS7.0"`, `"TOS7.1"`. |
| `category` | []string | ✅ Yes | Application categories | Up to 3 categories, selected from the official category list (see [Appendix A](/20_Appendix.md#appendix-a-application-categories)). **The first category is the primary category** — it determines the default display section of the application. Arrange from most specific to most general. Exceeding the category limit results in rejection. |
| `depend` | []string | ✅ Yes | Dependency application list | Application IDs that must be installed before this application. Must be existing App Center application IDs. Dependencies are installed in list order. Example: `["DockerEngine"]`. No dependencies: `[]`. **Circular dependencies will be rejected.** |
| `relation` | []string | No | Related application list | Application IDs displayed in the "Related Applications" module on the application details page. No mandatory dependency, display association only. No relations: `[]`. |
| `platform` | string | ✅ Yes | Target architecture | `"x86_64"` or `"aarch64"`. Multi-architecture requires separate submissions. |
| `official` | string | No | Official website | Link to the application's official website. Leave empty if none. |
| `application_type` | string | ✅ Yes | Application package type | Deb single-package mode applications: `"deb"`; dual-package/archive mode applications: `"deb-TarGz"`; Docker applications: `"docker"`. |
| `system_id` | string | Conditionally Required | Systemd service name | **Required for Deb applications.** Must match the systemd service filename. Leave empty for Docker applications. |
| `package` | string | Conditionally Required | Deb package name | **Required for Deb applications.** Must match the `Package` field in DEBIAN/control. Leave empty for Docker applications. |
| `compose_project` | string | Conditionally Required | Docker Compose project name | **Required for Docker applications.** Specifies the name used when creating the docker-compose project; must conform to Docker Compose project naming conventions (only lowercase letters, digits, hyphens, and underscores). Leave empty for Deb applications. Example: `"myapp-docker"`.<br>⚠️ **Note:** Although Docker Compose allows underscores, it is recommended that `compose_project` use the same character set as `id` to reduce confusion. `id` only supports lowercase letters, digits, and hyphens (no underscores). If both use the same string, do not use underscores in `compose_project` either. |
| `user` | string | ✅ Yes | Runtime user | The system user under which the application runs. After specification, a dedicated user is automatically created (e.g., `"jellyfin"`). Deb applications must match the systemd service `User` field. **Using the root user is strictly prohibited.** |
| `all_user_display` | bool | ✅ Yes | Whether visible to all users | `true` = visible to all TNAS users; `false` = visible to administrators only. When `false`, the application only appears in the administrator's App Center view. Non-admin users cannot see or interact with the application. The application is still installed system-wide and runs for all users; this setting only controls visibility. |
| `allow_open_in_mobile` | bool | No | Whether mobile access is supported | `true` = the application supports mobile access; `false` = the application does not support mobile access. Default `false`. |
| `share_folders` | []string | No | Shared folders created on installation | Configures shared folders to be created for the application during installation, with folder permissions managed via ACL. **Using this field requires the `user` field to be non-empty.** Example: `["data", "config"]`. |

#### 8.4.3 Key Rules

**JSON Format Validation:**

Validate config.ini before submission:

```bash
# Using python3
python3 -c "import json; json.load(open('config.ini'))" && echo "JSON format valid"

# Using jq
jq empty config.ini
```

**Common JSON Errors Leading to Rejection:**
```json
{
  "id": "myapp",       // ❌ Trailing comma after the last field of an object
  "version": '1.0.0',  // ❌ Single quotes (must use double quotes)
  // ❌ JSON does not allow comments
  "beta": false,
}
```
Correct:
```json
{
  "id": "myapp",
  "version": "1.0.0",
  "beta": false
}
```

**❌ Full-width quotes**: `"version"： "1.0.0"` → **✅ Half-width quotes**: `"version": "1.0.0"`

1. **IP Placeholder**: The `path` field must use `${ip}` (e.g., `http://${ip}:8686`). Hardcoding a fixed IP or domain is prohibited.
2. **JSON Syntax**: Must be valid JSON. Comments (`//` or `/* */`), single quotes, or trailing commas are prohibited.
3. **ID Uniqueness**: `id` must be globally unique. Duplicate IDs will be rejected.
4. **Version Incrementation**: Each new submission's version number must be greater than the previous version. Duplicates or downgrades are prohibited.
5. **Category Limit**: Each application may have at most 3 categories.
6. **TOS Version**: `low_version` must be TOS 7.0 or higher.
7. **Field Consistency**: `version` must be consistent across config.ini, DEBIAN/control, and app.lang. `system_id` must match the systemd service filename. `package` must match the `Package` field in DEBIAN/control.

**`path` Field Value Quick Reference Table:**

| Application Type | Opening Method | `path` Value | Example |
|---|---|---|---|
| Deb WebUI Internal Open | iframe embedding | `/<app_id>/` | `"/tmrtimer/"` |
| Deb WebUI External Open | New tab | `/<app_id>/` | `"/weather/"` |
| Docker Application | New tab | `http://${ip}:<port>` | `"http://${ip}:8080"` |
| No UI Service | No frontend | Omit or `""` | — |

> **Note:** The `path` format for iframe mode (internal open) and external open is the same (both `/<app_id>/`). The difference lies in the `open_path` field: internal open `open_path=false` (default), external open `open_path=true`. Docker applications use the `http://${ip}:<port>` format for `path`.

> **Reserved Fields:** The following field names are reserved for future platform use. Do not use them in custom config.ini: `host_network`, `container_runtime`, `sandbox`, `auto_update`, `upstream_url`, `license`, `min_memory`, `min_cpu`, `min_disk`. Using reserved fields may lead to future compatibility issues and rejection.

---

### 8.5 Language File — app.lang

The language file provides multilingual display support for the App Center. The system automatically loads the corresponding language based on the user's device language.

#### 8.5.1 Supported Languages (14 Required)

| Tag | Language |
|---|---|
| `zh-cn` | Simplified Chinese |
| `zh-hk` | Traditional Chinese |
| `en-us` | English |
| `fr-fr` | French |
| `de-de` | German |
| `it-it` | Italian |
| `es-es` | Spanish |
| `hu-hu` | Hungarian |
| `ja-jp` | Japanese |
| `ko-kr` | Korean |
| `pl-pl` | Polish |
| `ru-ru` | Russian |
| `tr-tr` | Turkish |
| `pt-pt` | Portuguese |

#### 8.5.2 File Format

```ini
[en-us]
name = "Application Name"
auth = "Developer Name"
descript = "Detailed description of the application's features and characteristics."
release_note = "1. New features added. 2. Bug fixes."
important = "Important notes that users need to be aware of."

[zh-cn]
name = "应用名称"
auth = "开发者名称"
descript = "应用功能和特性的详细描述。"
release_note = "1. 新增功能。2. 修复问题。"
important = "用户需要注意的重要事项。"
```

#### 8.5.3 Field Descriptions

| Field | Required | Description |
|---|---|---|
| `name` | ✅ Yes | Application display name. If the application name is a universal language name (not translated), the same name may be used across all languages. |
| `auth` | ✅ Yes | Developer/organization name. |
| `descript` | ✅ Yes | Application feature description. Semantics must be consistent across all languages. |
| `release_note` | No | Version update content. Use `</br>` for line breaks between multiple items. May be left empty for the first release. |
| `important` | No | Important notices (such as permission requirements, port conflicts, configuration steps, etc.). |

#### 8.5.4 Rules

1. All 14 language nodes must be present. For untranslated languages, fill with English content — **leaving blank is prohibited**.
2. File encoding must be **UTF-8 without BOM**.
3. The `descript` field semantics must be consistent across all languages.
4. If the application name is a universal language name (not translated), the same value may be used for `name` across all languages. If the application name itself is a proper noun (such as a brand name or product name), the same name may be used across all languages without transliteration or translation.
5. File naming convention: `<appid>.lang` (e.g., `aria2.lang`).

#### 8.5.5 File Encoding & Format

- File encoding must be **UTF-8 without BOM**
- Line endings must be **LF** (Unix style, `\n`). CRLF (Windows style, `\r\n`) will cause parsing errors
- File naming convention: `<appid>.lang` (e.g., `aria2.lang`)

#### 8.5.6 Text Length Limits

| Field | Maximum Length | Description |
|---|---|---|
| `name` | 64 characters | Display name; truncated if exceeded |
| `auth` | 64 characters | Developer/organization name |
| `descript` | 512 characters | Feature description |
| `release_note` | Recommended not exceeding 2048 characters | Multiple lines separated by `</br>` |
| `important` | 512 characters | Important notices |

#### 8.5.7 release_note Format

- Use `</br>` as the line break separator between multiple items
- **Do not** use other HTML tags (`<b>`, `<p>`, `<div>`, etc.) — they may cause page rendering anomalies
- Plain text only, except for `</br>` line breaks

#### 8.5.8 Translation Consistency

- The `descript` field semantics must be consistent across all 14 languages
- Reviewers will verify translation accuracy for at least the core languages (zh-cn, en-us). Obvious errors in other languages will require the developer to correct them.

---

### 8.6 Application Icon

| Requirement | Specification |
|---|---|
| Format | SVG (vector graphics, transparent background) |
| Filename | Must exactly match the `id` in config.ini (e.g., `Example-latest.svg`) |
| Storage Path | Under the repository `/images/icons/` directory |
| ViewBox | Recommended: `0 0 512 512` |
| Design Requirements | Clearly recognizable, no prohibited content |

Icon display scenarios: application list, application details page, installed applications panel.

---

### 8.7 Backend Service Specification

#### 8.7.1 WebUI Internal Open (Unix Socket Mode)

The backend executable is installed at:

```text
/usr/local/<app_id>/bin/<binary_name>
```

The backend must create and listen on a Unix Socket:

```text
/var/api/<app_id>.sock
```

**Requirements:**
1. `/var/api` must be auto-created if it does not exist.
2. Old socket files must be cleaned up before startup.
3. Socket file permissions must allow platform proxy access.
4. The backend interface protocol is HTTP-over-Unix-Socket.
5. The backend should gracefully handle `SIGTERM` for systemd service stopping.

**Standard Log Specification:**

| Log Level | Use |
|---|---|
| ERROR | Service failures, startup errors, data corruption |
| WARN | Deprecated features, recoverable errors, configuration issues |
| INFO | Service lifecycle events (startup/shutdown), version information, configuration loaded |
| DEBUG | Detailed diagnostic information — **DEBUG level logs must be disabled in production environments**, only used during development and debugging |

**Standard Output Format:**
```
[YYYY-MM-DD HH:MM:SS] [LEVEL] [component] message
```
Example:
```
[2026-05-11 16:30:00] [INFO] [main] Service started on port 8686
```

For systemd-managed services, prefer stdout/stderr for log output — systemd journal automatically captures both.

**Service Crash Auto-Restart Limits:**
- Maximum restart attempts: **5 times within 60 seconds**
- Once the limit is exceeded, the service enters a failed state
- The App Center displays the service as "Abnormal" after the restart limit is exceeded
- **The parameters `StartLimitBurst=5` and `StartLimitIntervalSec=60` must be explicitly configured in the systemd service file.**

#### 8.7.2 WebUI External Open (HTTP Port Mode)

The backend executable is installed at:

```text
/usr/local/<app_id>/bin/<binary_name>
```

The backend directly listens on `<listen_port>` to provide HTTP interfaces.

**Requirements:**
1. Directly listen on `<listen_port>`.
2. Serve the static WebUI homepage.
3. Provide a health check endpoint.
4. Provide business API routes; specific business logic is defined by the application.
5. Gracefully handle `SIGTERM` and `SIGINT`.

**Recommended Fixed Routes:**

```text
GET /
GET /health
```

**Recommended Business API Naming:**

```text
/api/<resource>
```

For compatibility with the system entry point, the following may also be supported simultaneously:

```text
/<app_id>/api/<resource>
/v2/proxy/<app_id>/<resource>
/v2/proxy/<app_id>/api/<resource>
```

### 8.8 Frontend File Specification

Applicable to WebUI applications (both internal and external open).

Frontend source code may be placed in the project source directory:

```text
webui/
├── index.html
├── app.js
└── styles.css
```

It must be compressed into `webui.bz2` for packaging, with the installation path:

```text
/usr/local/<app_id>/webui.bz2
```

**Requirements:**
1. After decompression, `webui.bz2` must contain a properly openable `.html` file.
2. At least `index.html`, `app.js`, `styles.css` are recommended.
3. The frontend page should initialize to an empty state each time it is opened, and should not reuse temporary input state from the previous session.
4. Frontend resource references should include version parameters to avoid loading stale caches after application upgrades.

```html
<link rel="stylesheet" href="./styles.css?v=<version>">
<script src="./app.js?v=<version>"></script>
```

### 8.9 Frontend-Backend Request Specification (WebUI Internal Open)

When the frontend accesses the backend, it **must not directly access the socket file**. Requests must go through the platform HTTP proxy path:

```text
/v2/proxy/<app_id>/<api_name>
```

If the application has only one main interface, it is recommended:

```text
/v2/proxy/<app_id>
```

**Frontend Request Example:**

```js
fetch("/v2/proxy/<app_id>/<api_name>", {
  method: "POST",
  credentials: "include",
  headers,
  body: JSON.stringify(payload)
});
```

The backend is recommended to be compatible with the following routes to avoid path inconsistencies under different proxy modes:

```text
/<app_id>
/<app_id>/<api_name>
<config.ini.path>/<api_name>
<config.ini.path>/<app_id>
```

### 8.10 Frontend Authentication Header Specification (WebUI Internal Open)

When the frontend sends backend requests, it must read the current website cookies.

**Cookies that must be read:**

```text
TMSESSNAME
X-Csrf-Token
```

**Request headers must include:**

```text
X-Csrf-Token: <X-Csrf-Token value read from cookie>
Cookie: TMSESSNAME=<TMSESSNAME value read from cookie>; X-Csrf-Token=<X-Csrf-Token value read from cookie>;
```

**Example:**

```text
X-Csrf-Token: ltRoTGSICC68drxbvljhBeD2DZ7LPcge
Cookie: TMSESSNAME=46958db9-1f8a-4686-b340-34fd8ccf62e8; X-Csrf-Token=ltRoTGSICC68drxbvljhBeD2DZ7LPcge;
```

**Frontend Implementation Example:**

```js
function getCookie(name) {
  const prefix = encodeURIComponent(name) + "=";
  return document.cookie
    .split(";")
    .map((item) => item.trim())
    .find((item) => item.startsWith(prefix))
    ?.slice(prefix.length) || "";
}

const sessionName = getCookie("TMSESSNAME");
const csrfToken = getCookie("X-Csrf-Token");

const headers = {
  "Content-Type": "application/json",
  "X-Csrf-Token": csrfToken,
  "Cookie": `TMSESSNAME=${sessionName}; X-Csrf-Token=${csrfToken};`
};
```

**Notes:**
1. Browsers do not allow the frontend to manually set the standard `Cookie` header.
2. This specification uses the custom header `Cookie` to pass the concatenated cookie string.
3. `Cookie` is a fixed key name and must be spelled as required by the platform.
4. Requests should retain `credentials: "include"`.

If the backend needs to support browser preflight requests, it should allow the following headers:

```text
Content-Type
X-Csrf-Token
Cookie
```

**`Cookie` Header Naming Note:** The custom header name `Cookie` is a platform internal naming convention. It bypasses the browser's restriction on setting the standard `Set-Cookie` header in JavaScript fetch/XHR requests. This name is fixed and must not be changed — any deviation will break authentication.

**Backend Authentication Validation Example (Python):**
```python
def validate_auth(headers):
    '''Validate the Cookie authentication header from frontend requests.'''
    cookie_str = headers.get('Cookie', '')
    csrf_token = headers.get('X-Csrf-Token', '')
    
    # Parse Cookie header (format: key1=val1; key2=val2)
    parts = {}
    for part in cookie_str.split(';'):
        if '=' in part:
            k, v = part.strip().split('=', 1)
            parts[k.strip()] = v.strip()
    
    session_name = parts.get('TMSESSNAME', '')
    cookie_csrf = parts.get('X-Csrf-Token', '')
    
    if not session_name or not csrf_token:
        return False
    if csrf_token != cookie_csrf:
        return False
    # Validate session via TOS platform
    return True
```

**Backend Authentication Validation Example (Go):**
```go
func validateAuth(r *http.Request) bool {
    cookieStr := r.Header.Get("Cookie")
    csrfToken := r.Header.Get("X-Csrf-Token")
    if cookieStr == "" || csrfToken == "" {
        return false
    }
    for _, part := range strings.Split(cookieStr, ";") {
        kv := strings.SplitN(strings.TrimSpace(part), "=", 2)
        if len(kv) == 2 && kv[0] == "X-Csrf-Token" {
            if kv[1] != csrfToken {
                return false
            }
        }
    }
    return true
}
```

**Token Expiry and Session Invalidation Handling:**
- When the authentication token expires or the session becomes invalid, the backend must return HTTP `401 Unauthorized`
- The frontend must detect the 401 response and redirect to the TOS login page
- Do not attempt to auto-refresh the token; redirect to `/` to trigger TOS re-authentication

```javascript
fetch('/v2/proxy/myapp/api', { credentials: 'include' })
  .then(res => {
    if (res.status === 401) {
      window.location.href = '/';  // Redirect to TOS login
    }
    return res.json();
  });
```

---
### 8.11 Nginx Configuration Specification (WebUI External Open)

An nginx configuration directory must be created at the same level as `config.ini`:

```text
/usr/local/<app_id>/nginx/<app_id>.conf
```

**Content Template:**

```nginx
location /<app_id>/ {
    proxy_pass http://127.0.0.1:<listen_port>/;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

**Example (weather application, port 16688):**

```nginx
location /weather/ {
    proxy_pass http://127.0.0.1:16688/;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

### 8.12 Systemd Service Specification

The service unit ID comes from `config.ini.system_id`:

```json
{
  "system_id": "<system_id>"
}
```

The final system service must be:

```text
<system_id>.service
```

Retained within the application installation directory:

```text
/usr/local/<app_id>/init.d/<system_id>.service
```

**Standard Service File:**

**Standard Service File (with security hardening):**

```ini
[Unit]
Description=<service_description>
After=network.target
StartLimitBurst=5
StartLimitIntervalSec=60

[Service]
Type=simple
User=<appid>
Group=<appid>
WorkingDirectory=/usr/local/<appid>
ExecStart=/usr/local/<appid>/bin/<binary_name>
EnvironmentFile=/usr/local/<appid>/<appid>.env
TimeoutStartSec=30
TimeoutStopSec=10
AmbientCapabilities=CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/lib/<appid> /var/log/<appid>
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
```

**Systemd Directive Reference:**

| Directive | Value | Required | Description |
|---|---|---|---|
| `User` | `<appid>` | ✅ Yes | Run the service as a dedicated non-root user |
| `Group` | `<appid>` | ✅ Yes | Run the service with a dedicated group |
| `WorkingDirectory` | `/usr/local/<appid>` | ✅ Yes | Working directory for the service |
| `NoNewPrivileges` | `true` | ✅ Yes | Prevent privilege escalation |
| `ProtectSystem` | `strict` | ✅ Yes | Mount /usr, /boot, /etc as read-only |
| `ProtectHome` | `true` | ✅ Yes | Hide the /home directory |
| `TimeoutStartSec` | `30` | ✅ Yes | Service startup timeout (seconds) |
| `TimeoutStopSec` | `10` | ✅ Yes | Graceful stop timeout (seconds) |
| `AmbientCapabilities` | `CAP_NET_BIND_SERVICE` | Conditional | Only needed when binding to ports below 1024 |
| `ReadWritePaths` | `/var/lib/<appid> /var/log/<appid>` | ✅ Yes | Explicitly declare writable paths |
| `LimitNOFILE` | `65536` | Recommended | File descriptor limit |
| `StartLimitBurst` | `5` | Recommended | Maximum restart count within the interval |
| `StartLimitIntervalSec` | `60` | Recommended | Restart limit interval (seconds) |

> **⚠️ Important:** The service unit configuration file **must not configure `Restart` and `RestartSec` parameters**. The application's start, stop, and restart lifecycle is uniformly managed by the TOS App Center. Developer-configured auto-restart strategies may conflict with the platform management logic, leading to inconsistent application states. `StartLimitBurst` and `StartLimitIntervalSec` are retained and unaffected.

### 8.13 DEBIAN/control File

#### 8.13.1 Single-Package Mode

In single-package mode, all content is integrated into a single deb package:

```
Package: <appid>
Version: <version>
Architecture: amd64
Section: utils
Priority: optional
Maintainer: Developer Name <your.email@example.com>
Depends: libc6 (>= 2.34), systemd
Description: Brief description
 Detailed description of the application's functionality.
```

**Field Reference:**

| Field | Required | Description |
|---|---|---|
| `Package` | ✅ Yes | Package name. Must match the `package` field in config.ini. |
| `Version` | ✅ Yes | Package version. Must match the `version` field in config.ini. |
| `Architecture` | ✅ Yes | x86_64: `amd64`, aarch64: `arm64`. |
| `Section` | Yes | Package classification (e.g., `utils`, `web`, `net`). |
| `Priority` | Yes | Usually `optional`. |
| `Maintainer` | ✅ Yes | Developer name and email. |
| `Depends` | Recommended | Runtime dependencies. Declare all required system libraries and packages. |
| `Description` | ✅ Yes | First line is a brief description; subsequent lines are a detailed description. See the format rules below. |

**Architecture Field Reference:**

| TOS Platform | DEBIAN/control `Architecture` | Build Target |
|---|---|---|
| x86_64 / amd64 | `amd64` | `x86_64-pc-linux-gnu` |
| aarch64 / arm64 | `arm64` | `aarch64-linux-gnu` |

**Common Errors:**
- Using `x86_64` in DEBIAN/control → must use `amd64`
- Note: TOS 7 only supports 64-bit architectures (x86_64 and aarch64); 32-bit ARM (armhf/armel) is not supported.

**Description Field Format:**
- Line 1: Brief description (max 80 characters, no leading whitespace)
- Subsequent lines: Detailed description (each line must start with a single space, max 80 characters per line)
- Empty lines in the description must contain a space followed by a period: ` .`

Example:
```
Description: Short summary of the software package
 This is the detailed description.
 It can span multiple lines,
 each beginning with a single space.
 .
 This is a new paragraph.
```

#### 8.13.2 Dual-Package Mode

Dual-package mode is suitable for applications with existing generic standard deb packages. The source package remains unchanged, with an additional application data package provided.

**Application Data Package DEBIAN/control:**

```
Package: <appid>
Version: <version>
Architecture: all
Section: utils
Priority: optional
Maintainer: Developer Name <your.email@example.com>
Depends: <package> (>= <version>)
Description: Application data package - <App Name>
 TerraMaster App Center metadata package for <App Name>.
```

> **Naming Note:** The data package name uses `<appid>` (recommended to match config.ini.id), while the source package name uses `<package>` (the original application's default package name). The data package declares its dependency on the source package via the `Depends` field.

**Dual-Package Field Association Rules:**

| Field | Data Package | Source Package | Association Requirement |
|---|---|---|---|
| `Package` | `<appid>` | `<package>` | Data package name recommended to match config.ini.id |
| `Version` | `<version>` | `<version>` | Must be exactly the same |
| `Architecture` | `all` | `amd64`/`arm64` | Data package is usually `all`; source package is the actual architecture |

**config.ini Field Associations:**

| Field | Association Description |
|---|---|
| `config.ini.package` | Must match the **data package** metadata `package` |
| `config.ini.version` | Must match the **data package** metadata `version` |
| `config.ini.system_id` | Must match the **source package** systemd service id |
| `config.ini.path` (when external open) | Must correspond to the nginx configuration file route, resolving to the `<listen_port>` provided by the source package |

**Data Package Internal File Structure:**

```
<appid>.deb
├── DEBIAN/
│   └── control
└── usr/
    └── local/
        └── <appid>/
            ├── config.ini
            ├── <appid>.lang
            ├── images/
            │   └── icons/
            │       └── <appid>.svg
            └── nginx/                    # Only needed for external open
                └── <appid>.conf
```

**Source Package Internal File Structure:**

```
<package>.deb
├── DEBIAN/
│   ├── control
│   ├── preinst
│   ├── postinst
│   ├── prerm
│   └── postrm
└── usr/
    └── local/
        └── <appid>/
            ├── bin/
            │   └── <binary_name>
            └── init.d/
                └── <system_id>.service
```

### 8.14 Lifecycle Scripts

**Script Requirements:**
- All lifecycle scripts must begin with the `#!/bin/bash` shebang
- File encoding: UTF-8
- File permissions: `755` (executable by all, writable by owner)
- All scripts must exit with exit code `0` to indicate success
- Use `set -e` to fail on any error

#### preinst — Before Installation

```bash
#!/bin/bash
set -e

# Create a dedicated user (if it does not exist)
if ! id -u <appid> > /dev/null 2>&1; then
    useradd --system --no-create-home --shell /usr/sbin/nologin <appid> 2>/dev/null || true
fi

# Create data directories
mkdir -p /var/lib/<appid>
chown <appid>:<appid> /var/lib/<appid> 2>/dev/null || true

# Create Unix Socket directory (WebUI Internal Open)
mkdir -p /var/api

exit 0
```

#### postinst — After Installation

```bash
#!/bin/bash
set -e

# Set file permissions
chown -R <appid>:<appid> /usr/local/<appid> 2>/dev/null || true
chown -R <appid>:<appid> /var/lib/<appid> 2>/dev/null || true

# Decompress webui.bz2 if it exists (WebUI applications)
if [ -f /usr/local/<appid>/webui.bz2 ]; then
    cd /usr/local/<appid> && tar -xjf webui.bz2 2>/dev/null || true
fi

# Enable and start the service
systemctl daemon-reload
systemctl enable <system_id>.service
systemctl start <system_id>.service

exit 0
```

#### prerm — Before Removal

```bash
#!/bin/bash
set -e

# Kill all residual processes of the application user (upgrade safety)
pkill -u <appid> 2>/dev/null || true
sleep 1

# Stop and disable the service
systemctl stop <system_id>.service 2>/dev/null || true
systemctl disable <system_id>.service 2>/dev/null || true

exit 0
```

#### postrm — After Removal

```bash
#!/bin/bash
set -e

# Reload systemd
systemctl daemon-reload

# Remove user and data on purge
if [ "$1" = "purge" ]; then
    if id -u <appid> > /dev/null 2>&1; then
        userdel <appid> 2>/dev/null || true
    fi
    rm -rf /var/lib/<appid>
    rm -f /var/api/<appid>.sock
    # Remove nginx configuration
    rm -f /etc/nginx/conf.d/<appid>.conf 2>/dev/null || true
    # Remove systemd service file
    rm -f /etc/systemd/system/<system_id>.service 2>/dev/null || true
    # Reload systemd
    systemctl daemon-reload 2>/dev/null || true
fi

exit 0
```

### 8.15 Packaging and Verification

**Deb Package Filename Naming Convention:**
- Version numbers must not appear in any package filename. The version is exclusively managed through the Release tag and the `version` field in `config.ini`.
- The following naming rules apply strictly based on the packaging hierarchy. Note that `<appid>` and `<platform>` are extracted from `config.ini`. `<platform>` must be either `x86_64` or `aarch64`.

| Packaging Mode | Format | Example |
| :--- | :--- | :--- |
| Single-package | `<appid>_<platform>.deb` | `myapp_x86_64.deb` |
| Dual-package (Archive) | `<appid>_<platform>.tar.gz` | `myapp_x86_64.tar.gz` |
| Dual-package (Data Package) | `<appid>.deb` | `myapp.deb` |
| Dual-package (Source Package) | `<package>.deb` | `myapp-backend.deb` |

**Lintian Verification Requirements:**
- All `Error` (E) level issues must be fixed before submission
- `Warning` (W) level issues should be reviewed; platform-critical warnings must be fixed
- `Info` (I) level issues are informational, optionally addressed
- Only use `lintian --suppress-tags=<tag>` for documented, intentional deviations

**Dual-Package Archive Structure:**
The `.tar.gz` archive must have the following structure:
```
<appid>_<platform>.tar.gz
├── <appid>.deb              # Application data package (recommended to match config.ini.id)
└── <package>.deb            # Deb source package (use the default name, no modification needed)
```
The archive root must not contain subdirectories — `.deb` files must be at the root level of the archive.

**Description:**
- `<appid>.deb`: Deb data package, used for display and operations in the App Center
- `<package>.deb`: Deb source package, used to fulfill deb service functionality

#### Method 1: Single-Package Mode

**Step 1: Build the Deb Package**

```bash
dpkg-deb --build ./<AppRootDir> ./<appid>_<platform>.deb
```

**Step 2: Verify the Package**

```bash
dpkg-deb -c <appid>_<platform>.deb
dpkg-deb -I <appid>_<platform>.deb
lintian <appid>_<platform>.deb  # If lintian is available
```

**Step 3: Test Installation**

```bash
sudo dpkg -i <appid>_<platform>.deb
sudo systemctl status <system_id>
sudo dpkg --purge <appid>    # Uninstall
```

---

#### Method 2: Dual-Package Mode

**Step 1: Build the Deb Source Package**

```bash
dpkg-deb --build ./<AppRootDir> ./<package>.deb
```

**Step 2: Build the Deb Data Package**

```bash
mkdir -p /tmp/<appid>/DEBIAN
mkdir -p /tmp/<appid>/usr/local/<appid>

# Copy TOS 7.0 configuration files to the data package
cp config.ini /tmp/<appid>/usr/local/<appid>/
cp <appid>.lang /tmp/<appid>/usr/local/<appid>/
cp -r images /tmp/<appid>/usr/local/<appid>/
# If external open, also copy nginx configuration
cp -r nginx /tmp/<appid>/usr/local/<appid>/ 2>/dev/null || true

# Create DEBIAN/control (see 8.13.2)
# ...

# Build the data package
dpkg-deb --build /tmp/<appid> ./<appid>.deb
```

**Step 3: Package the Submission Archive**

```bash
tar -czf <appid>_<platform>.tar.gz <appid>.deb <package>.deb
```

**Step 4: Verify, Checksum, and Test Installation**

```bash
# Verify
dpkg-deb -c <package>.deb && dpkg-deb -I <package>.deb
dpkg-deb -c <appid>.deb && dpkg-deb -I <appid>.deb

# Test Installation
sudo dpkg -i <package>.deb
sudo dpkg -i <appid>.deb
sudo systemctl status <system_id>
```

### 8.16 Complete Examples

#### Example 1: WebUI Internal Open — Timer Application

**Application Overview:**
- ID: `tmrtimer`
- Type: Deb Application / WebUI Internal Open (iframe)
- Runtime: Python3 HTTP Service (Unix Socket Mode)
- Frontend: Static HTML timer page

**Directory Structure:**

```
/usr/local/tmrtimer/
├── config.ini
├── tmrtimer.lang
├── webui.bz2
├── images/
│   └── icons/
│       └── tmrtimer.svg
└── init.d/
    └── tmrtimer.service
```

**config.ini:**

```json
{
  "id": "tmrtimer",
  "icon": "/images/icons/tmrtimer.svg",
  "exec": true,
  "version": "1.0.0",
  "category": ["Utilities"],
  "platform": "x86_64",
  "system_id": "tmrtimer",
  "package": "tmrtimer",
  "application_type": "deb",
  "path": "/tmrtimer/",
  "type": "iframe",
  "resize": true,
  "maxmin": true
}
```

**DEBIAN/control:**

```
Package: tmrtimer
Version: 1.0.0
Architecture: amd64
Section: utils
Priority: optional
Maintainer: ljw <ljw@example.com>
Depends: python3 (>= 3.10), systemd
Description: Timer application
 A simple timer tool supporting start, pause, and reset functionality.
```

---

#### Example 2: WebUI External Open — Weather Application

**Application Overview:**
- ID: `weather`
- Type: Deb Application / WebUI External Open (new tab)
- Runtime: Go backend service, port 16688
- Frontend: Static weather page

**Directory Structure:**

```
/usr/local/weather/
├── config.ini
├── bin/
│   └── weather                  # Go binary
├── weather.lang
├── webui.bz2
├── images/
│   └── icons/
│       └── weather.svg
├── nginx/
│   └── weather.conf
└── init.d/
    └── weather-system.service
```

**config.ini:**

```json
{
  "id": "weather",
  "icon": "/images/icons/weather.svg",
  "exec": true,
  "version": "1.0.001",
  "category": ["Utilities"],
  "platform": "x86_64",
  "system_id": "weather-system",
  "package": "weather-package",
  "application_type": "deb",
  "path": "/weather/",
  "open_path": true
}
```

**nginx/weather.conf:**

```nginx
location /weather/ {
    proxy_pass http://127.0.0.1:16688/;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

---

#### Example 3: No UI Service — Data Sync Service

**Application Overview:**
- ID: `datasync`
- Type: Deb Application / No UI Service
- Runtime: Python3 background service

**Directory Structure:**

```
/usr/local/datasync/
├── config.ini
├── bin/
│   └── datasync                  # Executable
├── datasync.lang
├── images/
│   └── icons/
│       └── datasync.svg
└── init.d/
    └── datasync.service
```

**config.ini:**

```json
{
  "id": "datasync",
  "icon": "/images/icons/datasync.svg",
  "exec": true,
  "version": "1.0.0",
  "category": ["Utilities"],
  "platform": "x86_64",
  "system_id": "datasync",
  "package": "datasync",
  "application_type": "deb"
}
```

### 8.17 Dual-Package Mode Specification

In dual-package mode, the original application package (deb source package) remains unchanged, with an additional application data package (deb data package) provided. The deb data package contains the configuration files required by TOS 7.0, and both are packaged into a tar.gz archive for submission.

**Data Package Naming Rule:** `<appid>.deb` (recommended to match config.ini.id, all lowercase)

**Data Package Internal File Structure:**

```
<appid>.deb
├── DEBIAN/
│   ├── control
│   └── postinst
└── usr/
    └── local/
        └── <appid>/
            ├── config.ini
            ├── <appid>.lang
            ├── images/
            │   └── icons/
            │       └── <appid>.svg
            ├── webui.bz2             # Required for WebUI applications
            └── nginx/                # Only needed for external open
                └── <appid>.conf
```

**Data Package DEBIAN/postinst:**

```bash
#!/bin/bash
set -e

# Ensure correct configuration file permissions
chmod 644 /usr/local/<appid>/config.ini 2>/dev/null || true
chmod 644 /usr/local/<appid>/<appid>.lang 2>/dev/null || true
chmod 644 /usr/local/<appid>/images/icons/<appid>.svg 2>/dev/null || true

exit 0
```

**Data Package config.ini Notes:**
- The `icon` path is fixed as `/images/icons/<appid>.svg` (matching the data package icon filename)
- `id` must exactly match the `id` field in config.ini
- `version` must exactly match the `Version` in the source package metadata
- `application_type` must be set to `deb-TarGz`
- `package` must match the `Package` field in the data package's DEBIAN/control

**Source Package Internal File Structure:**

```
<package>.deb
├── DEBIAN/
│   ├── control
│   ├── preinst
│   ├── postinst
│   ├── prerm
│   └── postrm
└── usr/
    └── local/
        └── <appid>/
            ├── bin/
            │   └── <binary_name>
            ├── depends/             # If dependencies exist
            │   ├── bin/
            │   ├── lib/
            │   └── ...
            └── init.d/
                └── <system_id>.service
```

**Submission Archive Structure:**

```
<appid>_<platform>.tar.gz
├── <appid>.deb              # Deb data package
└── <package>.deb            # Deb source package
```

**GitHub Repository Data Structure (Dual-Package Mode):**

```
<appid>_<platform>.tar.gz
├── <appid>.deb              # Application data package
└── <package>.deb            # Deb source package (original application package)
```

**Dual-Package Mode Mandatory Constraints:**

| Constraint | Description | Violation Consequence |
|---|---|---|
| **Installation Order** | The source package (`<package>.deb`) must be installed first, followed by the data package (`<appid>.deb`). The data package depends on the source package. | Installation failure |
| **Strict Version Consistency** | The `Version` of both packages must be exactly the same. Any version mismatch triggers automatic rejection. | Automatic rejection |
| **No Binaries in Data Package** | The data package (`<appid>.deb`) **must not contain any executable binary files**, compiled code, or system-specific libraries. Only configuration files, icons, language files, nginx configurations, and other static resources are allowed. | Intercepted at the automatic validation stage before submission, without entering manual review. |
| **Data Package Architecture** | The data package `Architecture` must be `all`, and must not be `amd64` or `arm64`. Configuration files are architecture-independent. | Automatic rejection |
| **Source Package Independence** | The deb source package must be independently installable on the TOS 7.0 system using the `dpkg -i` command. | Installation failure |
| **Dependency Declaration** | The data package's `Depends` field must include the source package name, and specifying the version is recommended. | Rejection |
| **Systemd Service File Ownership** | The systemd service file (`.service`) must be in the source package; the data package must not contain it. The data package is only responsible for TOS platform configuration and display. | Rejection |
| **Uninstallation Order** | When uninstalling, remove the data package first, then the source package. Uninstalling the data package does not affect the source package's runtime data. | — |

**Installation and Uninstallation Process:**
```bash
# Installation order
sudo dpkg -i <package>.deb                    # 1. Install deb source package first
sudo dpkg -i <appid>.deb                      # 2. Then install deb data package

# Uninstallation order
sudo dpkg --remove <appid>                    # 1. Uninstall data package first
sudo dpkg --purge <package>                   # 2. Then uninstall source package (`<package>` is the `Package` field value declared in the source package's DEBIAN/control, which is usually different from the data package's `<appid>`)
```

---

← [Previous: Application Types](07_Application_Types.md) &nbsp;&nbsp;|&nbsp;&nbsp; [Next: Docker Development](09_Docker_Development.md) → &nbsp;&nbsp;|&nbsp;&nbsp; [📖 Back to Contents](../README.md)
