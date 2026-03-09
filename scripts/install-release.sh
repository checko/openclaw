#!/bin/bash
set -e

# 1. Load deployment configuration from deploy.env (preferred) or .env (fallback)
if [ -f deploy.env ]; then
    echo "[INFO] Loading deployment configuration from deploy.env..."
    set -a
    source deploy.env
    set +a
elif [ -f .env ]; then
    echo "[INFO] Loading deployment configuration from .env..."
    set -a
    source .env
    set +a
else
    echo "[WARN] No deploy.env or .env file found. Using default values and environment variables."
    echo "[WARN] Copy deploy.env.example to deploy.env and edit it before running this script."
fi

# Defaults (overridden by deploy.env / .env if set)
INSTALL_DIR="${INSTALL_DIR:-${HOME}/openclaw-prod}"
BIN_DIR="${BIN_DIR:-${HOME}/.local/bin}"
OLLAMA_BASE_URL="${OLLAMA_BASE_URL:-http://192.168.1.100:11434}"
QWEN_MODEL_ID="${QWEN_MODEL_ID:-qwen3.5:122b}"
SEARXNG_BASE_URL="${SEARXNG_BASE_URL:-http://192.168.1.100:8081}"

echo "[START] Starting OpenClaw Production Installation..."

# 2. Check prerequisites
echo "[STEP 1/9] Checking for Node.js and pnpm..."
if ! command -v node &> /dev/null; then
    echo "[ERROR] Node.js not found. Please install Node.js >= 22."
    exit 1
fi

if ! command -v pnpm &> /dev/null; then
    echo "[INFO] Installing pnpm globally via npm..."
    npm install -g pnpm
fi

# 3. Cleanup existing installation if any
echo "[STEP 2/9] Cleaning up previous installation..."
systemctl --user stop openclaw-gateway.service 2>/dev/null || true
systemctl --user disable openclaw-gateway.service 2>/dev/null || true
rm -f "${HOME}/.config/systemd/user/openclaw-gateway.service"

STRAY_PID=$(lsof -t -i:18789 2>/dev/null || true)
if [ -n "$STRAY_PID" ]; then
    echo "[INFO] Stopping stray process $STRAY_PID on port 18789..."
    kill -9 $STRAY_PID 2>/dev/null || true
fi

# 4. Extract OpenClaw package
echo "[STEP 3/9] Extracting package to ${INSTALL_DIR}..."
mkdir -p ${INSTALL_DIR}
TAR_FILE=$(ls openclaw-*.tgz | head -n 1)
if [ -z "${TAR_FILE}" ]; then
    echo "[ERROR] No openclaw-*.tgz found in the current directory."
    exit 1
fi
tar -xzf "${TAR_FILE}" -C ${INSTALL_DIR} --strip-components=1

# 5. Install production dependencies
echo "[STEP 4/9] Installing production dependencies..."
cd ${INSTALL_DIR}
pnpm config set side-effects-cache-readonly false 2>/dev/null || true
pnpm install --production --no-frozen-lockfile --aggregate-output

# 6. Create local bin wrapper
echo "[STEP 5/9] Setting up 'openclaw' CLI wrapper..."
mkdir -p ${BIN_DIR}
cat > ${BIN_DIR}/openclaw <<EOF
#!/bin/bash
node ${INSTALL_DIR}/openclaw.mjs "\$@"
EOF
chmod +x ${BIN_DIR}/openclaw

PROD_OPENCLAW="node ${INSTALL_DIR}/openclaw.mjs"

# 7. Initialize configuration
echo "[STEP 6/9] Initializing and applying custom configuration..."
${PROD_OPENCLAW} onboard --non-interactive --accept-risk --skip-health --auth-choice skip --skip-channels --skip-search --skip-skills

echo "[INFO] Configuring Ollama provider..."
${PROD_OPENCLAW} config set models.providers.ollama "{ \"baseUrl\": \"${OLLAMA_BASE_URL}\", \"api\": \"ollama\", \"models\": [{ \"id\": \"${QWEN_MODEL_ID}\", \"name\": \"Qwen 3.5 122B\", \"api\": \"ollama\", \"input\": [\"text\", \"image\"], \"compat\": { \"supportsTools\": true } }] }"
${PROD_OPENCLAW} config set agents.defaults.model "ollama/${QWEN_MODEL_ID}"

echo "[INFO] Configuring SearXNG..."
${PROD_OPENCLAW} config set tools.web.search.enabled true
${PROD_OPENCLAW} config set tools.web.search.provider "searxng"
${PROD_OPENCLAW} config set tools.web.search.searxng.baseUrl "${SEARXNG_BASE_URL}"

echo "[INFO] Configuring tool permissions..."
${PROD_OPENCLAW} config set tools.profile null
${PROD_OPENCLAW} config set tools.allow '["web_search", "exec"]'

if [ -n "${TELEGRAM_BOT_TOKEN}" ]; then
    echo "[INFO] Configuring Telegram bot..."
    ${PROD_OPENCLAW} config set channels.telegram.botToken "${TELEGRAM_BOT_TOKEN}"
    ${PROD_OPENCLAW} config set channels.telegram.enabled true
    ${PROD_OPENCLAW} config set channels.telegram.allowFrom '["*"]'
    ${PROD_OPENCLAW} config set channels.telegram.dmPolicy "open"
    ${PROD_OPENCLAW} config set channels.telegram.groupPolicy "open"
else
    echo "[INFO] No TELEGRAM_BOT_TOKEN provided. Skipping Telegram configuration."
fi

${PROD_OPENCLAW} config set gateway.mode "local"

# 8. Install as a systemd --user service
echo "[STEP 7/9] Installing systemd --user service..."
cd ${INSTALL_DIR}
${PROD_OPENCLAW} daemon install --force

# 9. Enable and start service
echo "[STEP 8/9] Starting OpenClaw Gateway service..."
systemctl --user daemon-reload
systemctl --user enable openclaw-gateway.service
systemctl --user restart openclaw-gateway.service
loginctl enable-linger "${USER}" || echo "[WARN] Could not enable linger."

# 10. Final Verification
echo "[STEP 9/9] Verifying installation (waiting for startup)..."
MAX_RETRIES=5
RETRY_COUNT=0
HEALTH_OK=false

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    sleep 5
    if ${PROD_OPENCLAW} health > /dev/null 2>&1; then
        HEALTH_OK=true
        break
    fi
    echo "[INFO] Waiting for gateway to respond (attempt $((RETRY_COUNT+1))/$MAX_RETRIES)..."
    RETRY_COUNT=$((RETRY_COUNT+1))
done

if [ "$HEALTH_OK" = true ]; then
    ${PROD_OPENCLAW} health
    echo "--------------------------------------------------------"
    echo "SUCCESS: OpenClaw is successfully installed and running!"
    echo "DASHBOARD: Use 'openclaw dashboard' to access the UI."
    echo "PATH: Ensure ${BIN_DIR} is in your PATH."
    echo "--------------------------------------------------------"
else
    echo "[ERROR] Gateway health check failed."
    echo "[INFO] Recent service logs:"
    journalctl --user -u openclaw-gateway.service -n 20 --no-pager
    echo "--------------------------------------------------------"
fi
