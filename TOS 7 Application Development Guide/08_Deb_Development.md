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

- **Version Display (not a consistency requirement):** the platform does **not** require the two packages to carry the same `Version`, and does not compare them. The version shown in the App Center always comes from the `version` field in `config.ini` — make sure that field states the version you intend to release.
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
│       └── <app_id>.svg       # 【Required】Application icon
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

**Physical Deb Payload Layout (Critical):**

The App Center metadata parser reads `config.ini`, the language file, and the icon from **inside the deb's `data.tar`**, at the path `./usr/local/<appid>/`. It does **not** read them from the deb root.

Therefore the deb payload itself must be laid out as follows — the metadata files live under `usr/local/<appid>/`, not beside `DEBIAN/`:

```
<appid>.deb                      # single-package mode
├── DEBIAN/
│   ├── control
│   └── ...
└── usr/
    └── local/
        └── <appid>/
            ├── config.ini        # 【Required】parser reads it here
            ├── <appid>.lang      # 【Required】parser reads it here
            ├── images/
            │   └── icons/
            │       └── <appid>.svg   # 【Required】parser reads it here
            ├── bin/
            │   └── <binary_name>
            ├── init.d/
            │   └── <system_id>.service
            └── ...
```

> ⚠️ **Common fatal mistake:** placing `config.ini`, `<appid>.lang`, or `images/` at the deb root (next to `DEBIAN/`). The parser looks under `usr/local/<appid>/` inside `data.tar`, finds nothing, and the submission fails with a metadata parse error (`application_type` unresolvable) — regardless of how correct the archive format is.

> Dual-package mode: the **data package** (`<appid>.deb`) must carry these files at `usr/local/<appid>/` (see Section 8.17); the source package only carries binaries and lifecycle files.

**Mandatory Correspondences:**

```text
config.ini.id              == <app_id>
config.ini.package         == Package in DEBIAN/control
config.ini.system_id       == systemd service unit ID (without .service suffix)
config.ini.icon            == "/images/icons/<app_id>.svg"
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
>
> **Note:** The directory trees in 8.3.1–8.3.3 are **deb payload paths** — inside the `.deb`, these files must live under `./usr/local/<app_id>/` (see Section 8.2 for the physical layout requirement).

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
│       └── <app_id>.svg
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
  "icon": "/images/icons/<app_id>.svg",
  "publisher": "publisher name",
  "exec": true,
  "version": "<app_version>",
  "low_version": "<low_version>",
  "category": ["Utilities"],
  "platform": "x86_64",
  "user": "<app_user>",
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
9. Frontend requests to backend interfaces must go through the platform proxy path, with the fixed format `/v2/proxy/<app_id>/<api_name>`.
10. Frontend requests must carry **both** the platform `Cookie` header and the `X-Csrf-Token` header. This is the **only** compliant authentication channel — a missing header means the request is unauthenticated (see 8.9 / 8.10); a `Cookie`-only request is not accepted.

**Socket File Specification:**
- Permission mode: `0660` (owner and group read/write)
- Owner: `<appid>:<appid>` (matches the service user)
- Supports HTTP keep-alive connections
- Supports at least 100 concurrent connections
- Idle connection timeout: 30 seconds

11. Frontend requests to backend interfaces must go through the platform proxy path: `/v2/proxy/<app_id>/<api_name>` (see 8.9).
12. Frontend requests must carry **both** the `Cookie` and the `X-Csrf-Token` header, in the exact form defined in 8.10 — there is no alternative or `Cookie`-only channel.

**CORS and Preflight Request Configuration:**
The backend must handle CORS preflight requests (OPTIONS method) for the platform proxy. Allow the following:
- Origin: TOS Web origin
- Methods: GET, POST, PUT, DELETE, OPTIONS
- Headers: Content-Type, X-Csrf-Token, Cookie
- Credentials: true

#### 8.3.2 WebUI External Open (New Tab)

For applications where the backend is a local executable service, the frontend is a static WebUI, opened in a new browser tab, outside the TOS desktop iframe.

**Access permission:** only administrators can open an application page by default; an administrator may grant a non-administrator user access to the application. Non-administrator users have **no permission for the App Center module**, so their only entry point is the application icon on the desktop (shown after the administrator grants access). Do not assume that a non-administrator can reach the application through the App Center, and do not design an entry point that bypasses the platform. Authentication and permission handling are described in 8.9 and 8.10.

**Two mutually exclusive access modes.** Choose the mode according to how the application can be reached — through its own listening port, or through the platform socket/nginx route:

| Access mode | Address published in `config.ini.path` | Platform authentication | Required extra files |
|---|---|---|---|
| **Port listening** (§8.3.2.1) | `http://${ip}:<port>` — the application's own listening port | **Not available** — traffic never passes through the platform, so the platform cannot authenticate it | Standard payload only |
| **.sock listening** (§8.3.2.2) | `/<app_id>/` — route resolved by nginx | **Available** — `Cookie` + `X-Csrf-Token` (see 8.9 / 8.10) | `nginx/<app_id>.conf`, `webui.bz2` |

**Directory Structure:**

```
/usr/local/<app_id>/
├── config.ini
├── bin/
│   └── <binary_name>
├── <app_id>.lang
├── webui.bz2                     # 【Required for .sock access】Frontend page archive (see 8.3.2.2)
├── images/
│   └── icons/
│       └── <app_id>.svg
├── nginx/
│   └── <app_id>.conf             # 【Required for .sock access】Nginx configuration file (see 8.3.2.2)
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
  "icon": "/images/icons/<app_id>.svg",
  "publisher": "publisher name",
  "exec": true,
  "version": "<app_version>",
  "low_version": "<low_version>",
  "category": ["Utilities"],
  "platform": "x86_64",
  "user": "<app_user>",
  "system_id": "<system_id>",
  "package": "<deb_package_name>",
  "application_type": "deb",
  "path": "http://${ip}:8686",
  "open_path": true
}
```

**Core Requirements:**

