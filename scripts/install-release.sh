#!/bin/bash
set -e

# Configuration (defaults for your specific setup)
INSTALL_DIR="${HOME}/openclaw-prod"
BIN_DIR="${HOME}/.local/bin"
OLLAMA_BASE_URL="http://192.168.145.70:11434"
QWEN_MODEL_ID="qwen3.5:122b"
SEARXNG_BASE_URL="http://192.168.145.70:8081"
TELEGRAM_TOKEN="8527725704:AAGNW8d76SjQGXCdl4F75EnCKWEp6cnT6nI"

echo "🚀 Starting OpenClaw Production Installation..."

# 1. Check prerequisites
echo "🔍 Checking for Node.js and pnpm..."
if ! command -v node &> /dev/null; then
    echo "❌ Node.js not found. Please install Node.js >= 22."
    exit 1
fi

if ! command -v pnpm &> /dev/null; then
    echo "🔄 Installing pnpm globally via npm..."
    npm install -g pnpm
fi

# 2. Cleanup existing installation if any
echo "🧹 Cleaning up previous installation..."
systemctl --user stop openclaw-gateway.service 2>/dev/null || true
systemctl --user disable openclaw-gateway.service 2>/dev/null || true
rm -f "${HOME}/.config/systemd/user/openclaw-gateway.service"

# Kill any stray processes using the port
STRAY_PID=$(lsof -t -i:18789 2>/dev/null || true)
if [ -n "$STRAY_PID" ]; then
    echo "🛑 Stopping stray process $STRAY_PID on port 18789..."
    kill -9 $STRAY_PID 2>/dev/null || true
fi

# 3. Extract OpenClaw package
echo "📦 Extracting package to ${INSTALL_DIR}..."
mkdir -p ${INSTALL_DIR}
TAR_FILE=$(ls openclaw-*.tgz | head -n 1)
if [ -z "${TAR_FILE}" ]; then
    echo "❌ No openclaw-*.tgz found in the current directory."
    exit 1
fi
tar -xzf "${TAR_FILE}" -C ${INSTALL_DIR} --strip-components=1

# 4. Install production dependencies
echo "📦 Installing production dependencies..."
cd ${INSTALL_DIR}
# Configure pnpm to allow built dependencies (native modules)
pnpm config set side-effects-cache-readonly false 2>/dev/null || true
pnpm install --production --no-frozen-lockfile --aggregate-output

# 5. Create local bin wrapper
echo "🔨 Setting up 'openclaw' CLI wrapper..."
mkdir -p ${BIN_DIR}
cat > ${BIN_DIR}/openclaw <<EOF
#!/bin/bash
node ${INSTALL_DIR}/openclaw.mjs "\$@"
EOF
chmod +x ${BIN_DIR}/openclaw

# Define the absolute path to the production openclaw
PROD_OPENCLAW="node ${INSTALL_DIR}/openclaw.mjs"

# 6. Initialize configuration
echo "⚙️ Initializing and applying custom configuration..."
# Use 'onboard' with --auth-choice skip for a minimal clean init
${PROD_OPENCLAW} onboard --non-interactive --accept-risk --skip-health --auth-choice skip --skip-channels --skip-search --skip-skills

# Configure Ollama provider (native API) with Qwen 3.5
${PROD_OPENCLAW} config set models.providers.ollama "{ \"baseUrl\": \"${OLLAMA_BASE_URL}\", \"api\": \"ollama\", \"models\": [{ \"id\": \"${QWEN_MODEL_ID}\", \"name\": \"Qwen 3.5 122B\", \"api\": \"ollama\", \"input\": [\"text\", \"image\"], \"compat\": { \"supportsTools\": true } }] }"
${PROD_OPENCLAW} config set agents.defaults.model "ollama/${QWEN_MODEL_ID}"

# Configure SearXNG
${PROD_OPENCLAW} config set tools.web.search.enabled true
${PROD_OPENCLAW} config set tools.web.search.provider "searxng"
${PROD_OPENCLAW} config set tools.web.search.searxng.baseUrl "${SEARXNG_BASE_URL}"

# Allow essential tools
${PROD_OPENCLAW} config set tools.allow '["web_search", "exec"]'

# Configure Telegram
${PROD_OPENCLAW} config set channels.telegram.botToken "${TELEGRAM_TOKEN}"
${PROD_OPENCLAW} config set channels.telegram.enabled true
${PROD_OPENCLAW} config set channels.telegram.allowFrom '["*"]'
${PROD_OPENCLAW} config set channels.telegram.dmPolicy "open"
${PROD_OPENCLAW} config set channels.telegram.groupPolicy "open"

# Set Gateway to local mode
${PROD_OPENCLAW} config set gateway.mode "local"

# 7. Install as a systemd --user service
echo "🔧 Installing systemd --user service..."
cd ${INSTALL_DIR}
${PROD_OPENCLAW} daemon install --force

# 8. Enable and start service
echo "🚀 Starting OpenClaw Gateway service..."
systemctl --user daemon-reload
systemctl --user enable openclaw-gateway.service
systemctl --user restart openclaw-gateway.service
loginctl enable-linger "${USER}" || echo "⚠️ Could not enable linger."

# 9. Final Verification
echo "✅ Installation complete!"
echo "🔍 Running health check (waiting for startup)..."
MAX_RETRIES=5
RETRY_COUNT=0
HEALTH_OK=false

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    sleep 5
    if ${PROD_OPENCLAW} health > /dev/null 2>&1; then
        HEALTH_OK=true
        break
    fi
    echo "⏳ Waiting for gateway to respond (attempt $((RETRY_COUNT+1))/$MAX_RETRIES)..."
    RETRY_COUNT=$((RETRY_COUNT+1))
done

if [ "$HEALTH_OK" = true ]; then
    ${PROD_OPENCLAW} health
    echo "--------------------------------------------------------"
    echo "⭐ OpenClaw is successfully installed and running!"
    echo "⭐ Use 'openclaw dashboard' to access the Control UI."
    echo "⭐ Ensure ${BIN_DIR} is in your PATH."
    echo "--------------------------------------------------------"
else
    echo "⚠️ Gateway health check failed."
    echo "🔍 Recent service logs:"
    journalctl --user -u openclaw-gateway.service -n 20 --no-pager
    echo "--------------------------------------------------------"
    echo "❌ Installation finished with warnings. Please check the logs above."
    echo "--------------------------------------------------------"
fi
