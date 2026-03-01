# OpenClaw Setup Guide - Custom Ollama Provider

This document describes the complete setup sequence to deploy OpenClaw with a custom Ollama server as the AI model provider.

## Prerequisites

- **OS**: Linux (tested on Raspberry Pi OS / Ubuntu)
- **Node.js**: Version 22 or higher
- **pnpm**: Package manager (v10.x recommended)
- **Git**: For cloning repositories
- **screen** or **tmux**: Terminal multiplexer for background processes
- **Ollama server**: Running on a reachable network endpoint

## Setup Sequence

### Step 1: Install Prerequisites

```bash
# Install pnpm globally
npm install -g pnpm

# Verify Node.js version (must be >= 22)
node --version

# Verify pnpm version
pnpm --version
```

### Step 2: Clone OpenClaw Repository

```bash
# Choose your working directory
mkdir -p ~/test/claude/openclaw
cd ~/test/claude/openclaw

# Clone the repository
git clone https://github.com/openclaw/openclaw.git
cd openclaw
```

### Step 3: Install Dependencies

```bash
# Install all dependencies (this may take several minutes)
pnpm install
```

**Expected output**: Installs 1019 dependencies including:

- @mariozechner/pi-agent-core
- @mariozechner/pi-ai
- @mariozechner/pi-coding-agent
- And many other dependencies

### Step 4: Build the Project

```bash
# Build the TypeScript project
pnpm build
```

**Expected output**: Generates `dist/` directory with compiled JavaScript files (300+ output files).

### Step 5: Configure Custom Ollama Provider

Run the onboard command with custom provider parameters:

```bash
# Run onboard with non-interactive flags
pnpm openclaw onboard \
  --non-interactive \
  --accept-risk \
  --auth-choice custom-api-key \
  --custom-base-url http://YOUR_OLLAMA_IP:11434/v1 \
  --custom-model-id qwen3.5:35b \
  --custom-compatibility openai \
  --skip-health
```

**Replace placeholders:**

- `YOUR_OLLAMA_IP` - Your Ollama server IP address (e.g., `192.168.145.70`)
- `qwen3.5:35b` - Your model name from Ollama (list with `ollama list` or check `curl http://YOUR_OLLAMA_IP:11434/api/tags`)

**Important flags explained:**

- `--non-interactive` - Run without prompts
- `--accept-risk` - Accept terms and conditions
- `--auth-choice custom-api-key` - Use custom API key authentication
- `--custom-base-url` - The Ollama API endpoint (must end with `/v1`)
- `--custom-model-id` - The model name to use
- `--custom-compatibility` - API compatibility type (`openai` or `anthropic`)
- `--skip-health` - Skip health check during onboarding

### Step 6: Update Configuration

After running onboard, the configuration file is created at `~/.openclaw/openclaw.json`. You need to make two modifications:

#### 6a. Add API Key for Ollama Provider

Open the configuration file:

```bash
cat ~/.openclaw/openclaw.json
```

Find the `custom-...` provider section and add the `apiKey` field, and ensure `thinkingDefault` is set to `"off"` in the agents section:

```json
{
  "models": {
    "mode": "merge",
    "providers": {
      "custom-YOUR_OLLAMA_IP-11434": {
        "baseUrl": "http://YOUR_OLLAMA_IP:11434/v1",
        "api": "openai-completions",
        "apiKey": "ollama",
        "models": [
          {
            "id": "qwen3.5:35b",
            "name": "qwen3.5:35b (Custom Provider)",
            "reasoning": true,
            "input": ["text"],
            "cost": {
              "input": 0,
              "output": 0,
              "cacheRead": 0,
              "cacheWrite": 0
            },
            "contextWindow": 128000,
            "maxTokens": 32768
          }
        ]
      }
    }
  },
  "agents": {
    "defaults": {
      "thinkingDefault": "off",
      ...
    }
  },
  ...
}
```

**Key modifications:**

1. **`apiKey: "ollama"`** - Required for authentication (even for unauthenticated Ollama servers)
2. **`thinkingDefault: "off"`** - CRITICAL: Prevents "400 think value low is not supported" errors on OpenAI-compatible providers.
3. **`reasoning: true`** - Set to `true` if your model supports chain-of-thought reasoning
4. **`contextWindow: 128000`** - Maximum context window size (adjust based on your model)
5. **`maxTokens: 32768`** - Maximum output tokens (adjust based on your model)

#### 6b. Configure SearXNG Search Provider (Optional)

If you have a SearXNG instance, add the following to the `tools` section:

```json
{
  "tools": {
    "web": {
      "search": {
        "enabled": true,
        "provider": "searxng",
        "searxng": {
          "baseUrl": "http://YOUR_SEARXNG_IP:8081/Search"
        }
      }
    }
  }
}
```

#### 6c. Edit Configuration File

If you manually edited the file, save and close it. The file location is:

```
~/.openclaw/openclaw.json
```

### Step 7: Verify Ollama Server Connectivity

Before starting the gateway, verify your Ollama server is accessible:

```bash
# Check if Ollama server is running and list models
curl http://YOUR_OLLAMA_IP:11434/api/tags

# Expected output should list your available models
```

**Test endpoint**: Your Ollama server should respond with a JSON array of models.

### Step 8: Start OpenClaw Gateway

Start the gateway in a `screen` session so it continues running after you disconnect:

