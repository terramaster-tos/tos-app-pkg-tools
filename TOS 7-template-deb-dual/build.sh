#!/bin/bash
# ============================================================
# Build Script — Deb Dual-Package Mode
# ============================================================
# Usage:
#   ./build.sh              # Build for current architecture
#   ./build.sh x86_64       # Build for x86_64
#   ./build.sh aarch64      # Build for aarch64
#
# Output: <appid>_<platform>.tar.gz — archive containing two .deb packages:
#           <appid>.deb                 data package   (platform config only)
#           <package>_<ver>_<arch>.deb  source package (binary + systemd unit)
# ============================================================
set -e

# ---- Read metadata from config.ini ----
if ! command -v python3 &>/dev/null; then
    echo "ERROR: python3 is required to parse config.ini"
    exit 1
fi

APPID=$(python3 -c "import json; print(json.load(open('data-pkg/config.ini'))['id'])")
VERSION=$(python3 -c "import json; print(json.load(open('data-pkg/config.ini'))['version'])")
SYSTEM_ID=$(python3 -c "import json; print(json.load(open('data-pkg/config.ini'))['system_id'])")
# Source package name: taken from its own control file (it is the upstream
# package name and does not have to be "<appid>-source").
SOURCE_PKG=$(sed -n 's/^Package:[[:space:]]*//p' source-pkg/DEBIAN/control | head -n1)

if [ -z "${SOURCE_PKG}" ]; then
    echo "ERROR: cannot read Package: from source-pkg/DEBIAN/control"
    exit 1
fi

# The systemd unit must be shipped by the SOURCE package (§8.17).
if [ ! -f "source-pkg/init.d/${SYSTEM_ID}.service" ]; then
    echo "ERROR: source-pkg/init.d/${SYSTEM_ID}.service not found."
    echo "  The systemd unit belongs to the source package, not the data package."
    exit 1
fi

PLATFORM="${1:-x86_64}"
BUILD_DIR="build/${PLATFORM}"
OUTPUT_DIR="build/output"

echo "=== Building ${APPID} dual-package v${VERSION} for ${PLATFORM} ==="

# Clean previous build
rm -rf "${BUILD_DIR}" "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}"

# Map platform to dpkg architecture
case "${PLATFORM}" in
    x86_64)   DPKG_ARCH="amd64" ;;
    aarch64)  DPKG_ARCH="arm64" ;;
    *)        echo "ERROR: Unknown platform ${PLATFORM}"; exit 1 ;;
esac

# ---- Step 1: Build data package ----
echo "  [1/3] Building data package..."

DATA_STAGING="${BUILD_DIR}/data-staging"
mkdir -p "${DATA_STAGING}/usr/local/${APPID}" "${DATA_STAGING}/DEBIAN"

# Copy data package files (NO binaries, NO systemd unit!)
cp data-pkg/config.ini       "${DATA_STAGING}/usr/local/${APPID}/"
cp data-pkg/"${APPID}".lang  "${DATA_STAGING}/usr/local/${APPID}/"
cp -r data-pkg/images/       "${DATA_STAGING}/usr/local/${APPID}/" 2>/dev/null || echo "  (no images)"
# §8.17: the systemd unit must NOT be shipped by the data package.
# It is installed by the source package (see Step 2 below).

# Generate DEBIAN/control with correct version
cp data-pkg/DEBIAN/control   "${DATA_STAGING}/DEBIAN/"
# Update version in control file
sed -i "s/^Version:.*$/Version: ${VERSION}/" "${DATA_STAGING}/DEBIAN/control"
# Depends must point at the real source package name
sed -i "s|^Depends:.*|Depends: ${SOURCE_PKG} (>= ${VERSION})|" "${DATA_STAGING}/DEBIAN/control"

# Copy lifecycle scripts
cp data-pkg/DEBIAN/postinst  "${DATA_STAGING}/DEBIAN/" 2>/dev/null || true
cp data-pkg/DEBIAN/prerm     "${DATA_STAGING}/DEBIAN/" 2>/dev/null || true
chmod 755 "${DATA_STAGING}/DEBIAN/"post* 2>/dev/null || true
chmod 755 "${DATA_STAGING}/DEBIAN/"pre* 2>/dev/null || true

# Output name follows the recommended form of §4.2.4 / §8.17: <appid>.deb
dpkg-deb --build --root-owner-group "${DATA_STAGING}" "${BUILD_DIR}/${APPID}.deb"
echo "  ✓ Data package built (${APPID}.deb)."

# ---- Step 2: Build source package ----
echo "  [2/3] Building source package..."

SOURCE_STAGING="${BUILD_DIR}/source-staging"
mkdir -p "${SOURCE_STAGING}/DEBIAN" "${SOURCE_STAGING}/usr/local/${APPID}/bin"

