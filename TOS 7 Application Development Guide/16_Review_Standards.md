# 16. Review Standards

### 16.1 Submission Automated Validation (Pre-filter)

**Trigger Timing:** Executed in real time after a new version is submitted on the Developer Platform . Validation failure results in immediate blocking; no review ticket is generated and no initial review is entered.

**Validation Coverage:**

#### config.ini Validation

| Check Item | Description | Reference |
|---|---|---|
| Valid JSON syntax (no comments, no trailing commas, no single quotes outside double quotes) | Validate using `python3 -m json.tool` | 8.4 config.ini Specification |
| No single quotes, no inline comments | JSON standard only allows double quotes; `//` or `/* */` are treated as comments | 8.4 config.ini Specification |
| All required fields present (id/version/system_id/package/platform/type/name/icon/path, etc.) | Check against the required fields checklist item by item | 8.4.3 Key Rules |
| type and open_path are mutually exclusive (both cannot exist) | Docker apps use the `type` field, Deb apps use the `open_path` field | 8.4.2 Field Reference |
| path field must use `${ip}` placeholder; no hardcoded IP or domain | All URL-type path must be written as `https://${ip}:port/` | 8.4.3 Key Rules |
| version / system_id / package version numbers are consistent | version numbers in config.ini and DEBIAN/control must match | 4.2 Version Number Specification |
| platform field matches the actual submitted package architecture | e.g., if platform declares `x86_64`, binaries in the package must be x86_64 architecture | 8.4.2 Field Reference |

#### app.lang Validation

| Check Item | Description | Reference |
|---|---|---|
| All 14 language nodes present (keys complete) | Missing any language node results in immediate blocking | 8.5 app.lang Specification |
| name / descript fields non-empty for all languages | Empty fields must be filled with English translations; blank strings not allowed | 8.5.3 Field Descriptions |
| File encoding is UTF-8 without BOM | EF BB BF bytes not allowed at file header | 8.5.5 File Encoding & Format |
| All line endings must be LF (\\n); CRLF (\\r\\n) prohibited | A common cross-platform collaboration issue; Windows developers must pay extra attention | 4.6 Cross-Platform Line Ending Specification |

#### Resource File Validation

| Check Item | Description | Reference |
|---|---|---|
| Icon format is SVG | PNG/JPG/ICO or other bitmap formats are not accepted | 8.6 Application Icons |
| SVG has transparent background, valid viewBox | viewBox attribute must exist with reasonable values | 8.6 Application Icons |
| Icon file path exactly matches the `icon` field in config.ini | Including case sensitivity and directory hierarchy | 8.6 Application Icons |
| All script files (.sh/.py/.pl) must not use CRLF line endings | Unified LF line endings | 4.6 Cross-Platform Line Ending Specification |

#### Package Structure Validation

| Check Item | Description | Reference |
|---|---|---|
| Dual-package data package (data.tar.gz) must not contain binary executable files (except lifecycle scripts such as postinst/preinst under the DEBIAN directory) | Business programs and runtime binaries must not appear in the data package | 8.17 Dual-Package Mode Specification |
| Directory name case compliance (all lowercase, consistent with config.ini declarations) | Linux file system is case-sensitive | 8.2 Common Directory Structure |

#### Dependency Validation

| Check Item | Description | Reference |
|---|---|---|
| Docker app `depend` field must include `DockerEngine` | Without it, the Docker environment cannot be guaranteed ready at install time | 5.2 Declaring Runtime Dependencies |

#### Version Rule Validation

| Check Item | Description | Reference |
|---|---|---|
| Version number must be strictly greater than the last published version (e.g., 1.0.1 > 1.0.0) | Version rollback or duplicate submission is prohibited | 4.2 Version Number Specification |
| Version number must not contain informal suffixes such as `beta` / `alpha` / `rc` | Pre-release identifiers must be removed for official publication versions | 4.2 Version Number Specification |

#### Hash Validation

| Check Item | Description | Reference |
|---|---|---|
| The SHA-256 of the uploaded package must exactly match the declared sha256 at submission | Prevents transmission corruption or tampering | 8.15 Packaging & Checksums |

**Result Notification:** Automated validation failure only shows a popup with error description and documentation link; no review ticket is generated. Developers fix and resubmit, which re-triggers automated validation. Only after all checks pass can the process proceed to the 16.2 Manual Review workflow.

