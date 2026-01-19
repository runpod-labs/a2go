#!/bin/bash
# start-vllm.sh - vLLM startup script for Clawdbot on RunPod
# Handles model download, GPU detection, and vLLM server startup

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Configuration with defaults
MODEL_NAME="${MODEL_NAME:-Qwen/Qwen3-30B-A3B-Instruct}"
SERVED_MODEL_NAME="${SERVED_MODEL_NAME:-qwen3-30b-a3b}"
VLLM_API_KEY="${VLLM_API_KEY:-changeme}"
MAX_MODEL_LEN="${MAX_MODEL_LEN:-32768}"
GPU_MEMORY_UTILIZATION="${GPU_MEMORY_UTILIZATION:-0.90}"
TENSOR_PARALLEL_SIZE="${TENSOR_PARALLEL_SIZE:-auto}"
TOOL_CALL_PARSER="${TOOL_CALL_PARSER:-hermes}"
REASONING_PARSER="${REASONING_PARSER:-}"
HOST="${HOST:-0.0.0.0}"
PORT="${PORT:-8000}"
HF_HOME="${HF_HOME:-/workspace/huggingface}"

# Ensure HF_HOME exists
mkdir -p "$HF_HOME"
export HF_HOME

# Print banner
echo ""
echo "==========================================="
echo "  Clawdbot vLLM Server Startup"
echo "==========================================="
echo ""

# Check for GPU
log_info "Checking GPU availability..."
if ! command -v nvidia-smi &> /dev/null; then
    log_error "nvidia-smi not found. Is NVIDIA driver installed?"
    exit 1
fi

GPU_COUNT=$(nvidia-smi --query-gpu=name --format=csv,noheader | wc -l)
if [ "$GPU_COUNT" -eq 0 ]; then
    log_error "No GPUs detected!"
    exit 1
fi

log_success "Found $GPU_COUNT GPU(s):"
nvidia-smi --query-gpu=index,name,memory.total --format=csv,noheader | while read line; do
    echo "  - $line"
done

# Auto-detect tensor parallel size if set to auto
if [ "$TENSOR_PARALLEL_SIZE" = "auto" ]; then
    TENSOR_PARALLEL_SIZE=$GPU_COUNT
    log_info "Auto-detected tensor parallel size: $TENSOR_PARALLEL_SIZE"
fi

# Validate tensor parallel size
if [ "$TENSOR_PARALLEL_SIZE" -gt "$GPU_COUNT" ]; then
    log_error "Tensor parallel size ($TENSOR_PARALLEL_SIZE) exceeds GPU count ($GPU_COUNT)"
    exit 1
fi

# Check if vLLM nightly is needed for GLM-4.7
if [[ "$MODEL_NAME" == *"GLM-4.7"* ]]; then
    log_info "GLM-4.7 detected - checking for vLLM nightly..."
    VLLM_VERSION=$(python -c "import vllm; print(vllm.__version__)" 2>/dev/null || echo "unknown")
    log_info "Current vLLM version: $VLLM_VERSION"

    # Check if we need to upgrade
    if [[ ! "$VLLM_VERSION" =~ "dev" ]] && [[ ! "$VLLM_VERSION" =~ "0.13" ]]; then
        log_warn "GLM-4.7 requires vLLM nightly. Upgrading..."
        pip install -U vllm --pre --quiet
        log_success "vLLM upgraded"
    fi
fi

# Build vLLM command
VLLM_CMD="vllm serve $MODEL_NAME"
VLLM_CMD+=" --host $HOST"
VLLM_CMD+=" --port $PORT"
VLLM_CMD+=" --max-model-len $MAX_MODEL_LEN"
VLLM_CMD+=" --gpu-memory-utilization $GPU_MEMORY_UTILIZATION"
VLLM_CMD+=" --served-model-name $SERVED_MODEL_NAME"
VLLM_CMD+=" --api-key $VLLM_API_KEY"

# Add tensor parallel if using multiple GPUs
if [ "$TENSOR_PARALLEL_SIZE" -gt 1 ]; then
    VLLM_CMD+=" --tensor-parallel-size $TENSOR_PARALLEL_SIZE"
fi

# Add tool calling support
VLLM_CMD+=" --enable-auto-tool-choice"
if [ -n "$TOOL_CALL_PARSER" ]; then
    VLLM_CMD+=" --tool-call-parser $TOOL_CALL_PARSER"
fi

# Add reasoning parser for GLM-4.7
if [ -n "$REASONING_PARSER" ]; then
    VLLM_CMD+=" --reasoning-parser $REASONING_PARSER"
fi

# Add speculative decoding for GLM-4.7
if [[ "$MODEL_NAME" == *"GLM-4.7"* ]]; then
    VLLM_CMD+=" --speculative-config.method mtp"
    VLLM_CMD+=" --speculative-config.num_speculative_tokens 1"
fi

# Print configuration summary
echo ""
log_info "Configuration Summary:"
echo "  Model: $MODEL_NAME"
echo "  Served as: $SERVED_MODEL_NAME"
echo "  Max context: $MAX_MODEL_LEN tokens"
echo "  GPU memory: ${GPU_MEMORY_UTILIZATION}%"
echo "  Tensor parallel: $TENSOR_PARALLEL_SIZE"
echo "  Tool parser: $TOOL_CALL_PARSER"
echo "  Host: $HOST:$PORT"
echo ""

# Check if model is already downloaded
log_info "Checking model cache..."
CACHE_PATH="$HF_HOME/hub/models--${MODEL_NAME//\//-}"
if [ -d "$CACHE_PATH" ]; then
    log_success "Model found in cache at $CACHE_PATH"
else
    log_warn "Model not in cache. Will download on first start (this may take a while)."
fi

# Start vLLM server
log_info "Starting vLLM server..."
echo "Command: $VLLM_CMD"
echo ""
echo "==========================================="
echo ""

# Execute vLLM
exec $VLLM_CMD
