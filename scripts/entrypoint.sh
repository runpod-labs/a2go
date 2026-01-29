#!/bin/bash
# entrypoint.sh - Moltbot + vLLM startup script for RunPod
set -e

echo "============================================"
echo "  Moltbot + vLLM Startup"
echo "============================================"

# Configuration from environment
MODEL_NAME="${MODEL_NAME:-Qwen/Qwen2.5-Coder-7B-Instruct}"
SERVED_MODEL_NAME="${SERVED_MODEL_NAME:-local-coder}"
VLLM_API_KEY="${VLLM_API_KEY:-changeme}"
MAX_MODEL_LEN="${MAX_MODEL_LEN:-16384}"
GPU_MEMORY_UTILIZATION="${GPU_MEMORY_UTILIZATION:-0.90}"
TOOL_CALL_PARSER="${TOOL_CALL_PARSER:-hermes}"
TENSOR_PARALLEL_SIZE="${TENSOR_PARALLEL_SIZE:-auto}"
HF_HOME="${HF_HOME:-/workspace/huggingface}"
MOLTBOT_STATE_DIR="${MOLTBOT_STATE_DIR:-/workspace/.clawdbot}"
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"

export HF_HOME
export MOLTBOT_STATE_DIR

BOT_CMD="moltbot"
if ! command -v "$BOT_CMD" >/dev/null 2>&1; then
    BOT_CMD="clawdbot"
fi

# Ensure directories exist
mkdir -p "$HF_HOME" "$MOLTBOT_STATE_DIR" /workspace/clawd

# Auto-detect tensor parallel size
if [ "$TENSOR_PARALLEL_SIZE" = "auto" ]; then
    GPU_COUNT=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | wc -l || echo "1")
    TENSOR_PARALLEL_SIZE=$GPU_COUNT
fi

echo "Configuration:"
echo "  Model: $MODEL_NAME"
echo "  Served as: $SERVED_MODEL_NAME"
echo "  Max context: $MAX_MODEL_LEN"
echo "  GPU utilization: $GPU_MEMORY_UTILIZATION"
echo "  Tensor parallel: $TENSOR_PARALLEL_SIZE"
echo "  Tool parser: $TOOL_CALL_PARSER"
echo ""

# Initialize Moltbot config if not exists
if [ ! -f "$MOLTBOT_STATE_DIR/clawdbot.json" ]; then
    echo "Creating Moltbot configuration (legacy clawdbot.json)..."

    # Build telegram config based on whether token is provided
    if [ -n "$TELEGRAM_BOT_TOKEN" ]; then
        TELEGRAM_CONFIG="\"telegram\": { \"enabled\": true, \"botToken\": \"${TELEGRAM_BOT_TOKEN}\" }"
    else
        TELEGRAM_CONFIG="\"telegram\": { \"enabled\": true }"
    fi

    cat > "$MOLTBOT_STATE_DIR/clawdbot.json" << EOF
{
  "agents": {
    "defaults": {
      "model": { "primary": "local-vllm/${SERVED_MODEL_NAME}" },
      "workspace": "/workspace/clawd"
    }
  },
  "models": {
    "providers": {
      "local-vllm": {
        "baseUrl": "http://localhost:8000/v1",
        "apiKey": "${VLLM_API_KEY}",
        "api": "openai-completions",
        "models": [{
          "id": "${SERVED_MODEL_NAME}",
          "name": "Local Coding Model",
          "contextWindow": ${MAX_MODEL_LEN},
          "maxTokens": 4096,
          "reasoning": false,
          "input": ["text"],
          "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 }
        }]
      }
    }
  },
  "channels": {
    ${TELEGRAM_CONFIG}
  },
  "gateway": {
    "mode": "local"
  },
  "logging": { "level": "info" }
}
EOF
    chmod 600 "$MOLTBOT_STATE_DIR/clawdbot.json"
    echo "Config created. Telegram token: ${TELEGRAM_BOT_TOKEN:+provided}${TELEGRAM_BOT_TOKEN:-NOT SET - add manually}"
else
    echo "Existing config found at $MOLTBOT_STATE_DIR/clawdbot.json - preserving it"
fi

# Initialize Moltbot workspace if empty
if [ ! -f "/workspace/clawd/AGENTS.md" ]; then
    echo "Initializing Moltbot workspace..."
    "$BOT_CMD" setup --non-interactive --accept-risk --workspace /workspace/clawd 2>/dev/null || true
fi

# Build vLLM command
VLLM_CMD="vllm serve $MODEL_NAME"
VLLM_CMD+=" --host 0.0.0.0 --port 8000"
VLLM_CMD+=" --max-model-len $MAX_MODEL_LEN"
VLLM_CMD+=" --gpu-memory-utilization $GPU_MEMORY_UTILIZATION"
VLLM_CMD+=" --served-model-name $SERVED_MODEL_NAME"
VLLM_CMD+=" --api-key $VLLM_API_KEY"
VLLM_CMD+=" --enable-auto-tool-choice"
VLLM_CMD+=" --tool-call-parser $TOOL_CALL_PARSER"

if [ "$TENSOR_PARALLEL_SIZE" -gt 1 ]; then
    VLLM_CMD+=" --tensor-parallel-size $TENSOR_PARALLEL_SIZE"
fi

echo "Starting vLLM server..."
echo "Command: $VLLM_CMD"
echo ""

# Start vLLM in background
$VLLM_CMD &
VLLM_PID=$!

# Wait for vLLM to be ready
echo "Waiting for vLLM to start..."
MAX_WAIT=300
WAITED=0
while [ $WAITED -lt $MAX_WAIT ]; do
    if curl -s http://localhost:8000/health > /dev/null 2>&1; then
        echo "vLLM is ready!"
        break
    fi
    sleep 5
    WAITED=$((WAITED + 5))
    echo "  Waiting... ($WAITED/${MAX_WAIT}s)"
done

if [ $WAITED -ge $MAX_WAIT ]; then
    echo "ERROR: vLLM failed to start within ${MAX_WAIT} seconds"
    exit 1
fi

# Start Moltbot gateway
echo ""
echo "Starting Moltbot gateway..."
"$BOT_CMD" gateway &
GATEWAY_PID=$!

echo ""
echo "============================================"
echo "  Services Running"
echo "============================================"
echo "  vLLM API: http://localhost:8000"
echo "  Moltbot Gateway: ws://localhost:18789"
echo ""
echo "  vLLM PID: $VLLM_PID"
echo "  Gateway PID: $GATEWAY_PID"
echo "============================================"
echo ""

# Keep container running and handle signals
trap "kill $VLLM_PID $GATEWAY_PID 2>/dev/null; exit 0" SIGTERM SIGINT

# Wait for either process to exit
wait -n $VLLM_PID $GATEWAY_PID
EXIT_CODE=$?

echo "A process exited with code $EXIT_CODE"
kill $VLLM_PID $GATEWAY_PID 2>/dev/null || true
exit $EXIT_CODE
