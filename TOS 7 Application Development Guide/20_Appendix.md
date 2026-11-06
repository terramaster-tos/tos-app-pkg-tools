
# 20. Appendix

### Appendix A: Application Categories

| Category ID | Display Name |
|---|---|
| `Audio_Video_Entertainment` | Audio & Video Entertainment |
| `Photography_Video` | Photography & Video |
| `Backup_Sync` | Backup & Sync |
| `Development_Tools` | Development Tools |
| `Utilities` | Utilities |
| `Web_Services` | Web Services |
| `Security` | Security |
| `Download` | Download |
| `Driver` | Driver |
| `Artificial_Intelligence` | AI |

**Applying for a New Category:**
If no existing category fits your app, you can apply for a new category:
1. Submit a category request through the Developer Platform support channel
2. Provide: suggested category ID, display name, and justification of at least 3 existing or planned apps
3. Review takes 5–10 business days
4. Custom/non-standard categories without prior approval will be rejected

### Appendix B: System Port Reference

The following ports are reserved by the TOS system and must not be used by applications:

| Port | Service |
|---|---|
| 22 | SSH |
| 80 | HTTP (TOS Web) |
| 443 | HTTPS |
| 445 | SMB |
| 3306 | MySQL |
| 5050 | TOS Daemon (internal system service port; prohibited for app use) |
| 5432 | PostgreSQL |
| 6379 | Redis |
| 8181 | TOS Nginx (Web UI) |
| 8443 | TOS HTTPS |

Recommended app port range: **8000–19999** (excluding ports already occupied by installed apps). If ports in the recommended range are occupied, you may use **49152–65535** (dynamic port range), but it must be explicitly declared in the configuration.

> See also Chapter 12 §12.8 Common Port Reference (which includes a list of common community-occupied ports).

### Appendix C: TOS System Directories

| Path | Description |
|---|---|
| `/Volume*/@apps/<appid>/` | App installation directory (non-embedded apps) — the application sees it as `/usr/local/<appid>/`, resolved by the platform onto the user-selected volume |
| `/Volume*/@apps/<appid>/data/` | App runtime data (caches, temporary files) — logical path for the app: `/usr/local/<appid>/data/` |
| `/Volume*/@apps/<appid>/logs/` | App logs — logical path for the app: `/usr/local/<appid>/logs/` |
| `/Volume<N>/DockerAppData/<appid>/` | Docker app data (config and business data) |
| `/usr/local/system_app_data/<appid>/` | System embedded app directory (for built-in apps only) |
| `/usr/local/<appid>/init.d/<system_id>` | Systemd service unit — it must live under the application directory (`/usr/local/<appid>/init.d/`). Placing the unit under `/etc/systemd/system` is **not allowed**; any such path must be removed |

> **Note:** These are the paths your application uses. After installation the platform maps `/usr/local/<appid>/` onto the volume the user chose at installation, where the same directory physically lives at `/Volume<N>/@apps/<appid>/`. `*` is documentation notation for that volume number (e.g., Volume1, Volume2) — the platform does **not** expand it, so never write `/Volume*/…` into a compose file, a systemd unit, a lifecycle script, or any other machine-read configuration.
> - For non-embedded apps (both official and third-party), all files live in the application directory, which the application sees as `/usr/local/<appid>/`; the platform resolves it onto the user-selected volume at `/Volume<N>/@apps/<appid>/`.
> - System embedded apps (e.g., GlobalSearch, StorageManager) reside on the system disk at `/usr/local/system_app_data/`.
> - Docker app data is stored separately under `/Volume<N>/DockerAppData/<appid>/` via volume mounts. Docker applications do not use TNAS shared folders.

### Appendix D: TOS Systemd Targets

| Target | Description |
|---|---|
| `multi-user.target` | TOS application service target (**all app services must use this as `WantedBy`**) |
| `default.target` | System default boot target (do not use for app services; use `multi-user.target` instead) |

### Appendix E: Compatibility Matrix

| TOS Version | Base System | glibc | Python3 | Docker | Node.js |
|---|---|---|---|---|---|
| TOS 7.0 | Ubuntu 22.04-compatible | 2.35 | 3.10 | 20.10+ | 18.x |
| TOS 7.x | Ubuntu 22.04-compatible | 2.35 | 3.10 | 20.10+ (or higher) | 18.x (or higher) |

