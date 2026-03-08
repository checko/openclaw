#!/bin/bash
# OpenClaw Uninstall and Cleanup Script

INSTALL_DIR="${HOME}/openclaw-prod"
BIN_DIR="${HOME}/.local/bin"
CONFIG_DIR="${HOME}/.openclaw"
SERVICE_NAME="openclaw-gateway.service"

echo "🧹 Starting OpenClaw Cleanup..."

# 1. Stop and disable systemd service
echo "🛑 Stopping and disabling systemd service..."
systemctl --user stop ${SERVICE_NAME} 2>/dev/null || true
systemctl --user disable ${SERVICE_NAME} 2>/dev/null || true

# 2. Remove systemd unit file
echo "🗑️ Removing systemd unit file..."
rm -f "${HOME}/.config/systemd/user/${SERVICE_NAME}"
systemctl --user daemon-reload

# 3. Kill any remaining processes
echo "🛑 Killing any remaining OpenClaw processes..."
STRAY_PID=$(lsof -t -i:18789 2>/dev/null || true)
if [ -n "$STRAY_PID" ]; then
    kill -9 $STRAY_PID 2>/dev/null || true
fi
pkill -u "$USER" -f "openclaw" 2>/dev/null || true

# 4. Remove binaries and scripts
echo "🗑️ Removing CLI wrapper..."
rm -f "${BIN_DIR}/openclaw"

# 5. Remove installation and configuration directories
echo "🗑️ Removing installation directory: ${INSTALL_DIR}"
rm -rf "${INSTALL_DIR}"

echo "🗑️ Removing configuration directory: ${CONFIG_DIR}"
rm -rf "${CONFIG_DIR}"

# 6. Cleanup logs
echo "🗑️ Removing temporary logs..."
rm -rf "/tmp/openclaw"

echo "✅ OpenClaw has been completely uninstalled and cleaned up."
echo "🚀 You can now run your install.sh for a fresh test."
