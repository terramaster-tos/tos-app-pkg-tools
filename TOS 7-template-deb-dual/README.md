# Deb Dual-Package Template — TOS 7

A template for TOS 7 applications using the dual-package (archive) mode. Suitable when you already have a standard deb package and want to add TOS platform integration.

## Quick Start

```bash
# 1. Place your existing application's deb source package files in source-pkg/
# 2. Configure data-pkg/ files with TOS platform metadata
# 3. Replace "myapp" with your application ID everywhere
# 4. Build:
./build.sh x86_64
# Output: build/output/myapp_x86_64.tar.gz
```

## How It Works

Dual-package mode uses two deb packages in one tar.gz archive:

| Package | Purpose | Contains |
|---|---|---|
| **Data Package** (`myapp.deb`) | TOS platform integration | config.ini, icons, language file — **NO binaries, NO systemd unit** |
| **Source Package** (`myapp-source_<version>_<arch>.deb`) | Actual application | Application binary, systemd unit (`init.d/`), dependencies |

> Archive member names are free-form (the platform does not validate file
> names): use `<appid>.deb` for the data package and the source package's own
> `Package:` name for the source package, and keep them stable across releases.

## Directory Structure

```
myapp-dual/
├── build.sh                    # Build script
├── data-pkg/                   # TOS platform data package
│   ├── config.ini              # Platform metadata
│   ├── myapp.lang              # Multilingual file (26 languages)
│   ├── images/
│   │   └── icons/
│   │       └── myapp.svg       # App icon (SVG)
│   └── DEBIAN/
│       ├── control             # Declares Depends on the source package
│       ├── postinst            # chmod only — no service handling
│       └── prerm               # Stops the service on removal
└── source-pkg/                 # Upstream application package
    ├── init.d/
    │   └── myapp.service       # Systemd unit — SOURCE package (§8.17)
    └── DEBIAN/
        └── control             # Upstream package metadata
```

## Key Rules

- **Version Consistency:** keep the data and source package versions equal
  inside one archive (the platform does not validate versions, but mismatched
  versions make upgrades unpredictable)
- **No Binaries in Data Package:** the data package must not contain executables
- **No Systemd Unit in Data Package:** the unit belongs to the source package,
  installed under `/usr/local/<appid>/init.d/` (§8.17)
- **Source Package Independence:** source package must be installable via `dpkg -i`
- **Data Package Depends:** the data package control file declares
  `Depends: <package> (= <version>)`
- **Service Lifecycle:** the source package's postinst enables + starts the
  service; lifecycle scripts only stop/disable on removal (`case "$1"`), never
  on the upgrade path

## Requirements

- Your existing deb application package
- TOS 7.0 or later

## Resources

- [TOS 7 Application Development Guide — Chapter 8 (Deb Development)](../TOS%207%20Application%20Development%20Guide/08_Deb_Development.md)
- [TNAS Developer Platform](https://developer.terra-master.com)