1. `open_path` must be `true`.
2. The `path` field must resolve to the externally provided HTTP interface. Deb applications accept **both** forms: the full URL `http://${ip}:<port>` and the route form `/<app_id>/`. The nginx configuration file (see below) maps that address to the application's Unix socket or to its backend listening port.
3. The `.sock` access mode requires an nginx configuration file `<app_id>.conf` in the package, whose filename must correspond to `config.ini.id` (see 8.3.2.2); the port access mode does not use nginx.
4. The backend must be reachable either through its own listening port `<listen_port>` (port mode, §8.3.2.1) or through the application socket `/var/api/<app_id>.sock` (`.sock` mode, §8.3.2.2).
5. The deb package must contain an executable program, located at `/usr/local/<app_id>/bin/<binary_name>`.
6. The `config.ini.package` field specification must strictly conform to the Debian package `package` specification.

##### 8.3.2.1 Port Listening Access

In this mode the application listens on its own port `<listen_port>` and the address published in `config.ini.path` is `http://${ip}:<port>`. **Every route is resolved by that port**: the application page itself and all of its functional requests are sent directly to `http://<ip>:<port>`, without passing through the platform.

Because the traffic never traverses the platform proxy, **the platform cannot take part in authentication for this mode** — the platform session, the `Cookie` / `X-Csrf-Token` channel described in 8.9, and the platform permission model do **not** apply to the page served on the application port. The application itself must implement its own access control for that port (for example its own login or an explicit restriction to trusted networks); do not claim that the platform validates the session for a port-mode page.

**Port Listening Rules:**
- **Must not** occupy system reserved ports (22, 80, 443, 445, 3306, 5050, 5432, 6379, 8181, 8443) — full list: Appendix B of Chapter 20 / §12.8
- Recommended port range: 8000-19999

##### 8.3.2.2 .sock Listening Access

In this mode the application service is exposed through the platform socket and the platform nginx route, and the address published in `config.ini.path` is the route form `/<app_id>/`:

- **Page address:** `http://<ip>:8181/<app_id>/` — the application page is reached through the platform nginx on port 8181, which requires the nginx configuration file `nginx/<app_id>.conf` described below.
- **API address:** application interfaces are reached through the platform function route `http://<ip>:8181/v2/proxy/<app_id>/`.
- **`webui.bz2` is mandatory** in this mode: the frontend page archive is served by the platform.
- **Platform authentication applies:** requests must carry the platform `Cookie` + `X-Csrf-Token` headers. This is the only compliant authentication channel; the full specification is in **8.9** (request path) and **8.10** (headers and session handling).

**Nginx Configuration File Template:**

The nginx configuration file resolves the access address declared in the `config.ini` `path` field to the application's Unix socket (`/var/api/<app_id>.sock`) or to its backend listening port.

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

> **Portal Route and `proxy_pass` Policy:**
> - **Compliant form — portal block without `proxy_pass`:** the portal block `location /<app_id>/` may contain only `proxy_http_version` and the `proxy_set_header` directives. This is compliant when the application ships its own frontend Web panel and directly provides the application address, and the service is reachable through the application socket (`/var/api/<app_id>.sock`) — the platform's sibling block `location ^~ /v2/proxy/<app_id>/` proxies to `unix:/var/api/<app_id>.sock`, so the portal block itself does not need to forward traffic. In this form the absence of `proxy_pass` is **not** a defect and must not block review.
> - **Compliant form — portal block with `proxy_pass`:** the template above remains valid; the address declared in the `config.ini` `path` field is resolved to the backend listening port.
> - **Optional improvement:** adding `proxy_pass http://127.0.0.1:<listen_port>/;` to a portal block that does not need it is an **optional improvement**, not a review requirement, and must never be used as a ground for rejection; it is recorded as an advisory item in **12 §12.10 Optional Improvements (Advisory)**. The same calibration applies to all comparable applications (for example GitBucket and Sonarr).
> - See 8.11 for the same policy and 16.2 for the corresponding review checklist entry.

**Nginx Configuration Management Requirements:**
- Configuration file permissions: `644` (owner read/write, group and others read-only)
- Configuration file must be placed at `/usr/local/<app_id>/nginx/<app_id>.conf`
- The platform Nginx `include` directive loads configurations in alphabetical order; port conflicts between applications are resolved by using unique ports — two applications cannot share the same port
- Log rotation: Nginx access/error logs are managed by the platform; do not write your own nginx logs
- Must not include `server {}` blocks; only use `location /<app_id>/ {}` blocks
- **Reserved `tos` prefix:** the configuration file name `<app_id>.conf` and the route prefix `location /<app_id>/` are both derived from the App ID and must not start with `tos` — the platform reserves the `tos` prefix in the nginx namespace, so a `tos`-prefixed name collides with the platform's own nginx entries and the application page cannot be opened (see 8.4.2 and 8.11)

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
│       └── <app_id>.svg
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
  "icon": "/images/icons/<app_id>.svg",
  "publisher": "publisher name",
  "exec": true,
  "version": "<app_version>",
  "low_version": "<low_version>",
  "category": ["Utilities"],
  "platform": "x86_64",
  "user": "<app_user>",
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

> **Scope of this chapter (Deb and Docker):** the `config.ini` / `app.lang` / icon specifications in §8.4–§8.6 apply to **both** Deb and Docker applications. The field dictionary in §8.4.2 is the common field dictionary for both types; the only field with no Deb counterpart, `depend`, is Docker-only and is defined in **§9.2.1**. Docker-specific differences are described in Chapter 9.

> **Important:** The file extension is `.ini`, but the content must be in **strict JSON format**. Do not add comments, use single quotes, trailing commas, or any syntax errors.

> **Format Note:** The `.ini` file extension is a company historical convention (maintaining filename consistency with the legacy configuration system), but the parser processes it as JSON format. Developers must write using JSON syntax, otherwise automatic validation will fail.

#### 8.4.1 Standard Template

Below is the config.ini standard template, divided into three independent examples by application subtype. Developers should choose the corresponding template based on their application type. **Choose one of the three; do not mix.**

