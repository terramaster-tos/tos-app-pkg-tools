#!/bin/bash
# ============================================================
# Build Script — Deb Dual-Package Mode
# ============================================================
# Usage:
#   ./build.sh              # Build for current architecture
#   ./build.sh x86_64       # Build for x86_64
#   ./build.sh aarch64      # Build for aarch64
#
# Output: <appid>_<platform>.tar.gz (archive containing two .deb packages)
# ============================================================
set -e

# ---- Read metadata from config.ini ----
if ! command -v python3 &>/dev/null; then
    echo "ERROR: python3 is required to parse config.ini"
    exit 1
fi

APPID=$(python3 -c "import json; print(json.load(open('data-pkg/config.ini'))['id'])")
VERSION=$(python3 -c "import json; print(json.load(open('data-pkg/config.ini'))['version'])")

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

# Copy data package files (NO binaries!)
cp data-pkg/config.ini       "${DATA_STAGING}/usr/local/${APPID}/"
cp data-pkg/"${APPID}".lang  "${DATA_STAGING}/usr/local/${APPID}/"
cp -r data-pkg/images/       "${DATA_STAGING}/usr/local/${APPID}/" 2>/dev/null || echo "  (no images)"
cp -r data-pkg/init.d/       "${DATA_STAGING}/usr/local/${APPID}/"

# Generate DEBIAN/control with correct version
cp data-pkg/DEBIAN/control   "${DATA_STAGING}/DEBIAN/"
# Update version in control file
sed -i "s/^Version:.*$/Version: ${VERSION}/" "${DATA_STAGING}/DEBIAN/control"
sed -i "s/myapp-source (= .*)/myapp-source (= ${VERSION})/" "${DATA_STAGING}/DEBIAN/control"

# Copy lifecycle scripts
cp data-pkg/DEBIAN/postinst  "${DATA_STAGING}/DEBIAN/" 2>/dev/null || true
cp data-pkg/DEBIAN/prerm     "${DATA_STAGING}/DEBIAN/" 2>/dev/null || true
chmod 755 "${DATA_STAGING}/DEBIAN/"post* 2>/dev/null || true
chmod 755 "${DATA_STAGING}/DEBIAN/"pre* 2>/dev/null || true

dpkg-deb --build "${DATA_STAGING}" "${BUILD_DIR}/${APPID}_${VERSION}_${DPKG_ARCH}.deb"
echo "  ✓ Data package built."

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

# Generate DEBIAN/control with correct version and architecture
cp source-pkg/DEBIAN/control "${SOURCE_STAGING}/DEBIAN/"
sed -i "s/^Version:.*$/Version: ${VERSION}/" "${SOURCE_STAGING}/DEBIAN/control"
sed -i "s/^Architecture:.*$/Architecture: ${DPKG_ARCH}/" "${SOURCE_STAGING}/DEBIAN/control"

# postinst — fix ownership.
# The application user is created by the platform; do not add useradd here
# (see 08_Deb_Development.md section 8.14 and 10_Permission_Model.md).
cat > "${SOURCE_STAGING}/DEBIAN/postinst" << POSTINSTEOF
#!/bin/sh
set -e
APPID="${APPID}"
chown -R "\${APPID}:\${APPID}" "/usr/local/\${APPID}"
POSTINSTEOF
chmod 755 "${SOURCE_STAGING}/DEBIAN/postinst"

# prerm — stop service
cat > "${SOURCE_STAGING}/DEBIAN/prerm" << PRERMEOF
#!/bin/sh
set -e
systemctl stop ${APPID}.service 2>/dev/null || true
systemctl disable ${APPID}.service 2>/dev/null || true
PRERMEOF
chmod 755 "${SOURCE_STAGING}/DEBIAN/prerm"

dpkg-deb --build "${SOURCE_STAGING}" "${BUILD_DIR}/${APPID}-source_${VERSION}_${DPKG_ARCH}.deb"
echo "  ✓ Source package built."

# ---- Step 3: Package into tar.gz ----
echo "  [3/3] Creating tar.gz archive..."

ARCHIVE_NAME="${APPID}_${PLATFORM}.tar.gz"
cd "${BUILD_DIR}"
tar -czf "${ARCHIVE_NAME}" \
    "${APPID}_${VERSION}_${DPKG_ARCH}.deb" \
    "${APPID}-source_${VERSION}_${DPKG_ARCH}.deb"
mv "${ARCHIVE_NAME}" "../output/"
cd - > /dev/null

echo ""
echo "=== Build complete ==="
echo "  Output: ${OUTPUT_DIR}/${ARCHIVE_NAME}"
ls -lh "${OUTPUT_DIR}/"

echo ""
echo "  Contents:"
echo "    - ${APPID}_${VERSION}_${DPKG_ARCH}.deb   (data package — platform config)"
echo "    - ${APPID}-source_${VERSION}_${DPKG_ARCH}.deb  (source package — application binary)"
echo ""
echo "  Submit this archive to the TNAS Developer Platform."
