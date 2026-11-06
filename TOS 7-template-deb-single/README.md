# Deb Single-Package Template — TOS 7

A ready-to-use template for building TOS 7 Deb applications in single-package mode.

## Quick Start

```bash
# 1. Clone or copy this template
# 2. Replace "myapp" with your actual application ID everywhere
# 3. Add your application binary/script to bin/
# 4. Update config.ini with your app metadata
# 5. Update myapp.lang with your descriptions
# 6. Add webui.bz2 for WebUI applications (REQUIRED when config.ini sets
#    "type": "iframe" or "open_path": true; the template already ships a
#    placeholder webui.bz2 built from webui/)
#    Rebuild it after editing webui/ with: tar -cjf webui.bz2 -C webui/ .
# 7. Build:
./build.sh x86_64
# or for ARM:
./build.sh aarch64
```

## Directory Structure

```
myapp/
├── config.ini              # Application metadata (JSON format)
├── myapp.lang              # Multilingual file (26 languages; TOS 7.0 needs first 14)
├── myapp.env               # Environment variables (loaded by systemd via EnvironmentFile)
├── build.sh                # Build script (includes pre-build validation)
├── bin/
│   └── myapp               # Application executable
├── images/
│   └── icons/
│       └── myapp.svg       # App icon (SVG; ViewBox recommended 0 0 512 512)
├── init.d/
│   └── myapp.service       # Systemd service unit
├── nginx/                  # Nginx config (external open only — create if used)
├── webui/                  # Frontend sources (edit these)
│   └── index.html
├── webui.bz2               # Frontend archive — REQUIRED for WebUI apps
│                           # (placeholder shipped; rebuild with
│                           #  tar -cjf webui.bz2 -C webui/ .)
├── depends/                # Dependency files (optional — create if used)
│   ├── bin/
│   ├── lib/
│   ├── etc/
│   ├── data/
│   └── logs/
└── DEBIAN/
    ├── control             # Package metadata
    ├── postinst            # Post-install script
    ├── prerm               # Pre-remove script
    └── postrm              # Post-remove script
```

## Subtype Configuration

This template defaults to **WebUI Internal Open (iframe)**. To change:

| Subtype | config.ini Changes | webui.bz2 Required? |
|---|---|---|
| WebUI Internal (iframe) | `"type": "iframe"`, `"path": "/myapp/"` | ✅ Required |
| WebUI External (new tab) | Remove `"type"`, set `"open_path": true`, `"path": "http://${ip}:8686"` | ✅ Required |
| No UI Service | Remove `"type"`, `"open_path"`, `"path"` fields | ❌ Not required |

## Requirements

- TOS 7.0 or later
- Python 3.10 (pre-installed in TOS)
- Systemd

## Resources

- [TOS 7 Application Development Guide — Chapter 8 (Deb Development)](../TOS%207%20Application%20Development%20Guide/08_Deb_Development.md)
- [TNAS Developer Platform](https://developer.terra-master.com)
