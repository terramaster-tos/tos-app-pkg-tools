# 7. Application Types

| Type | Use Case | Package Format | Submission Format |
|---|---|---|---|
| Deb Application | Binary programs/scripts running directly on the host | Standard `.deb` package | Deb package (single-package mode) or tar.gz archive (dual-package mode) + configuration files |
| Docker Application | Services requiring isolated runtime environments | Docker image + docker-compose.yml | Compose file + configuration files |

Choose the appropriate type based on application characteristics:

- **Choose Deb** — If your application is a native binary, Python script (leveraging the system's pre-installed Python 3.10), or a lightweight system service. **Note: Node.js, Java, Go, and other language runtimes are not pre-installed on the system. Deb applications must not directly depend on them.**
- **Choose Docker** — If your application requires a specific runtime environment, has complex dependencies, or already has a containerized version

> **Hybrid Application Type:** When a native launcher manages Docker containers, the application package can include both Deb and Docker components. In this case, use `"application_type": "deb"` and declare `["DockerEngine"]` in `depend`. The Deb component acts as the launcher/manager for the Docker service.

**application_type Value Description:**

`application_type` supports only two values:

- `"deb"` — Deb application (including single-package mode and dual-package/archive mode)
- `"docker"` — Docker application

---

← [Previous: Development Environment](06_Development_Environment.md) &nbsp;&nbsp;|&nbsp;&nbsp; [Next: Deb Development](08_Deb_Development.md) → &nbsp;&nbsp;|&nbsp;&nbsp; [📖 Back to Contents](../README.md)