> Note: TOS 7.x series minor versions will maintain compatibility with TOS 7.0. Apps developed for TOS 7.0 will run without additional adaptation. For the latest version-specific details, refer to the official TOS release notes or the Developer Platform.

> **Note:** The Node.js / Python3 / Docker columns above are for reference within Docker containers only. Deb applications must not directly depend on these versions — declare their own runtime dependencies in DEBIAN/control.

### Appendix F: Language File Quick Template

> **Version scope:** TOS 7.0 requires the first **14** sections below (`zh-cn` … `pt-pt`); **from TOS 7.1 the required set is 26** — the complete list below, in this order (tags are authoritative, see 8.5.1). In **every** section that is included, `name` / `auth` / `descript` must be non-empty: an untranslated language is written with the **English** text, never left blank. `release_note` / `important` may be empty. Fewer than 26 sections is **not** a rejection ground (review only reminds the developer, see 8.5.9), and supersets are allowed.

```ini
[zh-cn]
name = ""            # required — never empty (use English if untranslated)
auth = ""            # required — never empty (use English if untranslated)
descript = ""        # required — never empty (use English if untranslated)
release_note = ""    # optional
important = ""       # optional

[zh-hk]
name = ""            # required — never empty (use English if untranslated)
auth = ""            # required — never empty (use English if untranslated)
descript = ""        # required — never empty (use English if untranslated)
release_note = ""    # optional
important = ""       # optional

[en-us]
name = ""            # required — never empty (use English if untranslated)
auth = ""            # required — never empty (use English if untranslated)
descript = ""        # required — never empty (use English if untranslated)
release_note = ""    # optional
important = ""       # optional

[ko-kr]
name = ""            # required — never empty (use English if untranslated)
auth = ""            # required — never empty (use English if untranslated)
descript = ""        # required — never empty (use English if untranslated)
release_note = ""    # optional
important = ""       # optional

[ja-jp]
name = ""            # required — never empty (use English if untranslated)
auth = ""            # required — never empty (use English if untranslated)
descript = ""        # required — never empty (use English if untranslated)
release_note = ""    # optional
important = ""       # optional

[de-de]
name = ""            # required — never empty (use English if untranslated)
auth = ""            # required — never empty (use English if untranslated)
descript = ""        # required — never empty (use English if untranslated)
release_note = ""    # optional
important = ""       # optional

[fr-fr]
name = ""            # required — never empty (use English if untranslated)
auth = ""            # required — never empty (use English if untranslated)
descript = ""        # required — never empty (use English if untranslated)
release_note = ""    # optional
important = ""       # optional

[it-it]
name = ""            # required — never empty (use English if untranslated)
auth = ""            # required — never empty (use English if untranslated)
descript = ""        # required — never empty (use English if untranslated)
release_note = ""    # optional
important = ""       # optional

[es-es]
name = ""            # required — never empty (use English if untranslated)
auth = ""            # required — never empty (use English if untranslated)
descript = ""        # required — never empty (use English if untranslated)
release_note = ""    # optional
important = ""       # optional

[hu-hu]
name = ""            # required — never empty (use English if untranslated)
auth = ""            # required — never empty (use English if untranslated)
descript = ""        # required — never empty (use English if untranslated)
release_note = ""    # optional
important = ""       # optional

[pl-pl]
name = ""            # required — never empty (use English if untranslated)
auth = ""            # required — never empty (use English if untranslated)
descript = ""        # required — never empty (use English if untranslated)
release_note = ""    # optional
important = ""       # optional

[tr-tr]
name = ""            # required — never empty (use English if untranslated)
auth = ""            # required — never empty (use English if untranslated)
descript = ""        # required — never empty (use English if untranslated)
release_note = ""    # optional
important = ""       # optional

[ru-ru]
name = ""            # required — never empty (use English if untranslated)
auth = ""            # required — never empty (use English if untranslated)
descript = ""        # required — never empty (use English if untranslated)
release_note = ""    # optional
important = ""       # optional

[pt-pt]  # last language required by TOS 7.0
name = ""            # required — never empty (use English if untranslated)
auth = ""            # required — never empty (use English if untranslated)
descript = ""        # required — never empty (use English if untranslated)
release_note = ""    # optional
important = ""       # optional

[cs-cz]
name = ""            # required — never empty (use English if untranslated)
auth = ""            # required — never empty (use English if untranslated)
descript = ""        # required — never empty (use English if untranslated)
release_note = ""    # optional
important = ""       # optional

[da-dk]
name = ""            # required — never empty (use English if untranslated)
auth = ""            # required — never empty (use English if untranslated)
descript = ""        # required — never empty (use English if untranslated)
release_note = ""    # optional
important = ""       # optional

[nl-nl]
name = ""            # required — never empty (use English if untranslated)
auth = ""            # required — never empty (use English if untranslated)
descript = ""        # required — never empty (use English if untranslated)
release_note = ""    # optional
important = ""       # optional

[nb-no]
name = ""            # required — never empty (use English if untranslated)
auth = ""            # required — never empty (use English if untranslated)
descript = ""        # required — never empty (use English if untranslated)
release_note = ""    # optional
important = ""       # optional

[sv-se]
name = ""            # required — never empty (use English if untranslated)
auth = ""            # required — never empty (use English if untranslated)
descript = ""        # required — never empty (use English if untranslated)
release_note = ""    # optional
important = ""       # optional

[el-gr]
name = ""            # required — never empty (use English if untranslated)
auth = ""            # required — never empty (use English if untranslated)
descript = ""        # required — never empty (use English if untranslated)
release_note = ""    # optional
important = ""       # optional

[ro-ro]
name = ""            # required — never empty (use English if untranslated)
auth = ""            # required — never empty (use English if untranslated)
descript = ""        # required — never empty (use English if untranslated)
release_note = ""    # optional
important = ""       # optional

[th-th]
name = ""            # required — never empty (use English if untranslated)
auth = ""            # required — never empty (use English if untranslated)
descript = ""        # required — never empty (use English if untranslated)
release_note = ""    # optional
important = ""       # optional

[vi-vn]
name = ""            # required — never empty (use English if untranslated)
auth = ""            # required — never empty (use English if untranslated)
descript = ""        # required — never empty (use English if untranslated)
release_note = ""    # optional
important = ""       # optional

[id-id]
name = ""            # required — never empty (use English if untranslated)
auth = ""            # required — never empty (use English if untranslated)
descript = ""        # required — never empty (use English if untranslated)
release_note = ""    # optional
important = ""       # optional

[ar-sa]
name = ""            # required — never empty (use English if untranslated)
auth = ""            # required — never empty (use English if untranslated)
descript = ""        # required — never empty (use English if untranslated)
release_note = ""    # optional
important = ""       # optional

[he-il]
name = ""            # required — never empty (use English if untranslated)
auth = ""            # required — never empty (use English if untranslated)
descript = ""        # required — never empty (use English if untranslated)
release_note = ""    # optional
important = ""       # optional
```

