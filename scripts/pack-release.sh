#!/bin/bash
set -e

# Check prerequisites
if [ ! -d "node_modules" ]; then
    echo "[ERROR] node_modules not found. Run 'pnpm install' first."
    exit 1
fi

# Configuration
VERSION=$(node -e "console.log(require('./package.json').version)")
RELEASE_NAME="openclaw-release-${VERSION}"
BUNDLE_DIR="release-bundle"

echo "[INFO] Preparing release for OpenClaw ${VERSION}..."

# 1. Clean and build everything
echo "[INFO] Building project and UI..."
pnpm build
pnpm ui:build

# 2. Create the bundle directory
rm -rf ${BUNDLE_DIR}
mkdir -p ${BUNDLE_DIR}

# 3. Create the production tarball (npm/pnpm pack)
echo "[INFO] Packing production artifacts..."
PNPM_PACK_FILE=$(pnpm pack --pack-destination ${BUNDLE_DIR} | tail -n 1)

# 4. Copy the scripts and deployment environment template into the bundle
echo "[INFO] Copying installation scripts..."
cp scripts/install-release.sh ${BUNDLE_DIR}/install.sh
cp scripts/uninstall-release.sh ${BUNDLE_DIR}/uninstall.sh
cp deploy.env.example ${BUNDLE_DIR}/deploy.env.example
chmod +x ${BUNDLE_DIR}/install.sh ${BUNDLE_DIR}/uninstall.sh

# 5. Create a final tar of the bundle
echo "[INFO] Creating final release archive..."
cd ${BUNDLE_DIR}
tar -czf ../${RELEASE_NAME}.tar.gz .
cd ..

echo "[SUCCESS] Release bundle created: ${RELEASE_NAME}.tar.gz"
echo "[INFO] To install on another machine:"
echo "      1. Copy this file and extract it"
echo "      2. cp deploy.env.example deploy.env  (and edit with your server settings)"
echo "      3. ./install.sh"
