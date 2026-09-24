
# 15. Publishing Process

### 15.1 Detailed Operation Workflow

#### Step 1: Register a Developer Account

1. Visit the TOS Developer Platform: https://developer.terra-master.com
2. Click the [Register] button to enter the registration information page
3. Use a valid email address as your login account and fill in your developer name (it is recommended to keep it consistent with the `publisher` field in the configuration file)
4. Read and agree to the terms of service, then click [Confirm] to complete registration
5. Email verification is required after registration; the account takes effect immediately with no manual review needed.

> **Note:** The account email is used to receive review result notifications, password resets, and other important information. Please keep your email valid.

#### Step 2: Obtain Configuration Templates and Develop Your Application

1. Refer to the standard templates in Chapter 8 (Deb Application Development & Configuration Specification) of this document to write config.ini, app.lang, systemd service files, and other configurations, or use the recommended project template repository on the TOS Developer Platform for quick initialization
2. Complete application development and packaging according to this document's specifications
3. Perform local testing and verification (see Chapter 13)

#### Step 3: Create a Release and Upload Package Assets

1. Create a public repository on GitHub or Gitee

2. **Create a Release and Upload Package Assets**

   The platform pulls application packages **exclusively from Releases** (GitHub Releases or Gitee Releases). **Do not** upload package files directly to the repository root.

   **Step-by-step:**
   - Go to the "Releases" page of your repository
   - Click "Create a new release" (GitHub) or "新建发行版" (Gitee)
   - **Tag version**: Any tag is accepted. Naming it after the version (e.g., `v1.0.0` or `1.0.0`) is recommended for readability, but it does not have to match `config.ini.version`. You will select this tag when submitting the version.
   - **Release title**: Recommended to use the same version string (e.g., `v1.0.0`)
   - **Attach binaries**: Upload the package file(s) as release assets following the naming conventions below

3. **Package Asset Naming and Content Requirements**

   Name the package file as shown below. The platform identifies the package type from the file extension (`.deb` = single package, `.tar.gz` = dual-package archive or Docker package). The version is read from `config.ini`, so it does not need to appear in the file name. **The file name itself is not validated** — the recommended names below only make it easier to pick the right asset. Identity is checked after the package is downloaded and parsed, by comparing `config.ini` with the application information you entered on the Developer Platform.

   | Application Type | Required Asset Format | Naming Convention | Content Requirements |
   |---|---|---|---|
   | Deb (Single Package) | `.deb` file | `<app_id>_<platform>.deb` | Single deb package containing all application files, configuration, and metadata |
   | Deb (Dual Package) | `.tar.gz` archive | `<app_id>_<platform>.tar.gz` | Must contain `<app_id>.deb` (data package) and `<package>.deb` (source package) |
   | Docker Application | `.tar.gz` archive | `<app_id>.tar.gz` | Must contain `docker-compose.yml`, `config.ini`, `app.lang`, and icon files |

   **Field Definitions:**
   - `<app_id>`: Recommended to match the `id` field in `config.ini`
   - `<platform>`: Recommended to match the `platform` field in `config.ini` and be one of the two supported values (`x86_64` or `aarch64`). It does not accept multiple values or `"all"`. For multi-architecture support, each target architecture must be submitted as a separate build, and it helps to include the architecture suffix in the file name so the correct asset is easy to pick when submitting. The platform does not read the architecture from the file name.
   - `<package>`: Should match the `package` field in `config.ini` (for dual-package mode)

   > **Important:**
   > - **The version is read from the `version` field in `config.ini`.** It does not need to appear in the file name or in the Release tag.
   > - **The platform pulls packages exclusively from Releases, not from the repository root.**
   > - **You may upload multiple packages (e.g., different architectures) in a single GitHub/Gitee Release.** When you submit the version, the platform lists every package found in the repository's Releases, and you select the one to submit.
   > - **Make sure the package you select matches the application type and architecture you declared when creating the application.** For example, do not submit an `aarch64` package for an application declared as `x86_64`.
   > - **Do not mix packaging formats for the same application ID in a single Release** (e.g., both a `.deb` and a `.tar.gz`). The platform tells single-package Deb (`.deb`) apart from dual-package Deb / Docker (`.tar.gz`) by the file extension, so a Release should contain a single format.
   > - **You are responsible for selecting the correct package.** Submitting the wrong package will cause the version to fail review.

4. **Include SHA-256 checksum files**

   For every package asset uploaded, generate and attach a corresponding `.sha256` checksum file:
   ```bash
   sha256sum <package_file> > <package_file>.sha256
   ```

   Example: `myapp_x86_64.deb` → `myapp_x86_64.deb.sha256`

#### Step 4: Create an Application on the Developer Platform

