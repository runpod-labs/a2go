#!/bin/bash
# setup-moltbot.sh - Install and configure Moltbot on RunPod
# Prerequisites: vLLM server running on port 8000

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Configuration
VLLM_HOST="${VLLM_HOST:-localhost}"
VLLM_PORT="${VLLM_PORT:-8000}"
VLLM_API_KEY="${VLLM_API_KEY:-changeme}"
SERVED_MODEL_NAME="${SERVED_MODEL_NAME:-qwen3-30b-a3b}"
MOLTBOT_CONFIG_DIR="${MOLTBOT_CONFIG_DIR:-$HOME/.clawdbot}"
RUNPOD_POD_ID="${RUNPOD_POD_ID:-}"

# Print banner
echo ""
echo "==========================================="
echo "  Moltbot Setup Script"
echo "==========================================="
echo ""

# Check if running as root (common on RunPod)
if [ "$EUID" -eq 0 ]; then
    log_info "Running as root"
fi

# Step 1: Install Node.js if not present
log_info "Checking Node.js installation..."
if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version)
    log_success "Node.js already installed: $NODE_VERSION"
else
    log_info "Installing Node.js 22.x..."
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
    apt-get install -y nodejs
    log_success "Node.js installed: $(node --version)"
fi

# Verify npm is available
if ! command -v npm &> /dev/null; then
    log_error "npm not found after Node.js installation"
    exit 1
fi
log_info "npm version: $(npm --version)"

# Step 2: Install Moltbot
log_info "Installing Moltbot..."
npm install -g moltbot@latest
BOT_CMD="moltbot"
if ! command -v "$BOT_CMD" &> /dev/null; then
    BOT_CMD="clawdbot"
fi
log_success "Moltbot installed: $("$BOT_CMD" --version 2>/dev/null || echo 'version check failed')"

# Step 3: Wait for vLLM to be ready
log_info "Waiting for vLLM server to be ready..."
MAX_RETRIES=60
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -s "http://${VLLM_HOST}:${VLLM_PORT}/health" > /dev/null 2>&1; then
        log_success "vLLM server is ready!"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        log_error "vLLM server did not become ready within 5 minutes"
        exit 1
    fi
    echo -n "."
    sleep 5
done
echo ""

# Verify model is available
log_info "Verifying model availability..."
MODELS_RESPONSE=$(curl -s "http://${VLLM_HOST}:${VLLM_PORT}/v1/models" \
    -H "Authorization: Bearer ${VLLM_API_KEY}")
echo "Available models: $MODELS_RESPONSE"

# Step 4: Create Moltbot configuration directory
log_info "Creating Moltbot configuration..."
mkdir -p "$MOLTBOT_CONFIG_DIR"

# Determine the base URL for the vLLM endpoint
if [ -n "$RUNPOD_POD_ID" ]; then
    # Running on RunPod - use proxy URL
    VLLM_BASE_URL="https://${RUNPOD_POD_ID}-${VLLM_PORT}.proxy.runpod.net/v1"
else
    # Local or direct connection
    VLLM_BASE_URL="http://${VLLM_HOST}:${VLLM_PORT}/v1"
fi

# Step 5: Create Moltbot configuration file
cat > "$MOLTBOT_CONFIG_DIR/clawdbot.json" << EOF
{
  "agents": {
    "defaults": {
      "model": {
        "primary": "runpod-vllm/${SERVED_MODEL_NAME}"
      }
    }
  },
  "models": {
    "providers": {
      "runpod-vllm": {
        "baseUrl": "${VLLM_BASE_URL}",
        "apiKey": "${VLLM_API_KEY}",
        "api": "openai-completions",
        "models": [
          {
            "id": "${SERVED_MODEL_NAME}",
            "name": "Local Coding Model (${SERVED_MODEL_NAME})",
            "contextWindow": 32768,
            "maxTokens": 8192
          }
        ]
      }
    }
  },
  "logging": {
    "level": "info"
  }
}
EOF

log_success "Moltbot configuration created at $MOLTBOT_CONFIG_DIR/clawdbot.json (legacy file name)"

# Step 6: Test Moltbot connection
log_info "Testing Moltbot configuration..."
echo ""
echo "Configuration summary:"
echo "  vLLM URL: $VLLM_BASE_URL"
echo "  Model: $SERVED_MODEL_NAME"
echo "  Config dir: $MOLTBOT_CONFIG_DIR"
echo ""

# Test a simple completion
log_info "Testing completion..."
TEST_RESPONSE=$(curl -s "http://${VLLM_HOST}:${VLLM_PORT}/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${VLLM_API_KEY}" \
    -d "{
        \"model\": \"${SERVED_MODEL_NAME}\",
        \"messages\": [{\"role\": \"user\", \"content\": \"Say hello in one word.\"}],
        \"max_tokens\": 10
    }" 2>&1)

if echo "$TEST_RESPONSE" | grep -q "choices"; then
    log_success "Completion test passed!"
    echo "Response: $(echo $TEST_RESPONSE | jq -r '.choices[0].message.content' 2>/dev/null || echo $TEST_RESPONSE)"
else
    log_warn "Completion test had issues. Response: $TEST_RESPONSE"
fi

echo ""
echo "==========================================="
echo "  Setup Complete!"
echo "==========================================="
echo ""
echo "To start Moltbot, run:"
echo "  moltbot"
echo ""
echo "To start with daemon mode:"
echo "  moltbot onboard --install-daemon"
echo ""
echo "Configuration file: $MOLTBOT_CONFIG_DIR/clawdbot.json"
echo ""