```bash
# Navigate to OpenClaw directory
cd ~/test/claude/openclaw/openclaw

# Create and start a screen session for the gateway
screen -dmS openclaw pnpm openclaw gateway run
```

**Detach from screen** (when you want to leave the session):

- Press `Ctrl+A`, then `D`

### Step 9: Verify Gateway is Running

```bash
# List screen sessions
screen -ls

# Expected output:
# openclaw	(pid) (Date) (Detached)

# Check if OpenClaw processes are running
ps aux | grep openclaw | grep -v grep

# Expected output should show `openclaw-gateway` process

# Test the gateway endpoint
curl http://127.0.0.1:18789/

# Expected output: HTML page for OpenClaw Control UI
```

### Step 10: Test OpenClaw CLI

```bash
# Check gateway status
pnpm openclaw status

# Send a test message to the agent
pnpm openclaw agent --agent main --message "Hello, what can you do ?"
```

**Expected output**: The agent should respond with a list of its capabilities.

### Step 11: Access Control UI (Optional)

Open your browser and navigate to:

```
http://127.0.0.1:18789/
```

---

## Summary of Configuration Changes

### Configuration File Location

```
~/.openclaw/openclaw.json
```

### Critical Configuration Points

| Setting                            | Value                         | Purpose                               |
| ---------------------------------- | ----------------------------- | ------------------------------------- |
| `gateway.mode`                     | `local`                       | Gateway runs on localhost             |
| `gateway.port`                     | `18789`                       | WebSocket port for client connections |
| `gateway.bind`                     | `loopback`                    | Binds to 127.0.0.1                    |
| `agents.defaults.model.primary`    | `custom-IP-11434/qwen3.5:35b` | Default model to use                  |
| `agents.defaults.thinkingDefault`  | `off`                         | Prevents 400 errors on Ollama         |
| `models.providers.*.apiKey`        | `ollama`                      | API key for custom provider           |
| `tools.web.search.provider`        | `searxng`                     | Enables SearXNG search                |
| `tools.web.search.searxng.baseUrl` | `http://IP:8081/Search`       | Your SearXNG endpoint                 |

---

## Commands Reference

### Start Gateway (Initial Setup)

```bash
cd ~/test/claude/openclaw/openclaw
screen -dmS openclaw pnpm openclaw gateway run
```

### Reattach to Gateway Session

```bash
# List sessions
screen -ls

# Attach to session
screen -r openclaw

# Detach (Ctrl+A, then D)
```

### Common CLI Commands

```bash
# Check gateway status
pnpm openclaw status

# Send message to agent
pnpm openclaw agent --agent main --message "Your message here"

# Follow logs
pnpm openclaw logs --follow

# Check gateway connection
pnpm openclaw gateway probe

# Run doctor for diagnostics
pnpm openclaw doctor
```

### Screen/Tmux Session Management

```bash
# List screen sessions
screen -ls

# List tmux sessions (alternative)
tmux list-sessions

# Attach to session
screen -r openclaw

# Kill screen session (when done)
screen -X -S openclaw quit

# Kill tmux session (alternative)
tmux kill-session -t openclaw
```

---

## Troubleshooting

### Error: "No API key found for provider"

**Solution**: Add `apiKey: "ollama"` to the custom provider configuration in `~/.openclaw/openclaw.json`.

### Error: "Gateway not responding"

**Solution**:

1. Check if gateway process is running: `ps aux | grep openclaw`
2. Check gateway logs: `pnpm openclaw logs --follow`
3. Restart gateway: `screen -X -S openclaw quit` then `screen -dmS openclaw pnpm openclaw gateway run`

### Error: "Command 'gateway' not found"

**Solution**: Use `pnpm openclaw gateway run` instead of `pnpm gateway run`.

### Error: "Required option '-m, --message' not specified"

**Solution**: Use `--message` with `agent`, not `agent message send`. Correct format:

```bash
pnpm openclaw agent --agent main --message "Your message"
```

---

## Verification Checklist

Before considering the setup complete, verify:

- [ ] OpenClaw repository cloned to `~/test/claude/openclaw/openclaw`
- [ ] Dependencies installed (`pnpm install` completed successfully)
- [ ] Project built (`pnpm build` completed successfully)
- [ ] Configuration file created at `~/.openclaw/openclaw.json`
- [ ] Custom provider configured with `apiKey: "ollama"`
- [ ] Ollama server accessible via `curl http://YOUR_OLLAMA_IP:11434/api/tags`
- [ ] Gateway screen session running (`screen -ls` shows `openclaw`)
- [ ] Gateway responds on port 18789
- [ ] `pnpm openclaw status` shows gateway as reachable
- [ ] `pnpm openclaw agent --agent main --message "test"` returns a response

---

## Update Available

Check for available updates:

```bash
cd ~/test/claude/openclaw/openclaw
git pull origin main
pnpm install
pnpm build
```

---

## Additional Notes

1. **Model Selection**: The setup uses `qwen3.5:35b` as an example. Change the `custom-model-id` during onboard and update the `id` field in the configuration file.

2. **Context Window**: The default context window is 4096 tokens. Update to the correct value for your model (e.g., `128000` for Qwen 3.5).

3. **Reasoning Support**: Set `reasoning: true` only if your model produces chain-of-thought reasoning output.

4. **Security**: Keep the gateway binding to `loopback` for security unless you need external access.

5. **Backup**: Keep a backup of your `~/.openclaw/openclaw.json` configuration file.