### 16.2 Four Review Dimensions

| Dimension | Review Content | Reviewer |
|---|---|---|
| **Configuration Completeness** | config.ini correct JSON format, app.lang with all 14 languages, SVG-compliant icon, no missing required fields, valid systemd service file | Dedicated Review Staff |
| **Functional Availability** | Install/start/stop/uninstall complete without errors, correct architecture adaptation, functionality matches description, ports available without conflicts | Testing Support Staff |
| **Security** | No hardcoded credentials, non-root execution, no privileged mode, no malicious code, no vulnerabilities, no prohibited scripts, hash verification passed | Technical Support Staff |
| **Compliance** | Content is legal and compliant, no intellectual property infringement, description matches functionality, repository is public, directory structure conforms to specification | Dedicated Review Staff |

#### Configuration Completeness — Detailed Checklist

**config.ini:**
- JSON without comments (`//`, `/* */`), no trailing commas
- No single quotes; all strings use double quotes
- All required fields present: `id` / `version` / `system_id` / `package` / `platform` / `type` / `name` / `icon` / `path`, etc.
- `type` and `open_path` mutually exclusive: Docker apps use `type` only; Deb apps use `open_path` only
- `path` field must use `${ip}` placeholder; hardcoded IP, domain, or localhost is prohibited
- `version` / `system_id` / `package` version numbers consistent
- `platform` field matches actual submitted package architecture
- See 8.4 config.ini Specification

**app.lang:**
- All 14 language nodes present (zh-cn, zh-hk, en-us, fr-fr, de-de, it-it, es-es, hu-hu, ja-jp, ko-kr, pl-pl, ru-ru, tr-tr, pt-pt)
- `name` / `descript` fields non-empty for all languages; empty fields must be filled with English translations
- File encoding UTF-8 without BOM
- All line endings LF (`\n`); CRLF (`\r\n`) prohibited
- See 8.5 app.lang Specification

**Icon:**
- SVG format, transparent background
- Contains a valid `viewBox` attribute
- Icon file path exactly matches the `icon` field in config.ini (including case sensitivity)
- See 8.6 Application Icons

**systemd (Deb apps only):**
- `User` / `Group` are non-root dedicated users
- Includes `StartLimitInterval` / `StartLimitBurst` startup limit parameters
- Includes `ProtectSystem=strict` or `ProtectSystem=full` system protection parameters
- Recommended: include `NoNewPrivileges=yes` / `PrivateTmp=yes` and other security hardening parameters
- See 8.12 Systemd Service Specification

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
- **Hash Verification:** All review positions must verify SHA-256 matches the baseline before proceeding
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
2. Download the application package under review, obtain the baseline SHA-256 hash, and record it
3. Verify information consistency: the application information submitted by the developer matches the content of the GitHub/Gitee repository
4. Verify repository compliance: repository is public, directory structure is complete, no redundant or prohibited files
5. Intellectual property compliance check: no infringement of TerraMaster or third-party intellectual property

**Initial Review Results:**
- ✅ Passed → Application status updated to "Pending Manual Review", enters the manual review phase
- ❌ Rejected → Detailed rejection reasons provided; developer notified through both channels for correction

#### 16.3.2 Hash Value Flow Verification
All review staff must first verify that the hash value matches the baseline hash value before beginning their review work. If the hash value is abnormal, immediately pause and investigate.

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
- Checksum mismatch
- Any language in app.lang has empty `name` or `descript` field
- config.ini uses single quotes or contains inline comments
- Submitted package architecture does not match the `platform` field in config.ini

### 16.5 Common Rejection Reasons (Sorted by Frequency)

