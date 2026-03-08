#!/bin/bash
set -e

# Configuration
VERSION=$(node -e "console.log(require('./package.json').version)")
RELEASE_NAME="openclaw-release-${VERSION}"
BUNDLE_DIR="release-bundle"

echo "📦 Preparing release for OpenClaw ${VERSION}..."

# 1. Clean and build everything
echo "🏗️ Building project and UI..."
pnpm build
pnpm ui:build

# 2. Create the bundle directory
rm -rf ${BUNDLE_DIR}
mkdir -p ${BUNDLE_DIR}

# 3. Create the production tarball (npm/pnpm pack)
echo "📦 Packing production artifacts..."
PNPM_PACK_FILE=$(pnpm pack --pack-destination ${BUNDLE_DIR} | tail -n 1)

# 4. Copy the scripts into the bundle
cp scripts/install-release.sh ${BUNDLE_DIR}/install.sh
cp scripts/uninstall-release.sh ${BUNDLE_DIR}/uninstall.sh
chmod +x ${BUNDLE_DIR}/install.sh ${BUNDLE_DIR}/uninstall.sh

# 5. Create a final zip/tar of the bundle
cd ${BUNDLE_DIR}
tar -czf ../${RELEASE_NAME}.tar.gz .
cd ..

echo "✅ Release bundle created: ${RELEASE_NAME}.tar.gz"
echo "🚀 To install on another machine, copy this file, extract it, and run ./install.sh"
