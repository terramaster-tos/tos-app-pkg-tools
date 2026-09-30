
# 6. Development Environment

TOS 7 employs a root filesystem compatible with **Ubuntu 22.04 LTS (Jammy Jellyfish)**. To ensure binary compatibility and consistent dependency library versions, developers must build their development environment based on Ubuntu 22.04.

## 6.1 System Base

**Recommended Development Environment Options:**

| Option | Description | Best For |
|--------|-------------|----------|
| Ubuntu 22.04 Physical Machine / VM (arm64) | Native ARM64 environment; compile and run directly, no cross-compilation needed | Developers with ARM hardware or willing to use ARM VMs |
| Docker Container (`arm64v8/ubuntu:22.04`) | Run ARM64 container on x86 host via QEMU emulation | x86 developers who prefer containerized workflows |
| x86 Host + Cross-Compilation | Install cross-compilation toolchains on x86 dev machine, cross-compile to **produce binaries targeting the TNAS platform** | Most common setup for x86 developers |

> **Key Principle:** Regardless of the chosen approach, the APT sources and package versions used in the development environment must align with TOS 7's root filesystem (Ubuntu 22.04 compatible) to avoid runtime errors caused by glibc, OpenSSL, and other core library version mismatches.

## 6.2 Supported Target Architectures

TNAS provides both **arm64** and **amd64** hardware architectures. Applications must provide separate builds for each target architecture. Multi-architecture support requires separate submissions for each target.

| Architecture | Build Target Triplet | Deb Architecture Field | Typical TNAS Models |
|---|---|---|---|
| ARM 64-bit (aarch64) | `aarch64-linux-gnu` | `arm64` | ARM-based TNAS models |
| x86 64-bit (x86_64) | `x86_64-pc-linux-gnu` | `amd64` | x86-based TNAS models |

## 6.3 Configuring Ubuntu 22.04 APT Sources

TOS 7's Ubuntu 22.04-compatible root filesystem uses Ubuntu `ports.ubuntu.com` (ARM architecture-specific mirror). The development environment must be configured with the same software sources to ensure package version alignment.

**TOS 7 Current APT Source Configuration** (`/etc/apt/sources.list`):

```
deb http://ports.ubuntu.com/ubuntu-ports/ jammy main restricted
deb http://ports.ubuntu.com/ubuntu-ports/ jammy-updates main restricted
deb http://ports.ubuntu.com/ubuntu-ports/ jammy universe
deb http://ports.ubuntu.com/ubuntu-ports/ jammy-updates universe
deb http://ports.ubuntu.com/ubuntu-ports/ jammy multiverse
deb http://ports.ubuntu.com/ubuntu-ports/ jammy-updates multiverse
deb http://ports.ubuntu.com/ubuntu-ports/ jammy-backports main restricted universe multiverse
deb http://ports.ubuntu.com/ubuntu-ports/ jammy-security main restricted
deb http://ports.ubuntu.com/ubuntu-ports/ jammy-security universe
deb http://ports.ubuntu.com/ubuntu-ports/ jammy-security multiverse
```

> **For x86 Development Machines:** Replace `ports.ubuntu.com/ubuntu-ports` with `archive.ubuntu.com/ubuntu`, but keep the **jammy** distribution codename unchanged to ensure package version alignment.

## 6.4 Basic Build Toolchain

Developers should install the following tools in their Ubuntu 22.04 development environment to ensure build artifacts are binary-compatible with TOS 7:

| Tool | Ubuntu 22.04 Source | Purpose |
|------|---------------------|---------|
| `build-essential` | jammy/main | Includes gcc-11/g++-11, make, and other fundamental compilation tools |
| `make` | jammy/main | GNU Make build automation |
| `cmake` | jammy/main | Cross-platform build system |
| `git` | jammy/main | Version control |
| `pkg-config` | jammy/main | Library dependency query tool |

```bash
# Install on development machine
apt install -y build-essential make cmake git pkg-config
```