# Copy/place source package binary
# In a real scenario, this is your upstream application binary
# For this template, we use a placeholder
cat > "${SOURCE_STAGING}/usr/local/${APPID}/bin/${APPID}" << 'BINARYEOF'
#!/bin/sh
echo "[myapp] Service running (source package)"
while true; do sleep 3600; done
BINARYEOF
chmod +x "${SOURCE_STAGING}/usr/local/${APPID}/bin/${APPID}"

# Install the systemd unit — it belongs to the SOURCE package (§8.17),
# never to the data package.
mkdir -p "${SOURCE_STAGING}/usr/local/${APPID}/init.d"
cp source-pkg/init.d/"${SYSTEM_ID}".service "${SOURCE_STAGING}/usr/local/${APPID}/init.d/"

# Generate DEBIAN/control with correct version and architecture
cp source-pkg/DEBIAN/control "${SOURCE_STAGING}/DEBIAN/"
sed -i "s/^Version:.*$/Version: ${VERSION}/" "${SOURCE_STAGING}/DEBIAN/control"
sed -i "s/^Architecture:.*$/Architecture: ${DPKG_ARCH}/" "${SOURCE_STAGING}/DEBIAN/control"

# postinst — enable + start the service on the fresh-install AND on the upgrade
# path ($2 = previous version, used for data migration). An upgrade must never
# leave the service stopped/disabled.
# NOTE: The application user is automatically created by the platform. 
# DO NOT run useradd here.
cat > "${SOURCE_STAGING}/DEBIAN/postinst" << POSTINSTEOF
#!/bin/bash
set -e
APPID="${APPID}"

# Create runtime dirs; must exist for ReadWritePaths in the .service file
mkdir -p "/usr/local/\${APPID}/data" "/usr/local/\${APPID}/logs" "/var/api" 2>/dev/null || true

chown -R "\${APPID}:\${APPID}" "/usr/local/\${APPID}"

# \$1 = "configure" (also on upgrade), \$2 = version installed before
case "\$1" in
    configure)
        if [ -n "\$2" ]; then
            echo "\${APPID}: upgrading from version \$2 ..."
        fi
        systemctl daemon-reload 2>/dev/null || true
        systemctl enable "\${APPID}.service" 2>/dev/null || true
        systemctl start "\${APPID}.service" 2>/dev/null || true
        ;;
    *)
        ;;
esac
exit 0
POSTINSTEOF
chmod 755 "${SOURCE_STAGING}/DEBIAN/postinst"

# prerm — stop/disable the service on REMOVE only, never on upgrade
cat > "${SOURCE_STAGING}/DEBIAN/prerm" << PRERMEOF
#!/bin/bash
set -e
APPID="${APPID}"

# \$1 = "remove" | "upgrade" | "deconfigure" | "failed-upgrade"
case "\$1" in
    remove|deconfigure)
        pkill -u "\${APPID}" 2>/dev/null || true
        sleep 1
        systemctl stop "\${APPID}.service" 2>/dev/null || true
        systemctl disable "\${APPID}.service" 2>/dev/null || true
        ;;
    upgrade|failed-upgrade)
        # Keep the service running across an upgrade.
        ;;
    *)
        ;;
esac
exit 0
PRERMEOF
chmod 755 "${SOURCE_STAGING}/DEBIAN/prerm"

# Output name: <package>_<version>_<arch>.deb — <package> is the source
# package name read from source-pkg/DEBIAN/control.
dpkg-deb --build --root-owner-group "${SOURCE_STAGING}" "${BUILD_DIR}/${SOURCE_PKG}_${VERSION}_${DPKG_ARCH}.deb"
echo "  ✓ Source package built (${SOURCE_PKG}_${VERSION}_${DPKG_ARCH}.deb)."

# ---- Step 3: Package into tar.gz ----
echo "  [3/3] Creating tar.gz archive..."

ARCHIVE_NAME="${APPID}_${PLATFORM}.tar.gz"
cd "${BUILD_DIR}"
tar -czf "${ARCHIVE_NAME}" \
    "${APPID}.deb" \
    "${SOURCE_PKG}_${VERSION}_${DPKG_ARCH}.deb"
mv "${ARCHIVE_NAME}" "../output/"
cd - > /dev/null

echo ""
echo "=== Build complete ==="
echo "  Output: ${OUTPUT_DIR}/${ARCHIVE_NAME}"
ls -lh "${OUTPUT_DIR}/"

echo ""
echo "  Contents:"
echo "    - ${APPID}.deb   (data package — platform config)"
echo "    - ${SOURCE_PKG}_${VERSION}_${DPKG_ARCH}.deb  (source package — application binary)"
echo ""
echo "  Submit this archive to the TNAS Developer Platform."
