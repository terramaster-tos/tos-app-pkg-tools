# 7. Application Types

| Type | Use Case | Package Format | Submission Format |
|---|---|---|---|
| Deb Application | Binary programs/scripts running directly on the host | Standard `.deb` package | Deb package (single-package mode) or tar.gz archive (dual-package mode) + configuration files |
| Docker Application | Services requiring isolated runtime environments | Docker image + docker-compose.yml | Compose file + configuration files |

Choose the appropriate type based on application characteristics:

- **Choose Deb** — If your application is a native binary, Python script (leveraging the system's pre-installed Python 3.10), or a lightweight system service. **Note: Node.js, Java, Go, and other language runtimes are not pre-installed on the system. Deb applications must not directly depend on them.**
- **Choose Docker** — If your application requires a specific runtime environment, has complex dependencies, or already has a containerized version

> **Dependency channel differs by type:** Deb applications declare dependencies in the `Depends` field of `DEBIAN/control` and never use the `config.ini` `depend` field; Docker applications declare them in the `config.ini` `depend` field, which is Docker-only and defined in [§9.2.1](09_Docker_Development.md#921-docker-specific-configini-fields).

> **Only two application types exist: Deb and Docker.** No other application type is supported. A Deb application runs its own binary programs/scripts directly on the host; an application whose functionality is delivered by Docker containers is declared as a Docker application and packaged according to Chapter 9. Do not describe a single application as being both types at once.

**application_type Value Description:**

`application_type` supports only two values — **no other value is accepted** (`deb-TarGz` is not a valid application type):

- `"deb"` — Deb application. The Deb type has two packaging modes:
  - **Single-package mode (TOS 7.0 single-package specification)** — all application files, configuration and metadata are integrated into one `.deb` package.
  - **Dual-package mode** — step 1 is a standard deb package (the application's original deb source package, kept unchanged); step 2 is a deb data package built to the generic deb standard plus the TOS specification, carrying the TOS-specific content such as `config.ini`, `lang` files and icons; the two packages are then bundled into a `tar.gz` archive for submission.
- `"docker"` — Docker application

---

← [Previous: Development Environment](06_Development_Environment.md) &nbsp;&nbsp;|&nbsp;&nbsp; [Next: Deb Development](08_Deb_Development.md) → &nbsp;&nbsp;|&nbsp;&nbsp; [📖 Back to Contents](../README.md)