## 6.5 Cross-Compilation Environment

When the developer's local machine architecture differs from the target TNAS architecture, cross-compilation toolchains must be configured.

**Architecture Matching Guide:**

| Dev Machine Architecture | Target TNAS Architecture | Cross-Compilation Method |
|---|---|---|
| x86_64 (amd64) | aarch64 (arm64) | Install `crossbuild-essential-arm64` |
| x86_64 (amd64) | x86_64 (amd64) | Native compilation, no cross-compilation needed |
| aarch64 (arm64) | x86_64 (amd64) | Install `crossbuild-essential-amd64` |
| aarch64 (arm64) | aarch64 (arm64) | Native compilation, no cross-compilation needed |

```bash
# Example: Set up arm64 cross-compilation on x86_64 host
dpkg --add-architecture arm64
apt update
apt install -y crossbuild-essential-arm64
```

## 6.6 Language Runtime Guide

TOS 7 provides specific pre-installed runtimes. Developers must understand which runtimes are available natively on the system and plan their dependency strategy accordingly.

### 6.6.1 Python (Pre-installed)

TOS 7 comes with **Python 3.10.12** pre-installed, along with the following system modules:

| Module | Purpose |
|--------|---------|
| `python3-certifi` | SSL certificate verification |
| `python3-cffi-backend` | C extension interface |
| `python3-cryptography` | Cryptographic algorithm library |
| `python3-dbus` | D-Bus inter-process communication |
| `python3-dnspython` | DNS toolkit |
| `python3-gi` | GObject introspection bindings |
| `python3-gpg` | GnuPG encryption interface |
| `python3-ldb` | LDAP database bindings |
| `python3-markdown` | Markdown to HTML conversion |
| `python3-django-pyscss` | Django SCSS support |

**Development Guidelines:**
- Deb applications can directly depend on Python 3.10 by declaring `Depends: python3` in `DEBIAN/control`
- For additional third-party libraries not listed above, bundle them with the Deb package or install to a private directory using `pip install --target`
- See [Chapter 2 · Architecture Strategy](02_Architecture_Strategy.md) for general guidance on handling non-pre-installed dependencies

### 6.6.2 Java (Not Pre-installed)

TOS 7 **does not pre-install a Java runtime**. Developers deploying Java applications have two options:

**Option 1: Depend on the TOS App Center Java Runtime**

The TOS App Center provides a standalone Java runtime application. Third-party applications can declare a dependency on this runtime in their package manifest. When users install the application, the system automatically checks for and prompts installation of the Java runtime first.

Refer to [Chapter 4 · Package Specification](04_Package_Specification.md) for the specific dependency declaration fields.

**Option 2: Bundle Java Runtime with the Application**

Developers can distribute an OpenJDK build alongside their application package. The application starts directly using the bundled `java` binary, requiring no additional user installations.

### 6.6.3 Go (Not Pre-installed — Cross-Compile and Deploy)

Go natively supports cross-compilation. Developers compile target-platform binaries on their own machines and deploy to TNAS:

```bash
# Compile static binary for arm64
GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build -o appname-arm64 main.go

# Compile static binary for amd64
GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o appname-amd64 main.go
```

**Recommendations:**
- Use `CGO_ENABLED=0` to produce statically-linked binaries with no system library dependencies
- Go is the **recommended language** for applications whose core logic cannot be implemented in Python or requires high performance

### 6.6.4 C / C++ (Standard Development)

C/C++ applications follow standard development practices — developers compile target-architecture binaries on their own machines and deploy to TNAS.

