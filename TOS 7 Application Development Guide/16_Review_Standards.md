# 16. Review Standards

### 16.1 Submission Automated Validation (Pre-filter)

**Trigger Timing:** Executed in real time after a new version is submitted on the Developer Platform . Validation failure results in immediate blocking; no review ticket is generated and no initial review is entered. There is no warning level: every threshold is a hard rejection, and a failed submission writes no version record at all (agent-api §6.5).

**Validation Coverage:**

> **Note:** This is the **single unified submission-validation checklist**. Its items are identical to the Developer Platform package-validation rules (agent-api §6.5.6 — a fixed set of ten checks, three at the download stage and seven at the parse stage), so the two checklists never diverge and there is no "authoritative list plus a reference list" split: every row below belongs to the same submission gate.
>
> The **API Auto-Check** column records only the enforcement stage of a row: **Yes / Partial** = covered by the ten automated checks of agent-api §6.5.6; **No** = not covered by those ten checks and therefore enforced by manual review (agent-api §6.5.6, "What the platform does not validate"). A **No** is not an optional item — it is a specification requirement that review enforces.

#### Platform Validation Items (in addition to the id / application_type / platform value comparison)

**agent-api automatic pre-filtering covers its ten checks only; the platform additionally validates package configuration and metadata completeness:**

| Platform validation item | What is validated | Failure code |
|---|---|---|
| Required files inside the package | `config.ini`, `<appid>.lang` and the icon file must all exist at the specified paths | `missing_required_files` |
| config.ini platform-validated fields | `id`, `icon`, `publisher`, `exec`, `version`, `help`, `category`, `platform`, `application_type`, `user` must all exist and be non-empty — `low_version` is optional and may be left empty | `invalid_config_ini` |
| Icon format and size | The icon must be SVG and within the size threshold (icon content ≤ 50 KB; archive entry ≤ 1 MiB) | `icon_validation_failed` / `package_unzip_failed` |

> Config field **values** other than `id` / `application_type` / `platform` are not compared with the values registered on the platform. This does not mean those fields go unvalidated: their presence, non-emptiness and type convention are checked as listed above.

#### config.ini Validation

| Check Item | Description | Reference | API Auto-Check |
|---|---|---|---|
| Valid JSON syntax (no comments, no trailing commas, no single quotes outside double quotes) | Validate using `python3 -m json.tool` | 8.4 config.ini Specification | Yes — `invalid_config_ini` (the file is parsed as JSON) |
| No single quotes, no inline comments | JSON standard only allows double quotes; `//` or `/* */` are treated as comments | 8.4 config.ini Specification | Yes — `invalid_config_ini` (single quotes and comments simply fail JSON parsing; there is no separate check) |
| All required fields present (id/icon/publisher/exec/version/help/category/platform/application_type/user; `low_version` optional) | Check the platform-validated config.ini fields item by item. `help` **is** required; `low_version` is optional, may be left empty and does not block submission | 8.4.3 Key Rules | Yes — `invalid_config_ini` requires the same fields to exist and be non-empty, and additionally requires each value to match its type convention (e.g. a boolean field may not be written as a string) |
| type and open_path are mutually exclusive (both cannot exist) | Deb iframe apps use the `type` field; Deb external-open and Docker apps use the `open_path` field. They are mutually exclusive and cannot coexist | 8.4.2 Field Reference | No — manual review / specification requirement (not one of the ten automated checks of agent-api §6.5.6; field values other than `id` / `application_type` / `platform` are not value-compared — see Platform Validation Items for the metadata checks that do run) |
| `open_path` must be `true` for Docker apps with a UI, with `path` set to `http://${ip}:<port>` | Mutual exclusion is not the whole rule: a Docker application has no iframe UI, so `open_path: true` is **mandatory**. Omitting it leaves the app opening as an embedded iframe whose page cannot render (rejection code `tool-C23` — see Appendix N) | 8.4.2 Field Reference / 9.3 | No — manual review / specification requirement (not one of the ten automated checks of agent-api §6.5.6: field *values* are not value-compared) |
| path field must use `${ip}` placeholder; no hardcoded IP or domain | URL-type path may be written as `http://${ip}:<port>`; the route form `/<app_id>/` is also accepted | 8.4.3 Key Rules | No — manual review / specification requirement (not one of the ten automated checks of agent-api §6.5.6 — see the row above) |
| platform field matches the actual submitted package architecture | e.g., if platform declares `x86_64`, binaries in the package must be x86_64 architecture | 8.4.2 Field Reference | Partial — `platform_mismatch` only checks that `config.ini`'s `platform` equals the architecture registered for the App (`x86_64` / `aarch64`); package binaries are never read, so architecture-versus-binary conformance stays a manual / testing item |
| `id` must not start with the reserved `tos` prefix | `tos` is reserved by the platform in the nginx route/command namespace; an `id` starting with `tos` (e.g. `tos-log-server`) collides with the platform's own nginx entries and the application page cannot be opened normally | 8.4.2 Field Reference / 8.11 Nginx Configuration Specification | No — manual review / specification requirement (agent-api §6.5.6: the API only compares `id` for `app_id_mismatch` and duplicate detection; no prefix rule is evaluated) |