> **Dependency scope:** the three templates below are Deb templates and therefore contain no `depend` line — Deb applications declare dependencies in the `Depends` field of `DEBIAN/control` (see [Chapter 5 · ABI Compatibility](05_ABI_Compatibility.md#52-declaring-runtime-dependencies) and §8.13), **not** in `config.ini`. The `config.ini` `depend` field applies to **Docker applications only** (field definition in §9.2.1, package structure in Chapter 9).

> **Must Read: Field Mutual Exclusion Relationships**
>
> | Application Type | Required Fields | Forbidden Fields |
> |---|---|---|
> | WebUI Internal Open (iframe) | `type: "iframe"` + `path: "/<app_id>/"` | `open_path` |
> | WebUI External Open (New Tab) | `open_path: true` + `path: "http://${ip}:<port>"` | `type` |
> | No UI Service | — | `type`, `open_path`, `path` |

---

**Template 1: WebUI Internal Open (iframe Embedding)**

```json
{
  "id": "dev-myapp",
  "icon": "/images/icons/dev-myapp.svg",
  "publisher": "publisher name",
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
  "relation": [],
  "platform": "x86_64",
  "official": "https://example.com",
  "application_type": "deb",
  "system_id": "dev-myapp",
  "package": "dev-myapp",
  "user": "dev-myapp",
  "allow_open_in_mobile": false
}
```

**Template 2: WebUI External Open (New Tab)**

```json
{
  "id": "dev-myapp",
  "icon": "/images/icons/dev-myapp.svg",
  "publisher": "publisher name",
  "exec": true,
  "open_path": true,
  "path": "http://${ip}:8686",
  "help": "https://example.com/docs",
  "version": "1.0.0",
  "recommend": false,
  "beta": false,
  "low_version": "TOS7.0",
  "category": ["Utilities"],
  "relation": [],
  "platform": "x86_64",
  "official": "https://example.com",
  "application_type": "deb",
  "system_id": "dev-myapp",
  "package": "dev-myapp",
  "user": "dev-myapp",
  "allow_open_in_mobile": false
}
```

**Template 3: No UI Service**

```json
{
  "id": "dev-myapp",
  "icon": "/images/icons/dev-myapp.svg",
  "publisher": "publisher name",
  "exec": true,
  "help": "https://example.com/docs",
  "version": "1.0.0",
  "recommend": false,
  "beta": false,
  "low_version": "TOS7.0",
  "category": ["Utilities"],
  "relation": [],
  "platform": "x86_64",
  "official": "https://example.com",
  "application_type": "deb",
  "system_id": "dev-myapp",
  "package": "dev-myapp",
  "user": "dev-myapp",
  "allow_open_in_mobile": false
}
```

#### 8.4.2 Field Reference

> **Field ownership:** this table is the `config.ini` field dictionary shared by both application types; a field whose Required column says "for Deb applications" or "for Docker applications" applies to that type only (`system_id` / `package` are Deb, `compose_project` is Docker). `depend` is the single Docker-only field **not** listed here — it is defined in **§9.2.1**, and Deb applications never declare it. Icon and `app.lang` specifications are in §8.6 / §8.5 and are shared by both types.
>
> **No `depend` for Deb:** Deb applications do not declare dependencies through `config.ini` — dependencies are declared in the `Depends` field of `DEBIAN/control` (see Chapter 5 · §5.2 and §8.13). The `depend` field exists for Docker applications only (§9.2.1).

| Field | Type | Required | Description | Detailed Description |
|---|---|---|---|---|
| `id` | string | ✅ Yes | Application unique identifier | Globally unique on the platform; must not duplicate any listed application. Character set: lowercase letters (a-z), digits (0-9), and hyphens (-). Must start with a letter. Maximum length: 50 characters. Recommended format: developer-account-identifier-app-business-name or reversed-domain-app-name. Examples: dev-admin-monitor, com-douyin-service. Prohibited pure generic system keywords: docker, bin, var, api, usr, root, admin, system, service, etc. **Reserved prefix — must not start with `tos`:** the platform reserves the `tos` prefix in the nginx route/command namespace, so an `id` such as `tos-log-server` collides with the platform's own nginx entries and the application page cannot be opened normally (see 8.11). Cannot be modified after creation. |
| `icon` | string | ✅ Yes | Icon path | Relative path within the repository. Must follow the `/images/icons/<id>.svg` format. The icon file must exist at this path. |
| `publisher` | string | ✅ Yes | Publisher name | The developer or organization name displayed in the App Center. Example: `"Kevin"`, `"LinuxServer.io"`. |
| `path` | string | Conditionally Required | Application access address | **The `path` field is mutually exclusive by scenario: iframe uses `/<app_id>/`; external open uses `http://${ip}:<port>`; no UI is left empty.** For Deb applications **both** forms are accepted: the full URL `http://${ip}:<port>` (e.g., `http://${ip}:8686`) and the route form `/<app_id>/`. Using the `${ip}` placeholder is recommended — the system automatically replaces it with the TNAS LAN IP. **Hardcoding a fixed IP or domain is prohibited.** Non-80/443 ports: `http://${ip}:<port>`. WebUI Internal Open (iframe): `/<app_id>/`. No UI application: set to `""` or omit this field. Required when `exec=true`. The desktop entry opens the resolved access address — for example `http://1.2.3.4/abc/`. |
| `exec` | bool | ✅ Yes | Whether there is an executable service | Whether the application supports start/stop operations. `true`: App Center displays start/stop buttons; `false`: display only, no lifecycle control. |
| `open_path` | bool | Conditionally Required | Whether to open in a new tab | Controls how the application is opened: `true` = new browser tab; `false` or omitted = TOS desktop embedded iframe. External open applications must set this to `true`; **Docker applications with a UI must also set it to `true`** (with `path` set to `http://${ip}:<port>`) — a Docker package is always shown in a new browser tab, and omitting the field leaves it opening as an embedded iframe whose page cannot render (rejection code `tool-C23`; see 9.3 / 16.1 / Appendix N). **Mutually exclusive with `type`; must not be set simultaneously.** |
| `type` | string | Conditionally Required | Application open type | Set to `"iframe"` for Deb WebUI Internal Open (iframe embedding). **⚠️ Mutually exclusive with `open_path`; the two must not be set simultaneously.** Deb external-open and Docker applications use `open_path` instead. No UI applications do not set this field. |
| `resize` | bool | No | Whether the window is resizable | Only effective when `open_path=false`. Controls whether the application popup can be resized. Default `false`. |
| `maxmin` | bool | No | Whether the window can be maximized/minimized | Only effective when `open_path=false`. Controls whether the application popup supports maximize/minimize. Default `false`. |
| `width` | int | No | Default window width | Only effective when `open_path=false`. The width of the application page when opened, default 1180. |
| `height` | int | No | Default window height | Only effective when `open_path=false`. The height of the application page when opened, default 680. |
| `help` | string | ✅ Yes | Help documentation URL | Help documentation, wiki, or community tutorial link of the application. **Required:** every submission must provide the application's help / documentation URL — it is one of the fields the platform validates for presence and non-emptiness (id / icon / publisher / exec / version / help / category / platform / application_type / user). Users rely on it to find usage documentation, so it must not be left empty. |
| `version` | string | ✅ Yes | Application version number, displayed in the App Center | Must follow the 4.2 Version Number Specification (character rules, numeric comparability, and must be greater than the previously published version) — a specification requirement upheld at manual review: the platform's automated validation does not inspect version numbers at all (agent-api §6.5.6). A digits-and-dots value that increases with every release (e.g. `"1.0.0"`, `"2.3.1"`) also lets the App Center detect updates — see 4.2 Version Number Specification. |
| `recommend` | bool | ✅ Yes | Whether the application is recommended | `recommend` — Recommendation flag, uniformly set by platform operations after review based on application quality. **Developers must always set this to `false` when submitting.** This field is managed by the platform; developers must not modify it to `true` on their own. |
| `beta` | bool | ✅ Yes | Whether it is a beta version | `true` = beta version, only shown to test users; `false` = stable version, shown to all users. |
| `low_version` | string | No | Minimum supported TOS version | Minimum supported TOS system version. Specifies the minimum TOS version on which the application can run normally. This is NOT the application's own version. **Optional:** leaving it empty is allowed and does not block submission; when provided it must be TOS 7.0 or higher. Use a plain numeric version in MAJOR.MINOR or MAJOR.MINOR.PATCH format (e.g. 7.0, 7.1); an empty value means the application declares no minimum TOS version. |
| `category` | []string | ✅ Yes | Application categories | Up to 3 categories, selected from the official category list (see [Appendix A](20_Appendix.md#appendix-a-application-categories)). **The first category is the primary category** — it determines the default display section of the application. Arrange from most specific to most general. Exceeding the category limit results in rejection. |
| `relation` | []string | No | Related application list | Application IDs displayed in the "Related Applications" module on the application details page. No mandatory dependency, display association only. No relations: `[]`. |
| `platform` | string | ✅ Yes | Target architecture | `"x86_64"` or `"aarch64"`. Multi-architecture requires separate submissions. |
| `official` | string | No | Official website | Link to the application's official website. Leave empty if none. |
| `application_type` | string | ✅ Yes | Application package type. Only two values are supported: `deb` and `docker` (`deb-TarGz` does not exist and is not accepted) | Deb applications: `"deb"`; Docker applications: `"docker"` |
| `system_id` | string | Conditionally Required | Systemd service name | **Required for Deb applications.** Must match the systemd service filename. Leave empty for Docker applications. |
| `package` | string | Conditionally Required | Deb package name | **Required for Deb applications.** Must match the `Package` field in DEBIAN/control. Leave empty for Docker applications. |
| `compose_project` | string | Conditionally Required | Docker Compose project name | **Required for Docker applications.** Specifies the name used when creating the docker-compose project; must conform to Docker Compose project naming conventions (only lowercase letters, digits, hyphens, and underscores). Leave empty for Deb applications. Example: `"myapp-docker"`.<br>⚠️ **Note:** Although Docker Compose allows underscores, it is recommended that `compose_project` use the same character set as `id` to reduce confusion. `id` only supports lowercase letters, digits, and hyphens (no underscores). If both use the same string, do not use underscores in `compose_project` either. |
| `user` | string | ✅ Yes | Runtime user | The system user under which the application runs. After specification, a dedicated user is automatically created (e.g., `"jellyfin"`). Deb applications must match the systemd service `User` field. **Using the root user is strictly prohibited.** |
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

1. **IP Placeholder**: The `path` field may use `${ip}` (e.g., `http://${ip}:8686`); hardcoding a fixed IP or domain is prohibited. Deb applications also accept the route form `/<app_id>/`.
2. **JSON Syntax**: Must be valid JSON. Comments (`//` or `/* */`), single quotes, or trailing commas are prohibited.
3. **ID Uniqueness**: `id` must be globally unique. Duplicate IDs will be rejected.
4. **Version Incrementation**: The version number must be greater than every previously published version of the same application, as required by the 4.2 Version Number Specification. The platform's automated validation does not inspect version numbers at all (agent-api §6.5.6) — this rule is a specification requirement upheld at manual review (see 16 §16.1 / §16.2) — while the App Center detects updates by comparing version numbers numerically, so a version that is not greater than the installed one will not reach existing users as an update.
5. **Category Limit**: Each application may have at most 3 categories.
6. **TOS Version (`low_version`, optional)**: `low_version` is **optional** — leaving it empty is allowed and does not block submission; when provided, its value must be TOS 7.0 or higher, written as plain numbers in MAJOR.MINOR or MAJOR.MINOR.PATCH form (e.g. `7.0`). An empty value means the application declares no minimum TOS version requirement.
7. **Field Consistency**: `system_id` must match the systemd service filename, and `package` must match the `Package` field in DEBIAN/control. Keep the `version` field consistent between config.ini and DEBIAN/control — see 4.2.2.
8. **Reserved `tos` Prefix**: `id` must not start with `tos`. The platform reserves the `tos` prefix in the nginx route/command namespace — an `id` starting with `tos` (e.g. `tos-log-server`) collides with the platform's own nginx entries, and the application page cannot be opened normally. The same prohibition applies to every nginx-related name derived from the App ID: the configuration file name `nginx/<app_id>.conf`, the route prefix `location /<app_id>/`, and any nginx command named after the App ID (see 8.4.2 and 8.11). Because `id` cannot be modified after creation, fix the name before publishing (see 19 §19.1).
9. **Help Documentation (`help`, required)**: `help` is a **required** field — every submission must provide the application's help documentation, wiki, or community tutorial URL, which belongs to the config.ini fields the platform validates for presence and non-emptiness (agent-api §6.5.6). Users rely on it to find usage instructions.

**`path` Field Value Quick Reference Table:**

| Application Type | Opening Method | `path` Value | Example |
|---|---|---|---|
| Deb WebUI Internal Open | iframe embedding | `/<app_id>/` | `"/tmrtimer/"` |
| Deb WebUI External Open | New tab | `http://${ip}:<port>` | `"http://${ip}:16688"` |
| Docker Application | New tab | `http://${ip}:<port>` | `"http://${ip}:8080"` |
| No UI Service | No frontend | Omit or `""` | — |

> **Note:** Deb WebUI internal open (iframe) uses the site-relative path `/<app_id>/`. Deb WebUI external open and Docker applications use the full URL format `http://${ip}:<port>`, resolved through the nginx route (see 8.4.3 and 8.13.2). The difference between internal and external open lies in the `open_path` field: internal open `open_path=false` (default), external open `open_path=true`.

> **Reserved Fields:** The following field names are reserved for future platform use. Do not use them in custom config.ini: `host_network`, `container_runtime`, `sandbox`, `auto_update`, `upstream_url`, `license`, `min_memory`, `min_cpu`, `min_disk`. Using reserved fields may lead to future compatibility issues and rejection.

---

### 8.5 Language File — app.lang

The language file provides multilingual display support for the App Center. The system automatically loads the corresponding language based on the user's device language.

#### 8.5.1 Supported Languages

**Write `app.lang` against the full 26-language set listed below.** Provide one section per language, using exactly these tags — they are the complete set the App Center recognises. Supersets are allowed.

**Required coverage:** an application released for TOS 7.0 must cover the first 14 languages; an application released for TOS 7.1 and later must cover all 26. **Shortfall is not a rejection ground:** an `app.lang` with fewer sections than the required set is **not** rejected — review only reminds the developer to complete the set (see 8.5.9 and 16 §16.1 / §16.2). Bear in mind that a language you omit hides the application from that language environment in the App Center until it is installed.

> **Version scope:** TOS 7.0 supports **14 system languages** — the first 14 rows of the table below (`zh-cn` … `pt-pt`) — and an application released for TOS 7.0 is required to adapt those 14. **From TOS 7.1 the required set is 26 languages**, i.e. the complete table below. The tags and their order in this table are authoritative: use exactly these tags, one section per language.

| # | Tag | Language | Required from |
|---|---|---|---|
| 1 | `zh-cn` | Simplified Chinese | TOS 7.0 |
| 2 | `zh-hk` | Traditional Chinese | TOS 7.0 |
| 3 | `en-us` | English | TOS 7.0 |
| 4 | `ko-kr` | Korean | TOS 7.0 |
| 5 | `ja-jp` | Japanese | TOS 7.0 |
| 6 | `de-de` | German | TOS 7.0 |
| 7 | `fr-fr` | French | TOS 7.0 |
| 8 | `it-it` | Italian | TOS 7.0 |
| 9 | `es-es` | Spanish | TOS 7.0 |
| 10 | `hu-hu` | Hungarian | TOS 7.0 |
| 11 | `pl-pl` | Polish | TOS 7.0 |
| 12 | `tr-tr` | Turkish | TOS 7.0 |
| 13 | `ru-ru` | Russian | TOS 7.0 |
| 14 | `pt-pt` | Portuguese | TOS 7.0 |
| 15 | `cs-cz` | Czech | TOS 7.1 |
| 16 | `da-dk` | Danish | TOS 7.1 |
| 17 | `nl-nl` | Dutch | TOS 7.1 |
| 18 | `nb-no` | Norwegian | TOS 7.1 |
| 19 | `sv-se` | Swedish | TOS 7.1 |
| 20 | `el-gr` | Greek | TOS 7.1 |
| 21 | `ro-ro` | Romanian | TOS 7.1 |
| 22 | `th-th` | Thai | TOS 7.1 |
| 23 | `vi-vn` | Vietnamese | TOS 7.1 |
| 24 | `id-id` | Indonesian | TOS 7.1 |
| 25 | `ar-sa` | Arabic | TOS 7.1 |
| 26 | `he-il` | Hebrew | TOS 7.1 |

**Must:** in every language section you include, `name` / `auth` / `descript` must not be empty; `release_note` / `important` may be empty. An untranslated language may be filled with the English text — a blank or punctuation-only value is not accepted.

**What a missing language means in practice** (details in 8.5.9): an application whose `app.lang` has no section for the current system language is **not displayed** in the App Center under that language, even if it has already been published; applications already installed on the device are always displayed and are unaffected by system-language switching.

> **Background note — why 26 languages?** TOS 7.0 shipped 14 system languages, and the requirements at that time asked for those 14 only. TOS 7.1 adds 12 more, so this documentation now describes one 26-language set that serves both TOS versions — simply write against the table above without worrying about version differences. Applications built with the earlier 14 languages still install and run exactly as before; they are only displayed in those 14 language environments. When such an application is updated, completing the 26-language set is recommended so that it also becomes discoverable in the 12 newly supported language environments.

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

> **Non-empty rule (applies to every language section that is included):** `name` / `auth` / `descript` **must not be empty** — blank, whitespace-only or punctuation-only values are not accepted. `release_note` / `important` **may be empty**. The required fields need **not** all be translated: an untranslated language must be filled with the **English** content rather than left blank. Supersets are allowed — submitting more than the 26 languages listed in 8.5.1 is accepted.

#### 8.5.4 Rules

1. Write `app.lang` against the full 26-language set defined in 8.5.1; supersets are allowed. Required coverage follows the version scope in 8.5.1 (TOS 7.0: the first 14; TOS 7.1 and later: all 26), while **a shortfall is not a rejection ground** — it only costs reach in the omitted language environments (see 8.5.9). For every language section that is included, untranslated entries must be filled with English content — **leaving an included section's values blank is prohibited**. An `app.lang` with fewer than 26 language sections is not rejected; review only reminds the developer to complete the 26-language set (see 8.5.9).
2. File encoding must be **UTF-8 without BOM**.
3. The `descript` field semantics must be consistent across all languages.
4. If the application name is a universal language name (not translated), the same value may be used for `name` across all languages. If the application name itself is a proper noun (such as a brand name or product name), the same name may be used across all languages without transliteration or translation.
5. File naming convention: `<appid>.lang` (e.g., `aria2.lang`).

#### 8.5.5 File Encoding & Format

- File encoding must be **UTF-8 without BOM**
- Line endings must be **LF** (Unix style, `\n`). CRLF (Windows style, `\r\n`) will cause parsing errors
- File naming convention: `<appid>.lang` (e.g., `aria2.lang`)

#### 8.5.6 Field Content per Language

Each language section carries its own values for `name` / `auth` / `descript` / `release_note` / `important`, written to fit the language concerned rather than a fixed template. Field definitions and required/optional status are listed in 8.5.3; `release_note` formatting rules are in 8.5.7.

In every section that is included, `name` / `auth` / `descript` must be non-empty; `release_note` / `important` may be empty. Entries that have not been translated are written with the English content — a blank value is never acceptable, and the section must not be omitted for that reason alone (omitting a language only affects display coverage, see 8.5.9).

#### 8.5.7 release_note Format

- Use `</br>` as the line break separator between multiple items
- **Do not** use other HTML tags (`<b>`, `<p>`, `<div>`, etc.) — they may cause page rendering anomalies
- Plain text only, except for `</br>` line breaks

#### 8.5.8 Translation Consistency

- The `descript` field semantics must be consistent across all supported languages
- Reviewers will verify translation accuracy for at least the core languages (zh-cn, en-us). Obvious errors in other languages will require the developer to correct them.

---

#### 8.5.9 Language Coverage and App Center Display Mechanism

**1) How the App Center decides whether to display an application in the current language**

Whether an application is visible under a given system language depends on **whether `app.lang` contains a section for that language**, together with the installation state:

| Application state | Language situation | Display behavior |
|---|---|---|
| Not installed | `app.lang` **contains** the current system language | Displayed in that language environment |
| Not installed | `app.lang` **does not contain** the current system language | **Not displayed** in that language environment — even if the application has already been published to the App Center |
| Installed | Any system language | **Always displayed** in the installed-application list; switching the system language does not affect it |

**2) Fallback (English) rule**

- **Installed applications:** if the user switches the system language to one whose section is **not** present in `app.lang`, the installed application is still displayed, with its **English** content as the fallback.
- **Not-installed applications:** there is **no fallback**. An application whose `app.lang` does not contain the current system language is not displayed in that language environment at all, so the English fallback cannot take effect.
- This is exactly why completing the 26-language set matters: the more languages `app.lang` covers, the more language environments the application can be discovered and installed from.

**3) Validation and review treatment**

The rules applied to `app.lang` — by the self-test tool and by review — are:

1. **Section-level non-empty check:** in every language section included, `name` / `auth` / `descript` must be non-empty; `release_note` / `important` may be empty.
2. **Untranslated content:** a language that has not been translated must carry the **English** text in those three fields. Blank, whitespace-only or punctuation-only values are not accepted for any section that is present.
3. **Superset allowed:** additional languages beyond the 26 in 8.5.1 are accepted.
4. **Coverage shortfall is not a blocking item:** the required set follows the version scope in 8.5.1 — the first 14 languages for a TOS 7.0 application, all 26 from TOS 7.1 on. An `app.lang` that covers fewer sections than its required set is **not** a rejection reason: review does not block the submission and only reminds the developer to complete the set (see 16 §16.1 / §16.2). The version requirement and the non-blocking reminder therefore coexist: coverage completeness is a recommendation, while the non-empty rule for every included section is mandatory.

**4) Historical background and upgrade advice**

