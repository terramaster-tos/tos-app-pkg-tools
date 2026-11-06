# Docker Application Template — TOS 7

> **⚠️ DEVELOPMENT GUIDE ONLY — DO NOT PACKAGE THIS FILE.**
> Per Chapter 9.2 of the TOS 7 Application Development Guide, the submitted
> `.tar.gz` archive MUST contain **exactly** the following 4 files and nothing else:
>
> ```
> <appid>.tar.gz
> ├── config.ini          # Application metadata (JSON)
> ├── <appid>.lang        # Multilingual file (26 languages)
> ├── <appid>.svg         # Application icon (SVG)
> └── docker-compose.yml  # Container orchestration config
> ```
>
> **Delete `README.md` (this file) before creating the archive.**

This template is generated from **Chapter 9 — Docker Development** of the
[TOS 7 Application Development Guide — Chapter 9](../TOS%207%20Application%20Development%20Guide/09_Docker_Development.md).
The "Docker App Template" entry in Chapter 3 (Quick Start) points developers to
this template for rapid application development.

## Quick Start

```bash
# 1. Copy this directory and rename it to your application id (e.g. my-awesome-app)
# 2. Globally replace "myapp-docker" with your application id
#    (config.ini id, docker-compose.yml service/container_name, file names,
#     volume paths /Volume1/DockerAppData/<appid>/)
# 3. Replace the image in docker-compose.yml with your Docker Hub image
#    (fixed version tag required — NEVER ":latest")
# 4. Update config.ini metadata (publisher, version, category, platform, ...)
# 5. Update <appid>.lang descriptions (all 26 languages; TOS 7.0 needs first 14)
# 6. Replace myapp-docker.svg with your own icon (keep the <appid>.svg name)
# 7. Test locally:
#    docker compose up -d
#    curl http://localhost:<port>/health
# 8. Delete README.md, then package:
#    tar -czf <appid>.tar.gz config.ini <appid>.lang <appid>.svg docker-compose.yml
# 9. Submit <appid>.tar.gz to the TNAS Developer Platform
#    (one submission per platform: x86_64 or aarch64)
```

## Directory Structure

```
<appid>/
├── config.ini              # Application metadata (JSON) — Docker fields included
├── <appid>.lang            # Multilingual file (26 languages)
├── <appid>.svg             # App icon (SVG; ViewBox recommended 0 0 512 512)
├── docker-compose.yml      # Compose Spec 3.8+, all Chapter 9 rules applied
└── README.md               # ← DELETE before packaging
```

## Compliance Checklist (Chapter 9)

| Rule | Requirement |
|---|---|
| **Package** | `.tar.gz` with exactly 4 files: config.ini, `<appid>.lang`, `<appid>.svg`, docker-compose.yml |
| **Image source** | Docker Hub ONLY — ① official project images (nginx, postgres) ② verified publishers ③ well-known community images (linuxserver/*). Rejected: ghcr.io / quay.io / private registries / unverified personal images |
| **Image tag** | Lock to a specific version. `:latest` is prohibited |
| **No root** | Non-root user via `user:` field. `privileged: true` strictly prohibited |
| **No host network** | `network_mode: host` strictly prohibited (except approved system network tools); use port mapping |
| **Version** | Compose Spec 3.8+ |
| **Container name** | Must match the application `id` |
| **Restart policy** | `unless-stopped` for normal services |
| **Data persistence** | All data dirs mounted to absolute host paths `/Volume1/DockerAppData/<appid>/...` — never use the `/Volume*/` wildcard. Bind mounts are preferred; a **named volume** (`<name>:/path`) must additionally be declared under the top-level `volumes:` key, otherwise Compose rejects the whole project (`service "x" refers to undefined volume "y"`) |
| **Ports** | Host port NOT in disabled list: 22, 80, 443, 8181, 5050. Recommended range: 8000-19999; verify free on TNAS before submission |
| **Timezone** | Explicitly configured: `TZ=Asia/Shanghai` + user override `TZ=${TZ:-Asia/Shanghai}` |
| **Health check** | Required for EVERY service; multi-container uses `depends_on: condition: service_healthy` |
| **x-app-meta** | Required for Web UI apps (appended at end of compose); NOT needed for headless apps |
| **Secrets** | No hardcoded passwords/tokens in image or compose — use env vars / .env |
| **Security scan** | Run `docker scan` or `trivy` before submission |
| **Line endings** | All files must use LF (not CRLF) |

## config.ini — Docker-specific Fields

| Field | Description | Example |
|---|---|---|
| `application_type` | Fixed to `"docker"` | `"docker"` |
| `compose_project` | Compose project name = app id | `"myapp-docker"` |
| `user` | Platform-side system user name (always required). This is **not** the container runtime user — that is the `user` field in `docker-compose.yml` (UID:GID); see guide §10.3.1 | `"myapp"` |
| `depend` | Must include `"DockerEngine"` | `["DockerEngine"]` |
| `relation` | Related apps | `["docker", "DockerEngine"]` |
| `path` | WebUI access path | `"http://${ip}:8080"` |
| `icon` | `/images/icons/<appid>.svg` (platform maps it to the package-root SVG) | `/images/icons/myapp-docker.svg` |

> **Prerequisite note:** Docker Engine is NOT pre-installed in TOS 7 — it is an
> App Center application. The platform automatically checks and prompts for
> installation when a Docker-based app is installed; no developer action needed.

## Multi-Architecture

Set the correct `platform` field in config.ini (`x86_64` or `aarch64`) for each
submission. Docker images may support both architectures via manifest, but TOS
requires separate submissions per platform.

## Resources

- [Chapter 9 — Docker Development](../TOS%207%20Application%20Development%20Guide/09_Docker_Development.md)
- [Chapter 3 — Quick Start](../TOS%207%20Application%20Development%20Guide/03_Quick_Start.md)
- [TNAS Developer Platform](https://developer.terra-master.com)
