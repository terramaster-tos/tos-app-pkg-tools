# 2. Architecture Strategy

### 2.1 Official Architecture Recommendation

TOS 7 adopts a **Container-first** strategy while maintaining full support for native Deb applications. The platform recommends the following decision framework:

```
                    ┌──────────────────────────────────┐
                    │ Does your application require    │
                    │ an isolated runtime environment? │
                    └──────────────┬───────────────────┘
                                   │
                    ┌──────────────▼──────────────┐        
                    │  Yes                    No   │    
                    │                             │              
                    ▼                             ▼              
              ┌──────────┐           ┌─────────────────────────┐      
              │ Docker   │           │ Is it a TOS standard    │  
              │ App      │           │ service or lightweight  │      
              │          │           │ tool?                   │      
              └──────────┘           └──────────┬──────────────┘      
                                       ┌────────▼──────┐         
                                       │ Yes           │ No      
                                       ▼               ▼         
                                    Deb App        Deb App      
                                    (TOS std)      (Native)
```


### 2.2 Container-First Direction

The TOS 7 application ecosystem is evolving toward a **Container-first** model:

- **Docker applications** are the preferred path for most third-party services
- Provide better isolation, simpler dependency management, and cross-platform consistency
- TOS 7 supports Docker containerized deployment. Before use, the DockerEngine application must be installed from the App Center. This application provides a complete Docker Compose runtime environment for TOS 7.
- Future platform features (sandboxing, resource limits, automatic updates) will prioritize Docker application support

**Special Application Type Selection Rules:**

- **No UI Background Services:** Use the **Deb (No UI)** subtype for lightweight daemons (also referred to as headless services); use **Docker** for services with complex runtime dependencies or those requiring container isolation

**For Deb applications**, TOS 7 provides full support, but developers should:
- Minimize system-level dependencies
- Use systemd for lifecycle management
- Follow the principle of least privilege
- Prepare for future containerized deployment

**Recommended Docker Scenarios:** The following scenarios must use Docker; using Deb is prohibited:

- Applications requiring a specific OS environment or library versions that conflict with the host
- Applications requiring network isolation (independent namespaces)
- Multi-container architecture applications (e.g., Web service + database)

> **Deb Application Roadmap:** Deb applications maintain full support throughout TOS 7.x. The platform may gradually introduce a transition path to the container-first architecture in future TOS major versions. Developers will receive at least 12 months' advance notice before any format deprecation.

---


### 2.3 TOS System Pre-installed Dependencies

TOS 7 employs a root filesystem compatible with Ubuntu 22.04. The system comes pre-installed with the following core dependencies:

- bash / dash
- Python 3.10
- systemd
- nginx
- curl / wget
- Docker runtime (exclusive to Docker applications)

> **Important:** Language runtimes such as Node.js, Java, and Go are **not pre-installed by default in TOS**. Do not directly depend on these environments in Deb applications.

### 2.4 Handling Non-Pre-installed Dependencies

If your application depends on runtime environments that are not pre-installed in TOS (such as Node.js, Java, Go, or other language runtimes), you must adopt one of the following compliant solutions. **Directly declaring such dependencies or downloading them at runtime is prohibited.**

#### Prohibited Approaches

- Declaring `Depends: nodejs` in `DEBIAN/control` (the system does not have it pre-installed, causing installation failure)
- Installing dependencies via `apt install nodejs` in scripts (triggers permission issues and damages the system environment)
- Using Node.js scripts as the application entry point (results in `node: command not found`)

#### Recommended Alternatives (in Priority Order)

##### Option 1: Compile Static Binaries with Go (Recommended)

Rewrite core logic in Go and compile into statically-linked standalone binaries without depending on any system dynamic libraries:

```bash
# Compile static binary for x86_64 architecture
GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o appname-x86_64 main.go

# Compile static binary for aarch64 architecture
GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build -o appname-aarch64 main.go
```

- Place the compiled binary in the `/usr/local/<appid>/` directory of the Deb package
- Start directly via systemd service file without additional dependencies

##### Option 2: Use Python (Python 3.10 is pre-installed in TOS, ready to use)

Rewrite core logic in Python. TOS comes pre-installed with Python 3.10, which can be used directly:

- Declare dependency in `DEBIAN/control`: `Depends: python3`
- If third-party libraries are needed, bundle them with the Deb package or use `pip install --target` to install into the application's private directory

##### Option 3: Bundle Static Dependencies (Special Scenarios Only)

If you must use a non-pre-installed environment such as Node.js, you can bundle the corresponding architecture's static binary with the Deb package:

- Place the Node.js static binary in the `/usr/local/<appid>/node/` directory
- Use absolute paths in scripts: `/usr/local/<appid>/node/bin/node /usr/local/<appid>/app.js`
- Note: This approach significantly increases package size; recommended only for lightweight applications

---

← [Previous Chapter: Overview](01_Overview.md) &nbsp;&nbsp;|&nbsp;&nbsp; [Next Chapter: Quick Start](03_Quick_Start.md) → &nbsp;&nbsp;|&nbsp;&nbsp; [📖 Back to Table of Contents](../README.md)