#### app.lang Validation

| Check Item | Description | Reference | API Auto-Check |
|---|---|---|---|
| Language coverage — TOS 7.0 requires the first 14 languages, TOS 7.1 and later require 26 (supersets allowed; see 8.5.1) | The 26 tags and their order are fixed by 8.5.1: `zh-cn`, `zh-hk`, `en-us`, `ko-kr`, `ja-jp`, `de-de`, `fr-fr`, `it-it`, `es-es`, `hu-hu`, `pl-pl`, `tr-tr`, `ru-ru`, `pt-pt`, `cs-cz`, `da-dk`, `nl-nl`, `nb-no`, `sv-se`, `el-gr`, `ro-ro`, `th-th`, `vi-vn`, `id-id`, `ar-sa`, `he-il`. Coverage is **not** a blocking item: an `app.lang` with fewer than 26 language sections is not rejected, and review only reminds the developer to complete the 26-language set. Omitting a language never exempts the included sections from the non-empty rule below — an untranslated language is filled with English rather than left blank | 8.5 app.lang Specification / 8.5.9 | Partial — `invalid_language_files` requires the first 14 sections of the 26-language set (zh-cn, zh-hk, en-us, fr-fr, de-de, it-it, es-es, hu-hu, ja-jp, ko-kr, pl-pl, ru-ru, tr-tr, pt-pt); sections outside those 14 are neither checked nor rejected. Full 26-language coverage is a specification requirement not yet enforced by the API (agent-api §6.5.4) |
| `name` / `auth` / `descript` non-empty in **every** language section; `release_note` / `important` may be empty | These three are the only mandatory fields per section: blank, whitespace-only or punctuation-only values are not accepted, while `release_note` / `important` are optional. The mandatory fields need not all be translated — an untranslated language must carry the **English** content, never an empty value. Submitting more than the 26 languages is accepted (superset) | 8.5.3 Field Descriptions / 8.5.9 | Yes — `invalid_language_files` requires `name` / `auth` / `descript` to be non-empty and treats `release_note` as optional |
| File encoding is UTF-8 without BOM | EF BB BF bytes not allowed at file header | 8.5.5 File Encoding & Format | No — manual review / specification requirement (the API runs no encoding check) |
| All line endings must be LF (\\n); CRLF (\\r\\n) prohibited | A common cross-platform collaboration issue; Windows developers must pay extra attention | 4.6 Cross-Platform Line Ending Specification | No — manual review / specification requirement (the API runs no line-ending check) |

#### Resource File Validation