### Appendix G: Shared Folder API (Deb Applications)

> **Deb applications only.** Docker applications do not participate in the TNAS shared-folder mechanism: no shared folder is created for them, they must not call `ter_share_add`, and all persistent business data is stored in the application data root `/Volume<N>/DockerAppData/<appid>/` through volume mounts.

```bash
# Create a shared folder for the app
ter_share_add -name <folder_name> -owner <username>

# Example
ter_share_add -name myapp-data -owner myapp
```

### Appendix H: Upgrade Migration Checklist

Use this checklist when upgrading your app to a new major version:

- [ ] Data migration scripts handle previous version formats
- [ ] Configuration files are backed up before modification
- [ ] New dependencies are declared in DEBIAN/control
- [ ] Service files are updated (if needed)
- [ ] Version numbers are incremented in config.ini and DEBIAN/control; if release notes are updated, sync the app.lang entries accordingly
- [ ] Changelog/release notes are updated
- [ ] Upgrade path tested: install old version → add data → upgrade → verify data
- [ ] Rollback path tested: downgrade or restore from backup
- [ ] Package re-built and re-uploaded (the platform regenerates the SHA-256 value at submission; attaching a `.sha256` file is optional)

### Appendix I: README.md Template

```markdown
# <App Name>

## Overview
A brief description of the app and its purpose.

## Features
- Feature 1
- Feature 2
- Feature 3

## Installation
1. Requirements: TOS 7.0+, [other dependencies]
2. Install from TOS App Center
3. Initial configuration steps

## Usage
How to access and use the app:

1. Access URL: `http://<your-nas-ip>:<port>`
2. Default credentials: [if applicable]
3. Key settings

