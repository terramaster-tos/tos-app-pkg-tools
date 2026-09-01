
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
   - **Tag version**: Must exactly match the `version` field in `config.ini` (format: `xx.yy.zzz`). Prefix `v` is optional but recommended (e.g., `v1.0.0` or `1.0.0`)
   - **Release title**: Recommended to use the same version string (e.g., `v1.0.0`)
   - **Attach binaries**: Upload the package file(s) as release assets following the naming conventions below

3. **Package Asset Naming and Content Requirements**

   The package file must follow the naming conventions below. Version numbers are **not** included in the file name — they are specified through the Release tag.

   | Application Type | Required Asset Format | Naming Convention | Content Requirements |
   |---|---|---|---|
   | Deb (Single Package) | `.deb` file | `<app_id>_<platform>.deb` | Single deb package containing all application files, configuration, and metadata |
   | Deb (Dual Package) | `.tar.gz` archive | `<app_id>_<platform>.tar.gz` | Must contain `<app_id>.deb` (data package) and `<package>.deb` (source package) |
   | Docker Application | `.tar.gz` archive | `<app_id>.tar.gz` | Must contain `docker-compose.yml`, `config.ini`, `app.lang`, and icon files |

   **Field Definitions:**
   - `<app_id>`: Must exactly match the `id` field in `config.ini`
   - `<platform>`: Must exactly match the `platform` field in `config.ini` and must be one of the two supported values (`x86_64` or `aarch64`). It does not accept multiple values or `"all"`. For multi-architecture support, each target architecture must be submitted as a separate build, and the package file name must include the appropriate architecture suffix.
   - `<package>`: Must match the `package` field in `config.ini` (for dual-package mode)

   > **Important:**
   > - **Version numbers are not included in the package file name.** The version is specified via the Release tag.
   > - **The Release tag must exactly match the `version` field in `config.ini`.**
   > - The platform validates version consistency between the Release tag and `config.ini.version`. Mismatches will result in automated rejection.
   > - **The platform pulls packages exclusively from Releases, not from the repository root.**
   > - **You may upload both `x86_64` and `arm64` packages for the same application version in a single GitHub/Gitee Release. The platform will automatically pull the appropriate package based on the architecture you selected when creating the application (this feature is not yet implemented; for now, please ensure that each Release contains only one architecture package).**
   > - **Only the formats and naming conventions listed above are supported.** Non-compliant names will result in automated rejection.

4. **Include SHA-256 checksum files**

   For every package asset uploaded, generate and attach a corresponding `.sha256` checksum file:
   ```bash
   sha256sum <package_file> > <package_file>.sha256
   ```

   Example: `myapp_x86_64.deb` → `myapp_x86_64.deb.sha256`

#### Step 4: Create an Application on the Developer Platform

1. Log in to the Developer Platform, click [My Applications] → [Add Application]
2. Fill in application information:
   - **Application ID**: Must exactly match the `id` field in config.ini
   - **Application Package Type**: Choose Docker or Deb package type
   - **Repository URL**: Provide the public repository URL (must be public, otherwise review cannot proceed)
3. Confirm and submit the creation

#### Step 5: Add a New Application Version

1. Find the target application under [My Applications] and click [Version Management]
2. Click [Add Version] and fill in the version number
   - Version number format: strictly follow `xx.yy.zzz` (major.minor.patch)
   - Historical version numbers cannot be reused
   - Must match the `version` field in config.ini
3. After submitting the version, the publishing application process begins

> **Version Consistency Requirement:**
> The version number you enter in Step 5 must match:
> 1. The `version` field in `config.ini`
> 2. The Release tag version created in Step 3
>
> **All three must be identical.** Mismatches will result in automated rejection.

#### Step 6: Platform Automated Validation

After submission, the platform automatically performs the following checks:
- File format validation (config.ini JSON syntax, app.lang format)
- Field completeness validation (no missing required fields)
- Language coverage validation (all 14 language nodes present)
- Icon validation (SVG format, path matching)
- Checksum verification (SHA-256 matches uploaded files)
- Version consistency validation (config.ini / DEBIAN/control / app.lang version match; Docker apps only check config.ini and app.lang version consistency, no DEBIAN/control check needed)
- Release tag vs config.ini.version consistency validation

**Common causes of automated validation failure:**
- config.ini contains comments or syntax errors
- app.lang is missing language nodes
- Icon not found or incorrect format
- Checksum mismatch
- Release tag does not match config.ini.version
- Package file name does not follow the required naming convention

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