*Why one list instead of two:* TOS 7.0 shipped 14 system languages, and the requirements of that period asked for those 14 only. TOS 7.1 adds 12 more, so this documentation describes a single 26-language set that serves both TOS versions — write against the table in 8.5.1 and ignore version differences. (Short version: see the background note at the end of 8.5.1.)

*Upgrading an application whose `app.lang` still carries the original 14 languages:*

1. **Add, do not rewrite.** Leave the 14 existing sections exactly as they are — same values, same order — and only append the remaining 12 sections using the tags listed in 8.5.1 (`cs-cz` … `he-il`).
2. **Fill untranslated sections with English.** A newly added language you have not translated yet still needs non-empty `name` / `auth` / `descript`; put the English text in. Blank, punctuation-only, or missing values are not accepted (see 8.5.3).
3. **Append in the 8.5.1 order.** Add the 12 new sections in the order listed in 8.5.1 (row 15 `cs-cz` … row 26 `he-il`) — the order in the file is not itself validated, but keeping it aligned with the specification makes review and later upgrades easier. Adding only part of the 12 is already useful (it is not a submission blocker). Keep the semantics of `descript` consistent across every language you provide (see 8.5.8).
4. **What an incomplete set actually costs you — reach, nothing else.** In a system language that `app.lang` does not contain, an application that is not yet installed is **not displayed** in the App Center, even if it has been published (no English fallback applies in this case); applications **already installed** stay visible and fall back to English. Review does **not** reject a submission for covering fewer than 26 languages — it only reminds you to complete the set (behavior details in points 1–3 above).