| Rank | Rejection Reason | Correction Suggestion | Applicable Scope | Reference |
|---|---|---|---|---|
| 1 | config.ini contains comments, syntax errors, or missing fields (this issue is intercepted during the automated validation phase; developers receive an immediate prompt after submission.) | Remove all comments; validate JSON format with `python3 -m json.tool` | All apps | 8.4 config.ini Specification |
| 2 | app.lang is missing language nodes or has empty fields | Complete all 14 languages; fill untranslated ones with English | All apps | 8.5 app.lang Specification |
| 3 | Docker compose image source is not from Docker Hub | Host images on Docker Hub; ghcr.io / private registries are prohibited | Docker only | 9.4 Image & Security Requirements |
| 4 | Repository is not public or resources are missing | Set repository to public; upload complete resources (README/source code/configurations) | All apps | 15.2 Repository Requirements |
| 5 | App functionality description does not match actual functionality | Correct the `descript` field in app.lang to ensure descriptions are verifiable | All apps | 8.5.3 Field Descriptions |
| 6 | Duplicate id field | Use a globally unique application ID; search and confirm on the platform before submission | All apps | 8.4.2 Field Reference |
| 7 | Icon format does not meet requirements or path does not match | Use SVG format (transparent background + viewBox); path must exactly match config.ini `icon` | All apps | 8.6 Application Icons |
| 8 | Deb package service cannot start/stop or has residual files after uninstall | Improve systemd service file and preinst/postinst/postrm lifecycle scripts | Deb only | 8.12 Systemd Service Specification |
| 9 | Docker port conflict, no data persistence | Ensure ports do not conflict with system reserved ports; add volumes for data persistence | Docker only | 9.3 docker-compose.yml Specification |
| 10 | Version number not incremented | New version number must be strictly greater than the previous version; rollback or duplicate submission prohibited | All apps | 4.2 Version Number Specification |
| 11 | Deb package runs as root | Create a dedicated non-root user (UID ≥ 1000); specify User/Group in systemd | Deb only | 8.12 Systemd Service Specification |
| 12 | Script execution fails with `bad interpreter` | Check file line endings; ensure all `.sh` files use LF (not CRLF); use `dos2unix` for batch conversion | All apps | 4.6 Cross-Platform Line Ending Specification |
| 13 | Dependency not preinstalled; `command not found` | Use Go/Python implementations or bundle static dependencies; do not depend on non-preinstalled environments like Node.js/Java | Deb only | 2.4 System Preinstalled Dependencies |
| 14 | Docker app uses privileged mode | Remove `privileged: true`; use `cap_add` for fine-grained permissions instead | Docker only | 9.4 Image & Security Requirements |
| 15 | Checksum mismatch or missing checksum file | Regenerate SHA-256 checksum; ensure the uploaded package matches the submitted declaration | All apps | 8.15 Packaging & Checksums |
| 16 | config.ini and DEBIAN/control version numbers are inconsistent | Ensure version numbers match between config.ini and DEBIAN/control; recommend using scripts for automatic synchronization | Deb only | 4.2 Version Number Specification |
| 17 | Docker app uses `network_mode: host` | Remove `network_mode: host`; use bridge network + port mapping instead | Docker only | 9.4 Image & Security Requirements |
| 18 | Submitted package architecture does not match the `platform` field | Ensure the `platform` in config.ini matches the binary architecture in the package (x86_64 / aarch64) | All apps | 8.4.2 Field Reference |
| 19 | app.lang has empty name/descript (in some language) | name and descript for all languages must be filled; untranslated languages use English as filler | All apps | 8.5.3 Field Descriptions |
| 20 | config.ini uses single quotes or contains inline comments | JSON only allows double-quoted strings; remove all `//` or `/* */` comments | All apps | 8.4 config.ini Specification |

### 16.6 Rejection Correction Process

1. Review not passed → System notifies developer through dual channels: "Platform Message + Registered Email"
2. Developer logs into the Developer Platform to view rejection reasons and correction suggestions
3. Developer must fix the issues and resubmit within **30 days**
4. No resubmission after 30 days → Submission is automatically closed
5. Consecutive **3 automated validation failures** or **manual review rejections** both count toward the rejection count; after 3 consecutive rejections, the platform automatically generates a **Customer Service Consultation Ticket** (not a review ticket), with a technical specialist providing one-on-one assistance for corrections
6. **After successfully correcting and submitting a new version, the consecutive rejection count is automatically reset**: Once the developer completes corrections, submits a new version, and passes review, the historical rejection count resets to zero and is no longer accumulated
7. Resubmit after corrections → Update the version number and re-enter the review workflow under the new version

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

> The total review cycle is typically 5–8 business days. Initial review results from submission are usually available within 1–2 business days; you can check progress in real time on the Developer Platform. Peak periods may cause delays; please plan your submission timing accordingly.

---

← [Previous: Publishing Process](15_Publishing_Process.md) &nbsp;&nbsp;|&nbsp;&nbsp; [Next: Operations & Delisting](17_Operations_Delisting.md) → &nbsp;&nbsp;|&nbsp;&nbsp; [📖 Back to TOC](../README.md)