| Check Item | Description | Reference | API Auto-Check |
|---|---|---|---|
| Icon format is SVG | PNG/JPG/ICO or other bitmap formats are not accepted | 8.6 Application Icons | Platform (not one of the ten agent-api §6.5.6 checks; see **Platform Validation Items**) — the required icon path ends in `{AppID}.svg`, so a non-SVG file is not found at that path; icon *semantics* are not checked |
| Icon file size is within the platform-accepted range | An oversized icon file is rejected | 8.6 Application Icons (agent-api §6.5.3) | Platform (not one of the ten agent-api §6.5.6 checks; see **Platform Validation Items**) — icon content over **50 KB** fails `icon_validation_failed`; an archive entry over 1 MiB fails `package_unzip_failed` |
| SVG has transparent background, valid viewBox | viewBox attribute must exist with reasonable values | 8.6 Application Icons | No — manual review / specification requirement (agent-api §6.5.6: `viewBox`, dimensions and colours are ignored, and the root element need not be `svg`) |
| Icon file path exactly matches the `icon` field in config.ini | Including case sensitivity and directory hierarchy | 8.6 Application Icons | No — manual review / specification requirement (not one of the ten automated checks of agent-api §6.5.6: the API looks for the icon at the fixed path `usr/local/{AppID}/images/icons/{AppID}.svg` and does not compare that path value against `config.ini`'s `icon` field) |
| All script files (.sh/.py/.pl) must not use CRLF line endings | Unified LF line endings | 4.6 Cross-Platform Line Ending Specification | No — manual review / specification requirement (the API runs no line-ending check) |

#### Package Structure Validation

| Check Item | Description | Reference | API Auto-Check |
|---|---|---|---|
| Required metadata files complete (config.ini / `<appid>.lang` / icon file) | The package must contain config.ini, `<appid>.lang` and the icon file; missing any one of them results in immediate blocking (agent-api §6.5.2 / §6.5.4) | 8.2 General Directory Structure | Platform (not one of the ten agent-api §6.5.6 checks; see **Platform Validation Items**) — `missing_required_files` |
| Package identity comes from `config.ini`, not from the file name | After downloading and parsing the package, the platform compares the `id`, `platform`, and package type in `config.ini` with the application information entered on the Developer Platform. The asset file name is **not** validated; the recommended name is a developer convenience only | 4.2.4 Release Asset Naming Specification | Yes — the asset file name, extension and `Content-Type` are never checked; `app_id_mismatch` compares `config.ini`'s `id` with the App ID **case-sensitively** |
| Dual-package data package (data.tar.gz) must not contain binary executable files (except lifecycle scripts such as postinst/preinst under the DEBIAN directory) | Business programs and runtime binaries must not appear in the data package | 8.17 Dual-Package Mode Specification | No — manual review / specification requirement (agent-api §6.5.6: executable content is never read) |
| Deb metadata files (config.ini / <appid>.lang / icon) must be under `data.tar` at `./usr/local/<appid>/`, not at the deb root | The parser reads metadata from this path; files at the deb root cause an unrecoverable metadata parse failure | 8.2 General Directory Structure | Platform (not one of the ten agent-api §6.5.6 checks; see **Platform Validation Items**) — `missing_required_files` looks for `usr/local/{AppID}/config.ini`, `usr/local/{AppID}/{AppID}.lang` and `usr/local/{AppID}/images/icons/{AppID}.svg` (paths are case-sensitive) |
| Directory name case compliance (all lowercase, consistent with config.ini declarations) | Linux file system is case-sensitive | 8.2 Common Directory Structure | Partial — the required paths and the App ID comparison are case-sensitive, but no separate "all lowercase" rule exists |
| Nginx configuration file `<app_id>.conf` shipped for WebUI external-open apps using the `.sock` access mode (8.3.2.2; port-mode apps serve their own page and ship no nginx file); the portal block `location /<app_id>/` is **not** required to contain `proxy_pass` | A portal block that only sets the proxy headers is compliant when the application ships its own frontend Web panel and its service is reachable through the application socket (`/var/api/<app_id>.sock`, reached through the sibling block `location ^~ /v2/proxy/<app_id>/`). Adding `proxy_pass` to the portal block is an optional improvement (advisory list: 12 §12.10); a missing `proxy_pass` is never a ground to block or reject a version (N03 withdrawn). The nginx configuration file name `<app_id>.conf` and the route prefix `location /<app_id>/` it defines are derived from the App ID and must not start with the reserved `tos` prefix | 8.3.2.2 / 8.11 Nginx Configuration Specification | No — the API's ten download/parse checks (agent-api §6.5.1–§6.5.4) contain no nginx-configuration check and the nginx configuration is never read; this row is a specification requirement upheld by manual review |

#### docker-compose.yml Validation (Docker applications only)

| Check Item | Description | Reference | API Auto-Check |
|---|---|---|---|
| Compose file parses successfully | Run `docker compose config -q`; any reported error blocks the submission | 9.3 docker-compose.yml Specification / 13.2 | No — manual review / specification requirement (the API never reads `docker-compose.yml`) |
| Every named volume referenced by a service is declared under the top-level `volumes:` key | If `services.<svc>.volumes` uses `name:/container/path`, the top-level `volumes:` key must declare `name`. A service-level reference alone makes Compose reject the whole project (`service "x" refers to undefined volume "y"`) before any image is pulled | 9.3 Rule 4 | No — manual review / specification requirement (the API never reads `docker-compose.yml`) |
| `x-app-meta.web.port` is exposed by a port mapping | The port declared in `x-app-meta.web` must appear as a host port under `services.<svc>.ports`; otherwise the app installs but the Web UI is unreachable | 9.3 Rule 2 | No — manual review / specification requirement |
| `open_path` is `true` for Docker apps with a UI, and `path` is `http://${ip}:<port>` | Docker applications with a Web UI always open in a new browser tab: `open_path: true` is **mandatory**, not merely "mutually exclusive with `type`". Omitting it leaves the app opening as an embedded iframe with no UI to render (rejection code `tool-C23`) | 8.4.2 Field Reference / 9.3 | No — manual review / specification requirement (not one of the ten automated checks of agent-api §6.5.6: field values other than `id` / `application_type` / `platform` are not value-compared) |
| `exec` is `true` for Docker applications | Without it the App Center cannot start/stop the application | 8.4.2 Field Reference | No — manual review / specification requirement (not one of the ten automated checks of agent-api §6.5.6; metadata completeness is checked, field values are not value-compared) |
| A non-root `user` (UID:GID) is declared in every service | A missing `user` field defaults to root inside the container, which is a one-vote-veto rejection | 9.4 Image & Security Requirements / 10.3 | No — the API never reads `docker-compose.yml` |

> **Note:** these rows are specification / manual-review requirements — the Developer Platform API runs no `docker-compose.yml` checks at all (see 16.2). Developers can catch them locally before submission with `docker compose config -q` (13.2 Step 2).

#### Dependency Validation

| Check Item | Description | Reference | API Auto-Check |
|---|---|---|---|
| Docker app `depend` field must include `DockerEngine` | The Docker-specific field is defined in 9.2.1: `depend` is a `[]string` that must contain `DockerEngine` and may append other App IDs (installed in list order, no circular dependencies). Without it the Docker environment cannot be guaranteed ready at install time | 9.2.1 Docker-specific config.ini Fields | No — manual review / specification requirement (not one of the ten automated checks of agent-api §6.5.6: field values other than `id` / `application_type` / `platform` are not value-compared) |

> **Note (Deb vs Docker):** this item applies to **Docker applications only**. Deb applications do not use the `config.ini` `depend` field — their dependencies are declared in the `Depends` field of `DEBIAN/control`, and are validated as normal Debian package metadata (see §8.13 / Chapter 5).
>
> **Tool wording issue (recorded, not a specification change):** the self-test tool `TOSAppSelfTestingTool` currently reports that `relation` must contain `docker` / `DockerEngine`. That message does not match this specification, which requires the dependency to be declared in `depend`. The tool's wording is pending correction by R&D; the specification keeps `depend` as the correct field.

#### Version Rule Validation

| Check Item | Description | Reference | API Auto-Check |
|---|---|---|---|
| Version format, incrementation, and consistency required | The format and the numeric increment must comply with 4.2.1. Keep `config.ini` and `DEBIAN/control` in sync (see 4.2.2) | 4.2 Version Number Specification | **No** — the API never inspects version semantics: the Version Number only has to be non-empty, there is no semantic-version or ordering requirement, and duplicate version numbers may be submitted (agent-api §6.5.6). The release `tag` is never compared with `config.ini`'s `version`, and `.deb` control information is not read at all, so `config.ini` / `DEBIAN/control` consistency is out of scope for the API. This row is a specification requirement upheld by manual review |

#### Hash Validation

| Check Item | Description | Reference | API Auto-Check |
|---|---|---|---|
| The package's SHA-256 integrity is verified at review against the platform-generated baseline | No `.sha256` attachment is required at submission: when a version is submitted, the platform generates the `.sha256` value from the package and marks that package with it. Reviewers download the package and verify its integrity against that platform-generated value (see 16.3.2) | 8.15 Packaging & Checksums / 11.2 | **No** — the API never reads package signatures (agent-api §6.5.6). Integrity verification is carried out by review staff against the platform-generated baseline, not by automated validation |

**Result Notification:** Automated validation failure only shows a popup with error description and documentation link; no review ticket is generated. Developers fix and resubmit, which re-triggers automated validation. Only after all checks pass can the process proceed to the 16.2 Manual Review workflow.

### 16.2 Four Review Dimensions

> **Note:** This section describes the **manual review** that runs only after the §16.1 automated validation has passed. The items the platform explicitly does **not** validate automatically (agent-api §6.5.6) are handled here by review staff, so the two sections are complementary rather than contradictory. Platform-side checks that do run automatically — required files inside the package, the platform-validated `config.ini` fields (`help` required, `low_version` optional), icon format and size (see §16.1 **Platform Validation Items**) — already gate the submission; where the dimensions below list them again, review is re-confirming a result the platform has already produced, not running an independent rule.

| Dimension | Review Content | Reviewer |
|---|---|---|
| **Configuration Completeness** | config.ini correct JSON format, app.lang covering the documented 26-language set (coverage is a reminder only, not a rejection ground; see 8.5.1 / 8.5.9), required package metadata files complete (config.ini / `<appid>.lang` / icon), SVG-compliant icon within the accepted size range (≤ 50 KB), the platform-validated config.ini fields present (`help` **required**; `low_version` optional and may be left empty), valid systemd service file, App ID and the nginx names derived from it (`nginx/<appid>.conf`, the route prefix) do not start with the reserved `tos` prefix | Dedicated Review Staff |
| **Functional Availability** | Install/start/stop/uninstall complete without errors, correct architecture adaptation, functionality matches description, ports available without conflicts; access permission follows the platform permission model (see the note below and §8.3.2) | Testing Support Staff |
| **Security** | No hardcoded credentials, non-root execution, no privileged mode, no malicious code, no vulnerabilities, no prohibited scripts, hash verification passed | Technical Support Staff |
| **Compliance** | Content is legal and compliant, no intellectual property infringement, description matches functionality, repository is public, directory structure conforms to specification | Dedicated Review Staff |


> **Permission model reference (non-administrator access):** a non-administrator TOS user has **no permission to open an application page by default**. An administrator can authorize a non-administrator user, and a non-administrator user has **no App Center module permission** — the only entry point is the application icon on the desktop once authorization is granted. Review confirms that the application does not assume non-administrator availability (for example a UI that cannot be reached without App Center), does not document "all users can access" or "no permission required", and does not design an entry that bypasses the platform (see §8.3.2, §8.9 / §8.10).

#### Configuration Completeness — Detailed Checklist

**Required metadata files:**
- The package must contain `config.ini`, `<appid>.lang` and the icon file; missing any one of them is rejected
- See 8.2 General Directory Structure

**config.ini:**
- JSON without comments (`//`, `/* */`), no trailing commas
- No single quotes; all strings use double quotes
- All required fields present: `id` / `icon` / `publisher` / `exec` / `version` / `help` / `category` / `platform` / `application_type` / `user` — `help` **is required** (part of the platform-validated config.ini field list); `low_version` is optional, may be left empty and does not block submission
- `type` and `open_path` are mutually exclusive: Deb iframe apps use `type` only; Deb external-open and Docker apps use `open_path` only; the two must not coexist
- Docker apps with a UI must set `open_path: true` (and `path: "http://${ip}:<port>"`) — rejection code `tool-C23`; see 9.3 and 16.1
- `path` field must use `${ip}` placeholder; hardcoded IP, domain, or localhost is prohibited
- `version` / `system_id` / `package` version numbers consistent (see 4.2.2) — a specification requirement checked here at manual review: the platform's automated validation does not inspect version numbers at all (agent-api §6.5.6)
- `platform` field matches actual submitted package architecture
- `id` must not start with the reserved `tos` prefix — `tos` is reserved by the platform in the nginx route/command namespace; an `id` such as `tos-log-server` collides with the platform's own nginx entries and the application page cannot be opened normally (see 8.4.2 / 8.11)
- See 8.4 config.ini Specification

**app.lang:**
- Language set documentation baseline is the full 26-language set (supersets allowed): zh-cn, zh-hk, en-us, ko-kr, ja-jp, de-de, fr-fr, it-it, es-es, hu-hu, pl-pl, tr-tr, ru-ru, pt-pt, cs-cz, da-dk, nl-nl, nb-no, sv-se, el-gr, ro-ro, th-th, vi-vn, id-id, ar-sa, he-il (see 8.5.1)
- **Coverage shortfall is NOT a rejection ground.** The required set follows the version scope of 8.5.1: the first 14 languages for a TOS 7.0 application, all 26 from TOS 7.1 on. When an `app.lang` contains fewer sections than its required set, review does not reject the submission — it only reminds the developer to complete the set so the application is displayed in more language environments (see 8.5.9)
- `name` / `auth` / `descript` fields non-empty for all languages (`release_note` / `important` may be empty); blank strings and punctuation-only placeholders are not accepted — filling an untranslated language with the English text (an English copy) is acceptable
- File encoding UTF-8 without BOM
- All line endings LF (`\n`); CRLF (`\r\n`) prohibited
- Note: automated validation currently enforces only the 14 sections required by TOS 7.0 (zh-cn … pt-pt, agent-api §6.5.4); the 12 sections added from TOS 7.1 and full 26-language coverage are specification requirements not yet enforced by the API (see 8.5.9)
- See 8.5 app.lang Specification

**Icon:**
- SVG format, transparent background
- Contains a valid `viewBox` attribute
- Icon file size is within the platform-accepted range (≤ 50 KB; oversized icons are rejected)
- Icon file path exactly matches the `icon` field in config.ini (including case sensitivity) — this is a specification self-check: the platform reads the icon from the fixed path `usr/local/{AppID}/images/icons/{AppID}.svg` and does not compare it with the `icon` field (agent-api §6.5.6)
- See 8.6 Application Icons

**systemd (Deb apps only):**
- `User` / `Group` are non-root dedicated users
- Includes `StartLimitInterval` / `StartLimitBurst` startup limit parameters
- Includes `ProtectSystem=strict` or `ProtectSystem=full` system protection parameters
- Recommended: include `NoNewPrivileges=yes` / `PrivateTmp=yes` and other security hardening parameters
- See 8.12 Systemd Service Specification

**nginx (`.sock`-mode WebUI external-open apps only — a port-mode app serves its own page and ships no nginx file):**
- The package must ship `nginx/<app_id>.conf`; the file must not contain a `server {}` block — use `location /<app_id>/ {}` blocks only
- The portal block `location /<app_id>/` is **not required** to contain `proxy_pass`: a block carrying only `proxy_http_version` / `proxy_set_header` is compliant when the application ships its own frontend Web panel and directly provides the application address, with its service reachable through the application socket `/var/api/<app_id>.sock` (the sibling block `location ^~ /v2/proxy/<app_id>/` proxies to `unix:/var/api/<app_id>.sock`), so the portal block does not have to forward traffic itself
- Adding `proxy_pass http://127.0.0.1:<listen_port>/;` to the portal block is an **optional improvement**, not a review requirement, and must never be used as a ground for rejection; it is recorded as an advisory item in 12 §12.10 Optional Improvements (Advisory)
- A version must never be rejected or blocked on the ground that the portal block lacks `proxy_pass` (N03 withdrawn; the same calibration applies to all comparable applications, e.g. GitBucket / Sonarr)
- Where the portal block *does* carry `proxy_pass`, check that its port matches the backend listening port
- The nginx configuration file name `<app_id>.conf` and the route prefix `location /<app_id>/` are derived from the App ID and must **not** start with the reserved `tos` prefix — a `tos`-prefixed name collides with the platform's own nginx entries and the application page cannot be opened; automated validation does not read the nginx configuration, so this is upheld at manual review
- See 8.3.2.2 / 8.11 Nginx Configuration Specification (the nginx file is required only in the `.sock` access mode)

**Frontend–backend authentication (`Cookie` + `X-Csrf-Token`):**
- Every backend request carries **both** the `Cookie` and the `X-Csrf-Token` header — this is the **only** compliant channel; a missing header means the request is unauthenticated (`401`)
- A request carrying only the standard browser `Cookie` (without `X-Csrf-Token`) is **not** compliant and must not be accepted as a second, interchangeable channel; no Cookie-only fallback may be documented or implemented
- Session expiry / invalid token: the application sends the user to the **TOS login page** to log in and authorize again; it must not keep rendering the page, and must not construct its own `redirect` parameter (the return path after login is platform behaviour)
- Authenticated but unauthorized (for example a non-administrator without authorization): return `403` and show a "no permission" message — do not render the application content and do not fall back to the login page
- A **port-mode** page (§8.3.2.1) never passes through the platform proxy, so the platform cannot authenticate it — the application must implement its own access control there
- See 8.9 / 8.10 Authentication Specifications

#### Functional Availability — Detailed Checklist

- Installation process: no errors, no missing dependencies (`command not found`), non-preinstalled dependencies bundled
- Startup: service starts normally, port listening works, systemd status active
- Shutdown: service stops normally, no zombie processes left
- Uninstallation: installation directory and service files fully cleaned, no residual configuration
- Architecture adaptation: x86_64 / aarch64 dual architecture tested separately and passed
- Functionality matches description: all features described in `descript` in `app.lang` are actually usable
- Port check: does not occupy TOS system reserved ports, no conflict with other installed applications
- UI usability (if applicable): Web interface opens normally, no JS errors on page, first load time ≤ 5 seconds
- See 13 Local Testing & Debugging

#### Security — Detailed Checklist

- **Execution Privileges:** User/Group are non-root; `--privileged` privileged mode is prohibited
- **Credential Scanning:** No hardcoded passwords, API Keys, Tokens, or database connection strings
- **Network Behavior:**
  - Deb scripts (postinst/postrm, etc.) are prohibited from performing network operations such as `apt install`, `pip install`, `curl | bash`
  - Docker apps are prohibited from using `network_mode: host` (container network isolation)
  - Port mapping is reasonable; unnecessary ports are not exposed
- **Image Source:** Docker app images must originate from Docker Hub; using ghcr.io, quay.io, private registries, or other non-Docker Hub images is prohibited
- **File Permissions:** Reading/writing system-sensitive directories such as `/etc`, `/root`, `/boot` is prohibited
- **Code Scanning:** No malicious code (reverse shells, cryptocurrency miners, data theft), no known high-risk CVE vulnerabilities
- **Log Security:** No output of passwords, serial numbers, Tokens, or other sensitive information to logs
- **Hash Verification:** All review positions must verify that the package matches the platform-generated SHA-256 baseline before proceeding (see 16.3.2)
- See 11.3 Security Audit Requirements

#### Compliance — Detailed Checklist

- **Content Legality:** No illegal, violent, pornographic, gambling, or other prohibited content
- **Intellectual Property:** No infringement of TerraMaster or third-party trademarks, patents, or copyrights
- **Description Consistency:** `name`/`descript` in `app.lang` match actual functionality; no exaggerated claims
- **Repository Status:** GitHub/Gitee repository is public; README is complete
- **Directory Structure:** Conforms to 8.2 Common Directory Structure; no redundant or prohibited files
- **Open Source License:** If open source code is used, its license requirements must be observed and declared within the package
- **Privacy Compliance:** No unauthorized collection of user data; no unauthorized data upload
- See 15.2 Repository Requirements

### 16.3 Review Workflow

#### 16.3.1 Initial Review Phase
1. Dedicated review staff log into the Application Management Platform (https://mgmt.terra-master.com) and claim "Pending Initial Review" tasks
2. Download the application package under review, obtain the SHA-256 baseline generated by the platform for that package at submission, and record it
3. Verify information consistency: the application information submitted by the developer matches the content of the GitHub/Gitee repository
4. Verify repository compliance: repository is public, directory structure is complete, no redundant or prohibited files
5. Intellectual property compliance check: no infringement of TerraMaster or third-party intellectual property

**Initial Review Results:**
- ✅ Passed → Application status updated to "Pending Manual Review", enters the manual review phase
- ❌ Rejected → Detailed rejection reasons provided; developer notified through both channels for correction

#### 16.3.2 Hash Value Flow Verification
All review staff must first verify that the hash value of the downloaded package matches the baseline generated by the platform at submission before beginning their review work. The comparison value is always the one the platform generated when the version was submitted (a developer-supplied `.sha256` file, if any, is not the reference). If the hash value is abnormal, immediately pause and investigate.

#### 16.3.3 Manual Review Phase
Proceed in the following order:
1. **Technical Support Staff** → Security Review (security scanning, code security, network security, data compliance)
2. **Testing Support Staff** → Functionality & Compatibility Review (install/start/stop/uninstall testing, architecture adaptation, functional completeness)
3. **Dedicated Review Staff** → Compliance & Content Review, User Experience & Documentation Quality Review

Each position provides a clear review opinion (approve/reject with specific reasons). The Dedicated Review Staff consolidates the results into a comprehensive review outcome.

### 16.4 One-Vote Veto Items (any single item triggers immediate rejection; no further review needed)
- Application runs as root user
- Docker app uses privileged mode (`--privileged`)
- Docker app uses `network_mode: host` (container network isolation violation)
- Malicious code or data theft behavior detected
- Application ID duplicates an existing application
- **Data package (`<appid>.deb`) contains binary executable files** (except lifecycle scripts postinst/preinst/postrm/prerm under the `DEBIAN/` directory)
- Package integrity failure — the downloaded package does not match the platform-generated SHA-256 baseline
- Any language in app.lang has an empty `name`, `auth` or `descript` field (`release_note` / `important` may be empty; untranslated languages must carry the English text)
- config.ini uses single quotes or contains inline comments
- Submitted package architecture does not match the `platform` field in config.ini

### 16.5 Common Rejection Reasons (Sorted by Frequency)

| Rank | Rejection Reason | Correction Suggestion | Applicable Scope | Reference |
|---|---|---|---|---|
| 1 | config.ini contains comments, syntax errors, or missing fields (this issue is intercepted during the automated validation phase; developers receive an immediate prompt after submission.) | Remove all comments; validate JSON format with `python3 -m json.tool` | All apps | 8.4 config.ini Specification |
| 2 | app.lang is missing language nodes or has empty fields | Complete the documented 26-language set (see 8.5.1; supersets allowed) — incomplete coverage does **not** block submission, review only reminds the developer to complete it; fill any included untranslated language with English | All apps | 8.5 app.lang Specification / 8.5.9 |
| 3 | Docker compose image source is not from Docker Hub | Host images on Docker Hub; ghcr.io / private registries are prohibited | Docker only | 9.4 Image & Security Requirements |
| 4 | Repository is not public or resources are missing | Set repository to public; upload complete resources (README/source code/configurations) | All apps | 15.2 Repository Requirements |
| 5 | App functionality description does not match actual functionality | Correct the `descript` field in app.lang to ensure descriptions are verifiable | All apps | 8.5.3 Field Descriptions |
| 6 | Duplicate id field | Use a globally unique application ID; search and confirm on the platform before submission | All apps | 8.4.2 Field Reference |
| 7 | Icon format does not meet requirements or path does not match | Use SVG format (transparent background + viewBox); path must exactly match config.ini `icon` | All apps | 8.6 Application Icons |
| 8 | Deb package service cannot start/stop or has residual files after uninstall | Improve systemd service file and preinst/postinst/postrm lifecycle scripts | Deb only | 8.12 Systemd Service Specification |
| 9 | Docker port conflict, no data persistence (including a named volume that is referenced but not declared) | Ensure ports do not conflict with system reserved ports; persist data with a volume mount — declare named volumes **both** in the service and under the top-level `volumes:` key, or use a bind mount. A service-level reference alone makes Compose reject the project (`service "x" refers to undefined volume "y"`); run `docker compose config -q` before submitting | Docker only | 9.3 docker-compose.yml Specification |
| 10 | Deb package runs as root | Create a dedicated non-root user (UID ≥ 1000); specify User/Group in systemd | Deb only | 8.12 Systemd Service Specification |
| 11 | Script execution fails with `bad interpreter` | Check file line endings; ensure all `.sh` files use LF (not CRLF); use `dos2unix` for batch conversion | All apps | 4.6 Cross-Platform Line Ending Specification |
| 12 | Dependency not preinstalled; `command not found` | Use Go/Python implementations or bundle static dependencies; do not depend on non-preinstalled environments like Node.js/Java | Deb only | 2.4 System Preinstalled Dependencies |
| 13 | Docker app uses privileged mode | Remove `privileged: true`; use `cap_add` for fine-grained permissions instead | Docker only | 9.4 Image & Security Requirements |
| 14 | Package integrity does not match the platform-generated SHA-256 baseline (transmission corruption or tampering) — a missing `.sha256` attachment is **not** a rejection reason, since the platform generates the value itself at submission | Re-export and re-upload the package from the repository Release; verify that the Release asset is the build you intend to publish | All apps | 8.15 Packaging & Checksums / 11.2 |
| 15 | Docker app uses `network_mode: host` | Remove `network_mode: host`; use bridge network + port mapping instead | Docker only | 9.4 Image & Security Requirements |
| 16 | Submitted package architecture does not match the `platform` field | Ensure the `platform` in config.ini matches the binary architecture in the package (x86_64 / aarch64) | All apps | 8.4.2 Field Reference |
| 17 | app.lang has empty name/descript (in some language) | name and descript for all languages must be filled; untranslated languages use English as filler | All apps | 8.5.3 Field Descriptions |
| 18 | config.ini uses single quotes or contains inline comments | JSON only allows double-quoted strings; remove all `//` or `/* */` comments | All apps | 8.4 config.ini Specification |
| 19 | App ID starts with the reserved `tos` prefix (`tos-log-server`), so the nginx names derived from it (`nginx/tos-log-server.conf`, the route prefix) collide with the platform's own nginx entries | Choose an App ID that does not start with `tos` (e.g. `dev-log-server`) and rename the nginx configuration file and route prefix accordingly — automated validation does not check this, and it surfaces as "the application page cannot be opened"; the App ID cannot be modified after creation | All apps | 8.4.2 Field Reference / 8.11 Nginx Configuration Specification |

### 16.6 Rejection Correction Process

1. Review not passed → System notifies developer through dual channels: "Platform Message + Registered Email"
2. Developer logs into the Developer Platform to view rejection reasons and correction suggestions
3. Developer must fix the issues and resubmit within **30 days**
4. No resubmission after 30 days → Submission is automatically closed
5. Consecutive **3 automated validation failures** or **manual review rejections** both count toward the rejection count; after 3 consecutive rejections, the platform automatically generates a **Customer Service Consultation Ticket** (not a review ticket), with a technical specialist providing one-on-one assistance for corrections
6. **After successfully correcting and submitting a new version, the consecutive rejection count is automatically reset**: Once the developer completes corrections, submits a new version, and passes review, the historical rejection count resets to zero and is no longer accumulated
7. Resubmit after corrections → Re-enter the review workflow. Updating the version number is optional (the platform does not require it) but recommended, so users and reviewers can tell the corrected build apart.

**Permanent Restriction Terms:**

Under any of the following circumstances, the platform will **permanently close** the developer's application submission channel:
- Multiple submissions of malicious applications (containing viruses, trojans, cryptocurrency miners, ransomware, etc.)
- Multiple submissions of applications infringing third-party intellectual property rights
- Verified reports of data theft, backdoors, or other severe security violations
- Evasion or falsification of review materials (fake repositories, forged checksums, impersonation of others' identities, etc.)

Permanent restriction is an irreversible penalty. The platform will send a formal notification via email with supporting evidence. Developers may submit an appeal application through the platform's appeal channel within 15 business days.

### 16.7 Review Timelines

| Phase | Estimated Duration | Description |
|---|---|---|
| Automated Validation | Real-time | Completed instantly upon submission |
| Initial Review | 1–2 business days | Information consistency and repository compliance verification |
| Manual Review | 3–5 business days | Comprehensive security/functionality/compliance review |
| Publication & Listing | 1–2 business days | Listed in App Center after approval |

> The total review cycle is typically 5–9 business days (Initial Review 1–2 + Manual Review 3–5 + Publication & Listing 1–2). Initial review results from submission are usually available within 1–2 business days; you can check progress in real time on the Developer Platform. Peak periods may cause delays; please plan your submission timing accordingly.

---

← [Previous: Publishing Process](15_Publishing_Process.md) &nbsp;&nbsp;|&nbsp;&nbsp; [Next: Operations & Delisting](17_Operations_Delisting.md) → &nbsp;&nbsp;|&nbsp;&nbsp; [📖 Back to TOC](../README.md)