1. Log in to the Developer Platform, click [My Applications] → [Add Application]
2. Fill in the application information — **only four fields are required**:
   - **Application ID**: Must exactly match the `id` field in config.ini
   - **Application Package Type**: Choose `Deb` or `Docker`
   - **Architecture**: Choose `x86_64` or `aarch64`
   - **Repository URL**: Provide the public repository URL (must be public, otherwise review cannot proceed)
3. Confirm and submit the creation

> **Note:** Create the application first, then submit a version. No version number is entered at creation time — the platform takes the version from the package you select in the next step. After the package is downloaded and parsed, the platform compares the application information inside `config.ini` (`id`, `platform`, and package type) with the information you entered here and proceeds only if they match.

#### Step 5: Submit a New Application Version

1. Find the target application under [My Applications] and click [Version Management]
2. Click [Add Version]. The platform calls the repository interface and returns **all installable packages found in the Releases** of the repository URL configured for the application
3. Select the Release (tag) and the package file you want to submit
   - Do **not** enter a version number manually — it is read from the `version` field inside the selected package
   - Reusing or lowering a version number is no longer rejected, but the App Center detects updates by comparing versions numerically — a version that is not greater than the installed one will not reach existing users as an update
   - The Release and its assets must remain available, because the platform downloads the package from the selected Release at review time
4. After submitting the version, the publishing application process begins

> **Version source and consistency:**
> The version comes from the package itself, always from the `version` field in `config.ini`. There is no manually entered version number, and the Release tag is not required to match the version.
>
> The platform does **not** validate the version — not its format, not incrementation, and not whether it matches `DEBIAN/control`. Note however that the App Center detects updates by comparing version numbers numerically, so a version that is not greater than the installed one will not be offered to existing users as an update.

#### Step 6: Platform Automated Validation

After submission, the platform automatically performs the following checks:
- File format validation (config.ini JSON syntax, app.lang format)
- Field completeness validation (no missing required fields)
- Language coverage validation (all 14 language nodes present)
- Icon validation (SVG format, path matching)
- Checksum verification (SHA-256 matches uploaded files)
- Package type validation (the selected package's format matches the declared Deb / Docker application type)

**Common causes of automated validation failure:**
- config.ini contains comments or syntax errors
- app.lang is missing language nodes
- Icon not found or incorrect format
- Checksum mismatch
- The selected package does not match the declared application type or architecture

#### Step 7: Manual Review

The review team reviews from four dimensions (see Chapter 16 for details):
1. **Configuration Completeness** (weight 30%): All required files present, correct format
2. **Functional Availability** (weight 35%): Install, start, run, uninstall all function without errors
3. **Security** (weight 25%): No malicious code, no excessive authorization, no hardcoded sensitive data
4. **Compliance** (weight 10%): Content compliance, description matches functionality

Review workflow: Initial Review (information consistency, repository compliance) → Security Review (technical support staff) → Functional Compatibility Testing (testing support staff) → Comprehensive Review (dedicated review staff)

#### Step 8: Review Result Notification

Review results are delivered to developers through two channels:
- **Platform Messages**: Log in to the Developer Platform to check review status
- **Registered Email**: Review results are sent to the email used during registration

Review status descriptions:
- **Under Review**: Application is in the review queue
- **Approved**: Application has passed review and entered the publishing process
- **Rejected**: Application has issues that need correction; must be fixed and resubmitted within 30 days
- **Voluntarily Withdrawn**: Developer has proactively withdrawn the review application

#### Step 9: Official Publication

After passing the review, the application will be listed on the TOS App Center within 1-2 business days:
- Users can search for and install the application in the App Center
- Developers can check the application status change to "Published" under [My Applications]

> **Statistics:** The developer dashboard displays core data such as the number of published apps, total app downloads, and cumulative app submissions. The progress of the 3 most recent publishing applications is updated in real time.

### 15.2 Repository Requirements

- Must be a **public repository** (GitHub or Gitee). Private repositories are not supported.
- Package files must be uploaded as **Release assets**, not to the repository root.
- Repository resources must remain available long-term. Published resources cannot be deleted.
- The repository structure must conform to the specified directory layout.
- All binary artifacts must be accompanied by SHA-256 checksum files.

**Application Renaming and ID Change Policy:**
- The application `id` (in config.ini) **cannot be changed** once published
- The application display name (in app.lang) can be updated in new versions
- If the application `id` needs to be changed, it must be submitted as a brand new application (new listing, new review)
- The old application must go through the application delisting process (see Section 17.4)

---

← [Previous: CICD Guide](14_CICD_Guide.md) &nbsp;&nbsp;|&nbsp;&nbsp; [Next: Review Standards](16_Review_Standards.md) → &nbsp;&nbsp;|&nbsp;&nbsp; [📖 Back to TOC](../README.md)
