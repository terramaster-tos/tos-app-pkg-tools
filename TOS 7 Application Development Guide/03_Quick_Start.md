
# 3. Quick Start

This chapter helps developers complete their first TOS 7 application development and publishing in 5 minutes.

## 3.1 Prerequisites

- A TNAS device running TOS 7.0 (current stable/beta version) — **recommended but optional**

  > 💡 **No TNAS hardware?** No problem. You can develop TOS applications without owning a physical TNAS device. As long as your development environment meets the recommended setup (see [Chapter 6 · Development Environment](06_Development_Environment.md#testing-environment-options)), you can build and test your application using alternatives such as Ubuntu 22.04 VM or a remote testing device.

- Basic Linux command line skills
- GitHub or Gitee account (for code hosting and developer platform integration)

## 3.2 Five-Step Publishing Process

**Step 1: Register a Developer Account**

Visit the [TOS Developer Platform](https://developer.terra-master.com), register and complete developer verification.

**Step 2: Choose Application Type**

| Your Application Characteristics | Recommended Type |
|---|---|
| Native binary, Python scripts (leveraging system pre-installed Python 3.10), lightweight system services | Deb Application |
| Requires isolated runtime environment, complex dependencies, multi-container architecture | Docker Application |

> ⚠️ **Note:** Language runtimes such as Node.js, Java, and Go are not pre-installed in TOS. Deb applications cannot directly depend on them. See [Chapter 2 · Architecture Strategy](02_Architecture_Strategy.md).

**Step 3: Choose a Project Template**

Based on your application type, use the corresponding GitHub template repository:

| Template Repository | Packaging Method | Applicable Scenarios |
|---|---|---|
| [Deb App Template (Single Package)](https://github.com/TerraMasterOfficial/app-pkg-tools/tree/main/TOS%207-template-deb-single) | Single-package mode | New applications built from scratch; all files packaged together |
| [Deb App Template (Dual Package)](https://github.com/TerraMasterOfficial/app-pkg-tools/tree/main/TOS%207-template-deb-dual) | Dual-package mode | Applications that already have a universal standard deb package |
| [Docker App Template](https://github.com/TerraMasterOfficial/app-pkg-tools/tree/main/TOS%207-template-docker) | Docker | Docker containerized deployment |

> ⚠️ **Note:** Subtype (WebUI Internal/External/Headless) and packaging method (single/dual package) are two independent dimensions and can be cross-combined. Both single and dual packages support all three subtypes.

> Each template repository includes: complete directory structure, config.ini, multilingual files, systemd service, frontend/backend example code, lifecycle scripts, build script (build.sh), GitHub Actions CI/CD configuration. Click the **"Use this template"** button on the repository page to create your project.

**Step 4: Local Development and Testing**

```bash
# Deb App: Build and test installation
dpkg-deb --build ./<app_root_directory> ./<appid>_<version>_<arch>.deb
sudo dpkg -i <appid>_<version>_<arch>.deb
sudo systemctl status <system_id>

# Docker App: Start testing
docker-compose up -d
curl http://localhost:<port>/health
```

**Step 5: Submit for Review**

1. Push your code to a public GitHub or Gitee repository
2. Create a Release in your repository and upload the package file as a Release asset (see [Chapter 15 · Step 3](15_Publishing_Process.md#step-3-create-a-release-and-upload-package-assets) for detailed naming and format requirements)
3. Create an application entry on the developer platform and link your GitHub/Gitee repository
4. Submit the application for review; the platform will automatically pull the package from your Release and run automated validation, followed by manual review
5. After approval, the application will be published to the TOS App Center

> 📝 **Note:** The developer platform automatically retrieves the application package from your GitHub/Gitee Release. No manual upload is required. For detailed package format, naming, and Release requirements, see [Chapter 15 · Publishing Process](15_Publishing_Process.md).

## 3.3 Key Checklist

Before submitting to the review platform, verify the following items:

- [ ] `config.ini` is valid JSON format (no comments, no trailing commas, double quotes only)
- [ ] `app.lang` includes all 14 languages (untranslated languages filled with English)
- [ ] Icon is in SVG format, stored at `/images/icons/<appid>.svg`
- [ ] systemd service file `User` is not `root`
- [ ] Version number is strictly incremented and consistent across `config.ini` and `DEBIAN/control`
- [ ] Full install/start/stop/uninstall workflow tested on a real TNAS device or alternative testing environment (see [Chapter 6 · Development Environment](06_Development_Environment.md#testing-environment-options))

> 💡 **No TNAS hardware?** No problem. You can develop and test TOS applications without owning a physical TNAS device. As long as your development environment meets the recommended setup (see [Chapter 6 · Development Environment](06_Development_Environment.md#testing-environment-options)), alternatives such as Ubuntu 22.04 VM or a remote testing device work just as well.

## 3.4 Common Pitfalls to Avoid

Before beginning formal development, pay special attention to the two most common cross-platform issues below to avoid rejection after submission:

### Top 1: Line Ending Issues (CRLF to LF)

- **Symptom:** Scripts edited on Windows report `bad interpreter: No such file or directory` after being deployed to TOS
- **Root Cause:** Windows defaults to CRLF line endings; Linux only recognizes LF
- **Solution:** Ensure all scripts and configuration files use LF line endings before submission

```bash
# Quickly check for CRLF files in your project
grep -rl $'\r' *.sh *.py *.ini *.lang *.service *.conf 2>/dev/null

# One-click conversion (Linux/macOS)
sed -i 's/\r$//' *.sh *.py *.ini *.lang *.service *.conf
```

For detailed specifications, see [Chapter 4 · Package Specification — Cross-Platform Line Ending](04_Package_Specification.md#cross-platform-line-ending).

### Top 2: Missing Node.js Dependencies

- **Symptom:** Application reports `node: command not found` on startup
- **Root Cause:** TOS does not pre-install Node.js; Deb applications cannot directly depend on the Node.js runtime
- **Solution:** Use Go to compile static binaries, or use Python 3.10 (pre-installed in the system)

For more strategies, see [Chapter 2 · Architecture Strategy — Handling Non-Pre-installed Dependencies](02_Architecture_Strategy.md#handling-non-pre-installed-dependencies).


← [Previous Chapter: Architecture Strategy](02_Architecture_Strategy.md) &nbsp;&nbsp;|&nbsp;&nbsp; [Next Chapter: Package Specification](04_Package_Specification.md) → &nbsp;&nbsp;|&nbsp;&nbsp; [📖 Back to Table of Contents](../README.md)