---

### 8.6 Application Icon

| Requirement | Specification |
|---|---|
| Format | SVG (vector graphics, transparent background) |
| Filename | Must exactly match the `id` in config.ini (e.g., `example-latest.svg`) |
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

**Service Crash Handling:**
- When the main service crashes, the application status will be shown as **"Not Enabled"** in the App Center.
- **Do not configure `Restart=` / `RestartSec=` in the service file.** The service restart policy is managed by the platform; developer-defined restart settings are not recommended and are discouraged during review.
- To prevent runaway crash loops, configure `StartLimitBurst=` and `StartLimitIntervalSec=` as needed.

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

### 8.9 Frontend-Backend Request Specification

> **Applicability:** this section applies to **WebUI Internal Open** (§8.3.1) and to the **WebUI External Open `.sock` access mode** (§8.3.2.2). It does **not** apply to the port listening mode (§8.3.2.1), whose traffic does not pass through the platform proxy — see the note on port mode below.

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

**Authentication channel — one compliant form only:** every request to `/v2/proxy/<app_id>/...` must carry **both** the `Cookie` header and the `X-Csrf-Token` header, in the exact form defined in **8.10**. This is the only accepted authentication channel:

- `Cookie` and `X-Csrf-Token` are **both mandatory** — if either one is missing, the request is treated as **not authenticated** and must be rejected (HTTP `401`).
- A request that carries only the standard browser `Cookie` (without the `X-Csrf-Token` header) is **not** compliant and is not accepted; it must not be treated as a second, interchangeable option.
- There is no alternative channel and the two are not "either/or": do not document, implement or accept a Cookie-only path, and do not fall back to it when the `X-Csrf-Token` header is absent.

