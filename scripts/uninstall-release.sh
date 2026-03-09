#!/bin/bash
# OpenClaw Uninstall and Cleanup Script

# Load deployment configuration from deploy.env (preferred) or .env (fallback)
# This ensures INSTALL_DIR and BIN_DIR match what was used during installation.
if [ -f deploy.env ]; then
    set -a
    source deploy.env
    set +a
elif [ -f .env ]; then
    set -a
    source .env
    set +a
fi

INSTALL_DIR="${INSTALL_DIR:-${HOME}/openclaw-prod}"
BIN_DIR="${BIN_DIR:-${HOME}/.local/bin}"
CONFIG_DIR="${HOME}/.openclaw"
SERVICE_NAME="openclaw-gateway.service"

echo "[START] Starting OpenClaw Cleanup..."

# 1. Stop and disable systemd service
echo "[INFO] Stopping and disabling systemd service..."
systemctl --user stop ${SERVICE_NAME} 2>/dev/null || true
systemctl --user disable ${SERVICE_NAME} 2>/dev/null || true

# 2. Remove systemd unit file
echo "[INFO] Removing systemd unit file..."
rm -f "${HOME}/.config/systemd/user/${SERVICE_NAME}"
systemctl --user daemon-reload

# 3. Kill any remaining processes
echo "[INFO] Killing any remaining OpenClaw processes..."
STRAY_PID=$(lsof -t -i:18789 2>/dev/null || true)
if [ -n "$STRAY_PID" ]; then
    kill -9 $STRAY_PID 2>/dev/null || true
fi
pkill -u "$USER" -f "openclaw" 2>/dev/null || true

# 4. Remove binaries and scripts
echo "[INFO] Removing CLI wrapper..."
rm -f "${BIN_DIR}/openclaw"

# 5. Remove installation and configuration directories
echo "[INFO] Removing installation directory: ${INSTALL_DIR}"
rm -rf "${INSTALL_DIR}"

echo "[INFO] Removing configuration directory: ${CONFIG_DIR}"
rm -rf "${CONFIG_DIR}"

# 6. Cleanup logs
echo "[INFO] Removing temporary logs..."
rm -rf "/tmp/openclaw"

echo "[SUCCESS] OpenClaw has been completely uninstalled and cleaned up."
echo "[INFO] You can now run your install.sh for a fresh test."
