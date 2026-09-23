#!/bin/bash
# ============================================================
# Build Script — Deb Single-Package Mode
# ============================================================
# Usage:
#   ./build.sh              # Build for current architecture
#   ./build.sh x86_64       # Build for x86_64
#   ./build.sh aarch64      # Build for aarch64
# ============================================================
set -e

# ---- Read metadata from config.ini ----
if ! command -v python3 &>/dev/null; then
    echo "ERROR: python3 is required to parse config.ini"
    exit 1
fi

APPID=$(python3 -c "import json; print(json.load(open('config.ini'))['id'])")
VERSION=$(python3 -c "import json; print(json.load(open('config.ini'))['version'])")

PLATFORM="${1:-x86_64}"
BUILD_DIR="build/${PLATFORM}"
STAGING="${BUILD_DIR}/staging"
OUTPUT_DIR="build/output"

echo "=== Building ${APPID} v${VERSION} for ${PLATFORM} ==="

# ---- Pre-build validation ----
# Check mutual exclusion of type and open_path
HAS_TYPE=$(python3 -c "import json; c=json.load(open('config.ini')); print('type' in c)")
HAS_OPEN_PATH=$(python3 -c "import json; c=json.load(open('config.ini')); print('open_path' in c)")
if [ "${HAS_TYPE}" = "True" ] && [ "${HAS_OPEN_PATH}" = "True" ]; then
    echo "ERROR: 'type' and 'open_path' are mutually exclusive. Cannot set both."
    echo "  WebUI Internal: set 'type' to 'iframe', do NOT set 'open_path'"
    echo "  WebUI External: set 'open_path' to true, do NOT set 'type'"
    echo "  No UI Service: remove both 'type' and 'open_path'"
    exit 1
fi
# Check that webui.bz2 exists for WebUI applications
HAS_TYPE=$(python3 -c "import json; c=json.load(open('config.ini')); print(c.get('type',''))")
HAS_OPEN_PATH=$(python3 -c "import json; c=json.load(open('config.ini')); print(c.get('open_path',False))")

if [ "${HAS_TYPE}" = "iframe" ] || [ "${HAS_OPEN_PATH}" = "True" ]; then
    if [ ! -f webui.bz2 ]; then
        echo "ERROR: webui.bz2 is required for WebUI applications but not found."
        echo "  Create it with: tar -cjf webui.bz2 -C webui/ ."
        exit 1
    fi
    echo "  ✓ webui.bz2 found"
fi

# Clean previous build
rm -rf "${BUILD_DIR}" "${OUTPUT_DIR}"
mkdir -p "${STAGING}/usr/local/${APPID}"
mkdir -p "${STAGING}/usr/local/${APPID}/bin"
mkdir -p "${STAGING}/DEBIAN"
mkdir -p "${OUTPUT_DIR}"

# ---- Copy application files ----
echo "  Copying application files..."

# Core config
cp config.ini          "${STAGING}/usr/local/${APPID}/"
cp "${APPID}.lang"     "${STAGING}/usr/local/${APPID}/"

# Binary (copy into /usr/local/<appid>/bin/)
if [ -d bin ]; then
    cp -r bin/*        "${STAGING}/usr/local/${APPID}/bin/"
    chmod +x           "${STAGING}/usr/local/${APPID}/bin/"*
fi

# Icons
cp -r images/          "${STAGING}/usr/local/${APPID}/"

# Systemd service
cp -r init.d/          "${STAGING}/usr/local/${APPID}/"

# Environment file (optional)
if [ -f "${APPID}.env" ]; then
    cp "${APPID}.env"  "${STAGING}/usr/local/${APPID}/"
fi

# Frontend archive (required for WebUI, optional for No UI)
if [ -f webui.bz2 ]; then
    cp webui.bz2        "${STAGING}/usr/local/${APPID}/"
fi

# Dependency files (optional)
if [ -d depends ]; then
    cp -r depends/      "${STAGING}/usr/local/${APPID}/"
fi

# Nginx config (required for external open)
if [ -d nginx ]; then
    cp -r nginx         "${STAGING}/usr/local/${APPID}/"
fi

# ---- DEBIAN metadata ----
echo "  Preparing DEBIAN metadata..."

# Map platform to dpkg architecture
case "${PLATFORM}" in
    x86_64)   DPKG_ARCH="amd64" ;;
    aarch64)  DPKG_ARCH="arm64" ;;
    *)        echo "ERROR: Unknown platform ${PLATFORM}"; exit 1 ;;
esac

cp DEBIAN/control       "${STAGING}/DEBIAN/"
sed -i "s/^Architecture:.*$/Architecture: ${DPKG_ARCH}/" "${STAGING}/DEBIAN/control"
cp DEBIAN/postinst      "${STAGING}/DEBIAN/"
cp DEBIAN/prerm         "${STAGING}/DEBIAN/"
cp DEBIAN/postrm        "${STAGING}/DEBIAN/"
chmod 755               "${STAGING}/DEBIAN/"post*
chmod 755               "${STAGING}/DEBIAN/"pre*

# ---- Build .deb ----
echo "  Building .deb package..."

# Release asset name, per the guide (ch. 08 section 8.15 / ch. 15):
#   <appid>_<platform>.deb      e.g. myapp_x86_64.deb
# The version is NOT part of the file name; the platform reads it from the
# config.ini inside the package.
dpkg-deb --build "${STAGING}" "${OUTPUT_DIR}/${APPID}_${PLATFORM}.deb"

echo ""
echo "=== Build complete ==="
echo "  Output: ${OUTPUT_DIR}/${APPID}_${PLATFORM}.deb"
ls -lh "${OUTPUT_DIR}/"