**Port mode is not covered:** a page served directly on the application port (§8.3.2.1) does not pass through the platform proxy, so neither this channel nor the platform permission model applies to it — the application must implement its own access control on that port.

**Authenticated but not authorized vs. not authenticated:** the two failure situations must be distinguished, because they lead to different user-facing behavior:

| Situation | Backend response | Frontend behavior |
|---|---|---|
| Not logged in, session expired or token invalid | `401 Unauthorized` | Send the user to the **TOS login page** to log in and authorize again (see 8.10) |
| Logged in, but the current TOS user has no permission for this application | `403 Forbidden` with a no-permission result | Show a **"no permission"** message; do **not** render the application content and do not issue further application API calls |

> **Permission model:** only administrators can open an application page by default; an administrator may grant a non-administrator user access. A non-administrator user has **no App Center module permission** — after authorization the entry point is the application icon on the desktop. The frontend must not assume that any logged-in user is allowed to use the application, and must never treat "logged in" as "authorized" (see §8.3.2).

### 8.10 Frontend Authentication Header Specification

> **Applicability:** this section applies to **WebUI Internal Open** (§8.3.1) and to the **WebUI External Open `.sock` access mode** (§8.3.2.2). It does **not** apply to the port listening mode (§8.3.2.1): that traffic does not pass through the platform proxy, so the platform does not authenticate it and the headers described here are not validated by the platform.