**Key Considerations:**
- Link against glibc 2.35 (the version provided by the Ubuntu 22.04-compatible root filesystem) for binary compatibility
- Use the cross-compilation toolchain when the development machine architecture differs from the target
- See [Section 6.5 · Cross-Compilation Environment](#65-cross-compilation-environment) for architecture matching guidance

### 6.6.5 PHP (Not Pre-installed)

TOS 7 **does not pre-install PHP**. Developers deploying PHP applications have two options:

**Option 1: Depend on the TOS App Center PHP Runtime**

The TOS App Center provides a PHP 8.0 runtime application. Declare a dependency on this runtime in your package manifest. When users install the application, the system automatically checks for and prompts installation of the PHP runtime first.

Refer to [Chapter 4 · Package Specification](04_Package_Specification.md) for the specific dependency declaration fields.

**Option 2: Bundle PHP Runtime with the Application**

Distribute the PHP binary alongside your application package. The application starts directly using the bundled PHP interpreter, requiring no additional user installations.

> **Note:** PHP is an interpreted language. Source code is deployed directly and works across both arm64 and amd64 architectures without cross-compilation.

## 6.7 Packaging & Validation Tools

**Deb Application Tools:**

| Tool | Purpose |
|------|---------|
| `dpkg-dev` | Debian package build tools (`dpkg-deb`, `dpkg-source`) |
| `debhelper` | Debian packaging helper scripts |
| `lintian` | Debian package compliance checker |
| `systemd` | Service management and unit file testing |

```bash
apt install -y dpkg-dev debhelper lintian
```

**Docker Application Tools:**

| Tool | Minimum Version | Purpose |
|------|----------------|---------|
| Docker Engine | 20.10+ | Container runtime |
| Docker Compose | v2+ | Container orchestration |
| `trivy` / `docker scout` | Latest | Vulnerability scanning |

**Build Validation Commands:**

```bash
# Deb package: Check compliance
lintian <appid>_x86_64.deb

# Deb package: Verify package metadata
dpkg-deb --info <appid>_x86_64.deb

# Docker: Scan image for known vulnerabilities
trivy image <image>:<tag>
```

## 6.8 Testing Environment Options

A TNAS device running **TOS 7.0 (current stable/testing version)** is required for final verification. Subsequent TOS 7.x minor versions are expected to remain compatible, but regression testing on the target version is recommended before formal submission.

**Testing Options for Developers Without TNAS Hardware:**

| # | Option | Description | Recommended For |
|---|--------|-------------|-----------------|
| 1 | **Ubuntu 22.04 Virtual Machine** | Basic functional testing of Deb applications on an Ubuntu 22.04 VM | Early-stage development and CI/CD |
| 2 | **Docker Desktop** (Windows/macOS/Linux) | Simulate the TOS 7.0 Docker environment for container app testing | Docker application development |
| 3 | **Remote Experience Machine** | Apply for an official TerraMaster TOS 7.0 remote experience machine via the official forum. Full testing without owning hardware | Developers who lack both hardware and local VM capacity |

> **Recommendation:** Use options 1–2 for daily development and CI/CD. Use option 3 (Remote Machine) for comprehensive pre-submission verification.

> For detailed testing procedures, see [Chapter 13 · Local Testing & Debugging](13_Local_Testing.md).

## 6.9 Supplementary: Linux Kernel Module Development

For developers building out-of-tree Linux kernel modules (e.g., custom network drivers) for TOS 7, the system provides kernel headers via `linux-headers-<version>.deb`, consistent with standard Ubuntu distribution behavior.

**Quick Reference:**

```bash
# Install build tools
apt install -y build-essential

# Extract driver source
tar -xzf driver-source.tar.gz
cd driver-source

# Build the kernel module
make

# Install and load
make install
depmod -a
modprobe <module_name>

# Verify
lsmod | grep <module_name>
dmesg | tail -10
```

> **Note:** Kernel module development requires the build environment kernel version to match the TOS 7 kernel version. Contact TerraMaster developer support for the specific kernel header package corresponding to your target TOS version.

---

← [Previous: ABI Compatibility](05_ABI_Compatibility.md) &nbsp;&nbsp;|&nbsp;&nbsp; [Next: Application Types](07_Application_Types.md) → &nbsp;&nbsp;|&nbsp;&nbsp; [📖 Back to Contents](../README.md)