## Permissions
| Permission | Rationale |
|---|---|
| Network: port XXXX | [rationale] |
| File system: /path/to/data | [rationale] |
| User: <appid> | Isolated service execution |

## Configuration
Key configuration options and their defaults.

## Ports
| Port | Protocol | Purpose |
|---|---|---|
| XXXX | TCP | [purpose] |

## Support
- Documentation: [link]
- Issue tracker: [link]
- Community: [link]

## Changelog
### v1.0.0 (YYYY-MM-DD)
- Initial release

## License
[License type]
```

### Appendix J: Complete Config File Templates

Complete downloadable config file templates for all app types are available on the TOS Developer Platform:
- `config.ini` template (Deb WebUI Internal, Deb WebUI External, Deb No UI, Docker)
- `app.lang` template (26-language quick template; see Appendix F and 8.5.1)
- Systemd unit file template (with security hardening)
- DEBIAN/control template (single-package, dual-package)
- Lifecycle script templates (preinst, postinst, prerm, postrm)
- Nginx config template
- docker-compose.yml template
- GitHub Actions CI/CD template

### Appendix K: Common Rejection Reasons & Fix Examples

| Rejection Reason | Incorrect Example | Correct Fix |
|---|---|---|
| Comments in config.ini | `// this is a comment` in JSON | Remove all comments; JSON does not support comments |
| Single quotes in JSON | `'version': '1.0.0'` | Use double quotes: `"version": "1.0.0"` |
| Trailing comma | `"beta": false,}` (comma on last field) | Remove trailing comma after the last field |
| Hardcoded IP | `"path": "http://192.168.1.100:8080"` | Use placeholder: `"path": "http://${ip}:8080"` |
| Missing languages | app.lang has only 12 languages | Aim at the documented 26-language set (see 8.5.1 and Appendix F), filling untranslated ones with English. Coverage below 26 does not block submission — review only reminds the developer to complete it |
| root in systemd | `User=root` in service file | Use dedicated user: `User=<appid>` |
| Docker privileged mode | `privileged: true` in compose | Remove; use fine-grained capabilities |
| Package integrity mismatch | Downloaded package does not match the platform-generated SHA-256 baseline (a missing `.sha256` attachment is not a failure — the platform generates the value at submission) | Re-build and re-upload the package from the repository Release; verify the Release asset is the build you intend to publish |
| Version not incremented | v1.0.0 → v1.0.0 (same version) | The version number must be greater than the previously published one; the App Center compares versions numerically, so a non-incremented version would not reach existing users as an update (v1.0.0 → v1.0.1) |
| App ID or nginx name starts with the reserved `tos` prefix | `"id": "tos-log-server"` (nginx configuration `tos-log-server.conf`, route `location /tos-log-server/`) | Choose an App ID that does not start with `tos` (e.g. `dev-log-server`) and rename the nginx configuration file and route prefix accordingly — `tos` is reserved by the platform in the nginx namespace, so a `tos`-prefixed name collides with the platform's own nginx entries and the application page cannot be opened (see 08 §8.4.2 / §8.11). Automated validation does not check this; it surfaces during functional review as "the app page cannot be opened" |

**Explicitly not a rejection reason:** a missing `proxy_pass` in the nginx portal block (`location /<app_id>/` carrying proxy headers only) must **not** be used to reject, block, or delay a version. This form is compliant when the application ships its own frontend Web panel and its service is reachable through the application socket `/var/api/<app_id>.sock`; adding `proxy_pass http://127.0.0.1:<listen_port>/;` is an optional improvement only (N03 withdrawn — see 08 §8.3.2.2 / §8.11 / §8.13.2, 16 §16.1 / §16.2, 19 §19.3, 12 §12.10). Backend port allocation checks and nginx configuration syntax validation remain mandatory and are unrelated to this item.

### Appendix L: Terminology & Definitions