When the frontend sends backend requests, it must read the current website cookies.

> **Single compliant channel:** authentication must follow the TerraMaster specification strictly — the request headers must carry **`Cookie` and `X-Csrf-Token` together**. This is the **only** accepted form: both headers are required, and a request missing either one is treated as **unauthenticated** (`401`). A standard browser `Cookie` alone is **not** a compliant authentication and is not accepted; there is no second, alternative channel, and the two must never be presented as interchangeable "options".

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
    '''Validate the platform authentication headers from frontend requests:
    both Cookie and X-Csrf-Token are mandatory — a missing one means 401.'''
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
- The frontend must detect the `401` response and send the user to the **TOS login page**, where the user logs in and authorizes again; the application page must not continue to render or issue further requests during that state
- Do not attempt to auto-refresh the token or to keep the session alive locally
- How the user returns to the application after logging in is decided by the platform: do not construct your own `redirect` parameter or assume a particular callback URL — rely on the platform behavior after a successful login

```javascript
fetch('/v2/proxy/myapp/api', { credentials: 'include' })
  .then(res => {
    if (res.status === 401) {
      // Not logged in / session expired: go to the TOS login page and log in again.
      // The return path after login is handled by the platform — do not append a redirect parameter.
      window.location.href = TOS_LOGIN_PAGE;
    }
    if (res.status === 403) {
      // Logged in but not authorized for this application: show "no permission",
      // do not render the application and do not issue further API calls.
      showNoPermission();
    }
    return res.json();
  });
```

**Permission failures are not login failures:** a `403` means the TOS user is authenticated but has no permission for the application (for example a non-administrator user who has not been authorized by an administrator). In that case the frontend must show a "no permission" message and must **not** render the application content; it must not fall back to the login page, and it must not retry with other credentials.

---
### 8.11 Nginx Configuration Specification (WebUI External Open)

In the **`.sock` access mode (§8.3.2.2)** an nginx configuration directory must be created at the same level as `config.ini` — this file is what exposes the application through the platform route. A **port-mode** application (§8.3.2.1) serves its own page and ships no nginx file:

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

> **`proxy_pass` in the portal block is an optional improvement:** the portal block `location /<app_id>/` may contain only `proxy_http_version` and the `proxy_set_header` directives when the application ships its own frontend Web panel and its service is reachable through the application socket `/var/api/<app_id>.sock` (proxied by the sibling block `location ^~ /v2/proxy/<app_id>/`). In that form the portal block does not forward traffic itself, and a missing `proxy_pass` is **not** a defect and must not block review. Adding `proxy_pass http://127.0.0.1:<listen_port>/;` to the portal block is an **optional improvement**, not a review requirement, and must never be used as a ground for rejection; it is recorded as an advisory item in **12 §12.10 Optional Improvements (Advisory)**. Full judgment logic: see 8.3.2; review checklist: see 16.2.

> **Reserved `tos` prefix (mandatory):** the App ID and every nginx-related name derived from it — the configuration file name `nginx/<app_id>.conf`, the route prefix `location /<app_id>/`, and any nginx command or entry named after the App ID — must **not** start with `tos`. `tos` is reserved by the platform in the nginx namespace: per platform engineering confirmation, an nginx command starting with `tos` collides with the platform's own nginx entries and the application cannot be opened normally. Fix the name **before** publishing — choose an App ID that does not start with `tos` and rename the corresponding nginx configuration file and route prefix; the App ID cannot be modified after creation (see 8.4.2 and 19 §19.1).

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

