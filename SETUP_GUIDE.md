# OpenClaw Setup Guide - Custom Ollama Provider

This document describes the complete setup sequence to deploy OpenClaw with a custom Ollama server as the AI model provider.

## Prerequisites

- **OS**: Linux (tested on Raspberry Pi OS / Ubuntu)
- **Node.js**: Version 22 or higher
- **pnpm**: Package manager (v10.x recommended)
- **Git**: For cloning repositories
- **systemd**: For background service management
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

# Create a local bin directory and a wrapper for easy CLI access
mkdir -p ~/.local/bin
echo "#!/bin/bash" > ~/.local/bin/openclaw
echo "node $(pwd)/openclaw.mjs \"\$@\"" >> ~/.local/bin/openclaw
chmod +x ~/.local/bin/openclaw

# Ensure ~/.local/bin is in your PATH (add this to your .bashrc or .zshrc)
export PATH="\$HOME/.local/bin:\$PATH"
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

### Step 4: Build the Project

```bash
# Build the TypeScript project (required for CLI and Gateway)
pnpm build

# Build the Control UI assets (required for Dashboard)
pnpm ui:build
```

**Note**: The CLI and Gateway require the compiled files in the `dist/` directory to function.

### Step 5: Configure Custom Ollama Provider

Run the onboard command with custom provider parameters:

```bash
# Run onboard with non-interactive flags
openclaw setup
openclaw configure
```

Alternatively, you can manually edit the configuration at `~/.openclaw/openclaw.json`.

### Step 6: Update Configuration

After initial setup, refine your `~/.openclaw/openclaw.json` for your specific models.

#### 6a. Configure Ollama / Qwen 3.5 (Vision & Tools)

For models like **Qwen 3.5 122B** which support vision and tools natively in Ollama:

```json
{
  "models": {
    "providers": {
      "ollama": {
        "baseUrl": "http://YOUR_OLLAMA_IP:11434",
        "api": "ollama",
        "models": [
          {
            "id": "qwen3.5:122b",
            "name": "Qwen 3.5 122B",
            "input": ["text", "image"],
            "compat": {
              "supportsTools": true
            }
          }
        ]
      }
    }
  },
  "agents": {
    "defaults": {
      "model": "ollama/qwen3.5:122b"
    }
  }
}
```

#### 6b. Important: Model Compatibility (GPT-OSS 120B)

Some models like **gpt-oss:120b** have specific API requirements:

- **API Support**: `gpt-oss:120b` primarily supports the **OpenAI-compatible API** path.
- **Configuration**: Use `api: "openai-completions"` and point the `baseUrl` to the `/v1` endpoint (e.g., `http://IP:11434/v1`).
- **Native Ollama API**: Native `/api/chat` may result in plain-text JSON tool calls instead of structured execution.

#### 6c. Configure SearXNG Search Provider

```json
{
  "tools": {
    "web": {
      "search": {
        "enabled": true,
        "provider": "searxng",
        "searxng": {
          "baseUrl": "http://YOUR_SEARXNG_IP:8081"
        }
      }
    }
  }
}
```

### Step 7: Verify Ollama Server Connectivity

```bash
curl http://YOUR_OLLAMA_IP:11434/api/tags
```

### Step 8: Install and Start OpenClaw Gateway

Instead of using `screen`, use the built-in daemon installer for a proper `systemd --user` service:

```bash
# Install the gateway service
openclaw daemon install

# Start the service
systemctl --user start openclaw-gateway.service

# Enable lingering so the service runs even after logout
loginctl enable-linger $USER
```

### Step 9: Verify Gateway Status

```bash
# Check systemd status
systemctl --user status openclaw-gateway.service

# Check gateway logs
journalctl --user -u openclaw-gateway.service -f

# Check OpenClaw health
openclaw health
```

### Step 10: Test OpenClaw CLI

Always use a `--session-id` for ad-hoc tests to maintain chat history:

```bash
openclaw agent --session-id test-chat --message "Hello! What is your model name?"
```

---

## Summary of Critical Settings

| Setting                | Value                            | Purpose                                  |
| ---------------------- | -------------------------------- | ---------------------------------------- |
| `api`                  | `ollama` OR `openai-completions` | Native vs OpenAI-compatible bridge       |
| `input`                | `["text", "image"]`              | Required for Vision support              |
| `compat.supportsTools` | `true`                           | Required for structured tool execution   |
| `gateway.mode`         | `local`                          | Allows the gateway to start on your host |

---

## Troubleshooting

### Tool calls are appearing as plain JSON text

**Cause**: The model isn't using the structured tool-calling format.
**Solution**: Ensure `compat.supportsTools: true` is set. If using `gpt-oss:120b`, switch to `api: "openai-completions"` with the `/v1` baseUrl.

### Command 'openclaw' not found

**Cause**: The wrapper script isn't in your PATH.
**Solution**: Re-run the Step 1 wrapper commands and ensure `~/.local/bin` is in your `.bashrc`.

### Gateway not starting

**Cause**: Missing `gateway.mode: "local"`.
**Solution**: `openclaw config set gateway.mode local`.