| Term | Definition | AKA |
|---|---|---|
| **App ID** | Globally unique identifier for the app; set in `config.ini.id` | `app_id`, `appid`, `id` |
| **System ID** | Systemd service unit name; set in `config.ini.system_id` | `system_id`, service name |
| **Package Name** | Debian package name; set in the Package field of DEBIAN/control | `package`, deb package name |
| **Dual-Package Mode** | Two deb packages in one tar.gz archive — a deb data package (containing TOS platform configuration) and a deb source package (containing app binaries). | Dual-package mechanism |
| **Data Package** | TOS system-recognizable app configuration data package, abbreviated as deb data package | App data package, metadata package |
| **Source Package** | Runnable app main body deb package, abbreviated as deb source package | App installation package, binary package |
| **Single-Package Mode** | Develop directly according to the TOS 7.0 specification, integrating all files into a single deb package | Single-package mechanism |
| **WebUI Internal Opening** | App frontend opens within the TOS desktop as an iframe | iframe mode, embedded mode |
| **WebUI External Opening** | App frontend opens in a new browser tab | New tab mode, external mode |
| **Reserved `tos` Prefix** | `tos` is reserved by the platform at the beginning of an nginx command / nginx-related name. The App ID (`config.ini.id`) and the nginx names derived from it (`nginx/<appid>.conf`, the route prefix `location /<appid>/`) must not start with `tos` (see 08 §8.4.2 / §8.11) | `tos` prefix collision |
| **No UI Service** | An app without a graphical interface; a background daemon service | Headless service, daemon |
| **Minimum TOS Version** | The minimum TOS version required by the app; set in the `low_version` field of `config.ini`. This field is **optional** — leaving it empty means the application declares no minimum TOS version; `help` is a **required** field that must be provided on every submission. | Min TOS version, TOS version requirement |

### Appendix M: Beta App Management

| Rule | Description |
|---|---|
| **Visibility Scope** | Beta apps are only visible to users who have opted into beta testing |
| **Visibility Control** | Set `"beta": true` in config.ini; the platform automatically restricts visibility |
| **Graduation Process** | To graduate from Beta: set `"beta": false`. Increase the version number so beta users receive the update; use the `"beta"` field rather than a `-beta` / `-rc` suffix (see 4.2.1) |
| **Prohibited Behavior** | Beta apps must not be distributed as production releases; misleading users about beta status will result in rejection |
| **Expiry & Delisting** | Beta apps not updated for 90 days may be automatically delisted |
| **Version Number** | Version numbers must comply with 4.2 Version Number Specification (Debian character rules, comparable, greater than the previously published version); use the `"beta": true` field rather than a `-beta` / `-rc` suffix, and keep the number increasing so update detection keeps working |


### Appendix N: Review Rejection Codes (Tool Check ID) Reference

Rejection notices quote the machine check ID that blocked the submission, in the form `tool-C<number>` (for example `tool-C23`). Use the table below to map a code back to the rule it enforces and to the section that has to be fixed.

| Check ID | Rule enforced | Document Section |
|---|---|---|
| `tool-C23` | A Docker application with a UI must set `open_path: true` in `config.ini` (with `path` set to `http://${ip}:<port>`). Leaving the field out makes the application open as an embedded iframe whose page cannot render — "mutually exclusive with `type`" is not the whole rule | 8.4.2 / 9.3 Rule 2 / 16.1 (docker-compose.yml Validation) / 16.2 |

> **Coverage note:** only the check IDs confirmed by developer-side rejection notices are listed above — this guide does not publish the platform's complete check-ID list. If a rejection notice quotes a code that is not in the table, identify the rule from the rejection description using **16.1 (automated validation)**, **16.5 (common rejection reasons)** and **Appendix K (fix examples)**, and report the unmapped code through the Developer Platform support channel so that it can be added here.
>
> **Self-check before submission:** the Docker-side checks listed in 16.1 can be reproduced locally with `docker compose config -q` (13.2 Step 2) plus a manual pass over the 16.1 checklists.

*This document is the official global specification for TOS7 app development and publishing. The specification will be continuously updated with TOS7 version iterations. Developers should refer to the latest version on the Developer Platform.*

---

← [Previous: FAQ](19_FAQ.md) &nbsp;&nbsp;|&nbsp;&nbsp; [📖 Back to Contents](../README.md)