> **Note:** the `proxy_pass` line above is an **optional improvement**. The portal block is compliant with or without it, as long as the application ships its own frontend Web panel and its service is reachable through the application socket (see the policy note above and 8.3.2).

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
ReadWritePaths=/usr/local/<appid>/data /usr/local/<appid>/logs
LimitNOFILE=65536
# Restart= / RestartSec= are managed by the platform; do not configure them.

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
| `ReadWritePaths` | `/usr/local/<appid>/data /usr/local/<appid>/logs` | ✅ Yes | Explicitly declare writable paths (the application's own data and log directories) |
| `LimitNOFILE` | `65536` | Recommended | File descriptor limit |
| `StartLimitBurst` | `5` | Optional | Maximum restart attempts within the interval (set according to your needs) |
| `StartLimitIntervalSec` | `60` | Optional | Restart limit interval in seconds (set according to your needs) |
| `Restart` | — | Not recommended | Do not configure — the service restart policy is managed by the platform (see 8.7.1) |
| `RestartSec` | — | Not recommended | Do not configure — managed by the platform together with `Restart=` (see 8.7.1) |

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
| `Version` | ✅ Yes | Package version. Recommended to match the `version` field in config.ini (the platform does not validate this, but inconsistency may cause App Center display mismatches). |
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
| `Version` | `<version>` | `<version>` | Recommended to keep identical (the platform does not validate the two packages' versions) |
| `Architecture` | `all` | `amd64`/`arm64` | The data package should be `all` (configuration files are architecture-independent); the source package carries the actual architecture. The two packages are associated automatically by the APT repository mechanism, and neither the platform nor the self-test tool validates this value — still follow the specification and write `all` |

**config.ini Field Associations:**

| Field | Association Description |
|---|---|
| `config.ini.package` | Must match the **data package** metadata `package` |
| `config.ini.version` | Recommended to match the **data package** metadata `version` (the platform does not validate this) |
| `config.ini.system_id` | Must match the **source package** systemd service id |
| `config.ini.path` (when external open) | Must correspond to the nginx configuration file route. Where the portal block `location /<app_id>/` carries `proxy_pass`, the route resolves to the `<listen_port>` provided by the source package; where it does not, the address is served by the application's own frontend Web panel through the application socket (see 8.3.2 / 8.11) |

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

# NOTE: The application user is automatically created by the platform during installation.
# DO NOT add useradd commands here. The user named in the `user` field of config.ini is created by the platform at install time; the platform ensures it has non‑root privileges.

# Create the application's writable data and log directories
mkdir -p /usr/local/<appid>/data /usr/local/<appid>/logs
chown <appid>:<appid> /usr/local/<appid>/data /usr/local/<appid>/logs 2>/dev/null || true

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
chown -R <appid>:<appid> /usr/local/<appid>/data /usr/local/<appid>/logs 2>/dev/null || true

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
    rm -rf /usr/local/<appid>/data /usr/local/<appid>/logs
    rm -f /var/api/<appid>.sock
    # Remove nginx configuration
    rm -f /etc/nginx/conf.d/<appid>.conf 2>/dev/null || true
    # Remove the service unit from the platform-registered location.
    # Note: the unit must live under the application directory (/usr/local/<appid>/init.d/)
    # Place the unit under /usr/local/<appid>/init.d/; do not hardcode /etc/systemd/system paths.
    systemctl disable <system_id>.service 2>/dev/null || true
    # Reload systemd
    systemctl daemon-reload 2>/dev/null || true
fi

exit 0
```

### 8.15 Packaging and Verification

**Deb Package Filename Naming Convention (Recommended):**
- The version is read from the `version` field in `config.ini`, not from the file name. Including a version number in the file name is optional; the recommended form omits it.
- The platform does **not** validate the file name; it identifies the package type from the extension (`.deb` = single package, `.tar.gz` = dual-package archive) and verifies identity from `config.ini` after parsing the package. The names below are recommended so that packages are easy to distinguish by packaging hierarchy. Note that `<appid>` and `<platform>` are extracted from `config.ini`. `<platform>` is either `x86_64` or `aarch64`.

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
- `DEBIAN/md5sums` is no longer a verification item (the legacy requirement of the old TPK format has been cancelled); lintian warnings about a missing `md5sums` are **not** blocking
- The deb packaging method is not restricted (`dpkg-deb --build` or manual organization are both accepted)

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

`<AppRootDir>` must contain `DEBIAN/` **and** the payload under `usr/local/<appid>/`. The metadata files (`config.ini`, `<appid>.lang`, `images/icons/`) must live under `usr/local/<appid>/` — the parser reads them from `data.tar` at this path (see Section 8.2). They must **not** sit at the deb root:

```bash
# <AppRootDir> layout before building:
# ./<AppRootDir>/DEBIAN/control
# ./<AppRootDir>/usr/local/<appid>/config.ini            # NOT ./<AppRootDir>/config.ini
# ./<AppRootDir>/usr/local/<appid>/<appid>.lang
# ./<AppRootDir>/usr/local/<appid>/images/icons/<appid>.svg

dpkg-deb --build ./<AppRootDir> ./<appid>_<platform>.deb

# Verify the metadata files are inside data.tar at the required path:
dpkg-deb --contents ./<appid>_<platform>.deb | grep -E "usr/local/<appid>/(config.ini|<appid>.lang|images/icons/)"
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
├── bin/
│   └── tmrtimer
├── tmrtimer.lang
├── webui.bz2
├── images/
│   └── icons/
│       └── tmrtimer.svg
└── init.d/
    └── tmrtimer.service
```

**Deb Package Layout (what goes into the `.deb`):**

```
tmrtimer.deb
├── DEBIAN/
│   └── control
└── usr/
    └── local/
        └── tmrtimer/
            ├── config.ini
            ├── bin/
            │   └── tmrtimer
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
  "publisher": "publisher name",
  "exec": true,
  "version": "1.0.0",
  "low_version": "TOS7.0",
  "category": ["Utilities"],
  "platform": "x86_64",
  "user": "tmrtimer",
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
  "publisher": "publisher name",
  "exec": true,
  "version": "1.0.1",
  "low_version": "TOS7.0",
  "category": ["Utilities"],
  "platform": "x86_64",
  "user": "weather",
  "system_id": "weather-system",
  "package": "weather-package",
  "application_type": "deb",
  "path": "http://${ip}:16688",
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

> **Note:** the `proxy_pass` line above is an **optional improvement**. The portal block is compliant with or without it, as long as the application ships its own frontend Web panel and its service is reachable through the application socket (see 8.3.2 / 8.11).

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
  "publisher": "publisher name",
  "exec": true,
  "version": "1.0.0",
  "low_version": "TOS7.0",
  "category": ["Utilities"],
  "platform": "x86_64",
  "user": "datasync",
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
- `version` is recommended to match the `Version` in the source package metadata (the platform does not enforce or compare the two packages' versions)
- `application_type` must be set to `deb`
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
| **Version Display** | The platform does **not** require the two packages to carry the same `Version`, and does not compare them. The version shown in the App Center comes from the `version` field in `config.ini` — keep that field accurate. | — |
| **No Binaries in Data Package** | The data package (`<appid>.deb`) **must not contain any executable binary files**, compiled code, or system-specific libraries. Only configuration files, icons, language files, nginx configurations, and other static resources are allowed. | Rejected at manual review — executable content is not one of the automatic checks (see 16 §16.1). |
| **Data Package Architecture** | The data package `Architecture` should be `all`, not `amd64` or `arm64` — configuration files are architecture-independent. The two packages are associated automatically by the APT repository mechanism, and neither the platform nor the self-test tool validates this value, so a deviation is not a ground for rejection; the specification nonetheless requires `all`. | Not validated — follow the specification (`all`) |
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
