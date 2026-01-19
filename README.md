# Clawdbot on RunPod with Local Coding Model

Run Clawdbot with open-source coding models on RunPod using vLLM. Chat with your AI assistant via Telegram!

## Overview

This project provides a complete setup for running Clawdbot with local coding models on RunPod infrastructure. It uses vLLM for high-performance inference with tool calling support.

## Quick Start (Docker Image - Recommended)

### Option A: Use Pre-built Docker Image

```bash
# On RunPod, create a pod with:
# - Image: your-dockerhub-username/clawdbot-vllm:latest
# - GPU: 1x H100 80GB (or larger for bigger models)
# - Volume: 150GB at /workspace
# - Ports: 8000/http, 18789/http, 22/tcp

# Environment variables:
MODEL_NAME=Qwen/Qwen2.5-Coder-7B-Instruct
VLLM_API_KEY=your-secure-key
```

### Option B: Build Docker Image Yourself

```bash
# Clone and build
git clone https://github.com/your-repo/runpod-clawdbot.git
cd runpod-clawdbot

# Build the image
docker build -t clawdbot-vllm:latest .

# Push to Docker Hub (for RunPod to use)
docker tag clawdbot-vllm:latest your-username/clawdbot-vllm:latest
docker push your-username/clawdbot-vllm:latest
```

### Set Up Telegram (After Pod is Running)

```bash
# SSH into your pod
ssh root@YOUR_POD_IP -p SSH_PORT

# Add your Telegram bot token (get it from @BotFather)
clawdbot channels add --channel telegram --token "YOUR_BOT_TOKEN"

# Restart gateway
pkill clawdbot-gateway && clawdbot gateway &

# Check status
clawdbot channels status
```

Now message your bot on Telegram! 🎉

---

## Manual Setup (Without Docker)

### Phase 1: Deploy to RunPod

1. **Create a RunPod Pod**

   Go to [RunPod Console](https://runpod.io/console/pods) and create a new pod:

   - **Template**: Select `vllm/vllm-openai:v0.12.0`
   - **GPU**: 1x NVIDIA H100 PCIe (80GB)
   - **Container Disk**: 50 GB
   - **Volume**: 100 GB
   - **Ports**: 8000/http, 8888/http, 22/tcp

2. **SSH into your pod and run the setup**

   ```bash
   # Clone this repo
   git clone https://github.com/your-repo/runpod-clawdbot.git
   cd runpod-clawdbot

   # Set environment variables
   export VLLM_API_KEY="your-secure-key"
   export MODEL_NAME="Qwen/Qwen3-30B-A3B-Instruct"
   export SERVED_MODEL_NAME="qwen3-30b-a3b"
   export TOOL_CALL_PARSER="hermes"
   export HF_HOME="/workspace/huggingface"

   # Start vLLM server
   ./scripts/start-vllm.sh
   ```

3. **Wait for model to load** (first run downloads ~60GB)

4. **Test the server** (in a new terminal)

   ```bash
   ./tests/test-vllm.sh
   ./tests/test-tool-calling.sh
   ```

5. **Install and configure Clawdbot**

   ```bash
   export RUNPOD_POD_ID="your-pod-id"  # Found in RunPod console URL
   ./scripts/setup-clawdbot.sh
   ```

### Phase 2: Upgrade to GLM-4.7 (Optional)

For SOTA tool calling performance:

```bash
# Stop current vLLM server (Ctrl+C)

# Update configuration
export MODEL_NAME="zai-org/GLM-4.7-FP8"
export SERVED_MODEL_NAME="glm-4.7"
export TOOL_CALL_PARSER="glm47"
export REASONING_PARSER="glm45"
export TENSOR_PARALLEL_SIZE="4"  # or "2" for H200

# Upgrade vLLM to nightly (required for GLM-4.7)
pip install -U vllm --pre

# Restart vLLM
./scripts/start-vllm.sh
```

## Project Structure

```
runpod-clawdbot/
├── templates/
│   └── clawdbot-vllm.json    # RunPod template configurations (all tiers)
├── scripts/
│   ├── start-vllm.sh         # vLLM startup script
│   └── setup-clawdbot.sh     # Clawdbot installation script
├── config/
│   ├── clawdbot.json         # Main config template
│   ├── clawdbot-tier1.json   # Qwen3-30B-A3B config
│   ├── clawdbot-tier2.json   # MiMo-V2-Flash config
│   └── clawdbot-tier3.json   # GLM-4.7 config
├── tests/
│   ├── test-vllm.sh          # vLLM server tests
│   └── test-tool-calling.sh  # Tool calling tests
├── docker-compose.yml        # Local development setup
├── .env.example              # Environment variables template
└── README.md                 # This file
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `VLLM_API_KEY` | `changeme` | API key for vLLM authentication |
| `MODEL_NAME` | `Qwen/Qwen3-30B-A3B-Instruct` | HuggingFace model ID |
| `SERVED_MODEL_NAME` | `qwen3-30b-a3b` | Model name in API responses |
| `MAX_MODEL_LEN` | `32768` | Maximum context length |
| `TENSOR_PARALLEL_SIZE` | `auto` | Number of GPUs for tensor parallelism |
| `TOOL_CALL_PARSER` | `hermes` | Parser for tool/function calling |
| `REASONING_PARSER` | `` | Reasoning parser (GLM-4.7 only) |
| `HF_HOME` | `/workspace/huggingface` | HuggingFace cache directory |

### Clawdbot Configuration

Edit `~/.clawdbot/clawdbot.json` to point to your vLLM endpoint:

```json
{
  "models": {
    "providers": {
      "runpod-vllm": {
        "baseUrl": "https://<POD_ID>-8000.proxy.runpod.net/v1",
        "apiKey": "your-vllm-api-key",
        "api": "openai-completions"
      }
    }
  }
}
```

## Hardware Requirements

### Tier 1: Qwen3-30B-A3B (~$2/hr)
- **GPU**: 1x H100 80GB or 1x H200
- **VRAM**: ~45GB (3B active parameters)
- **Best for**: Validation, cost-conscious usage

### Tier 2: MiMo-V2-Flash (~$4/hr)
- **GPU**: 2x H100 80GB or 1x H200
- **VRAM**: ~80GB total
- **Best for**: Fast inference (150 tok/s)

### Tier 3: GLM-4.7-FP8 (~$7-8/hr)
- **GPU**: 4x H100 80GB or 2x H200
- **VRAM**: ~150GB total
- **Best for**: SOTA tool calling, agentic workflows

## Testing

### Basic vLLM Tests

```bash
# Health check
curl http://localhost:8000/health

# List models
curl http://localhost:8000/v1/models \
  -H "Authorization: Bearer $VLLM_API_KEY"

# Chat completion
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $VLLM_API_KEY" \
  -d '{
    "model": "qwen3-30b-a3b",
    "messages": [{"role": "user", "content": "Hello!"}],
    "max_tokens": 50
  }'
```

### Run Full Test Suite

```bash
./tests/test-vllm.sh
./tests/test-tool-calling.sh
```

## Local Development

For local testing with Docker (requires NVIDIA GPU):

```bash
# Copy environment file
cp .env.example .env
# Edit .env with your values

# Start vLLM server
docker-compose up vllm

# Run tests
docker-compose --profile test up tests
```

## Model Comparison Details

### Qwen3-30B-A3B-Instruct
- **Architecture**: MoE (30B total, 3B active)
- **Context**: 32K tokens
- **SWE-bench Verified**: 69.6%
- **Tool Parser**: `hermes`
- **Pros**: Fast, efficient, great value
- **Cons**: Smaller active params

### MiMo-V2-Flash
- **Architecture**: MoE (309B total, 15B active)
- **Context**: 256K tokens
- **SWE-bench Verified**: 73.4%
- **Speed**: 150 tokens/second (fastest)
- **License**: MIT
- **Pros**: Speed + quality balance
- **Cons**: Requires 2 GPUs

### GLM-4.7-FP8
- **Architecture**: MoE (358B total, 32B active)
- **Context**: 200K tokens
- **SWE-bench Verified**: 73.8%
- **τ²-Bench**: 84.7% (SOTA)
- **Tool Parser**: `glm47`
- **Innovation**: Interleaved thinking
- **Pros**: Best tool calling, preserved reasoning
- **Cons**: Requires 4 GPUs, vLLM nightly

## Troubleshooting

### vLLM doesn't start
1. Check GPU availability: `nvidia-smi`
2. Verify VRAM is sufficient
3. Check HuggingFace cache: `du -sh $HF_HOME`
4. Review vLLM logs for OOM errors

### Tool calling not working
1. Verify `--enable-auto-tool-choice` is set
2. Check tool parser matches model (e.g., `glm47` for GLM-4.7)
3. Run `./tests/test-tool-calling.sh` for diagnostics

### Model loading is slow
- First load downloads 30-100GB from HuggingFace
- Use network volume to persist cache across pod restarts
- Consider pre-downloading to RunPod volume

### Clawdbot can't connect
1. Verify vLLM is running: `curl http://localhost:8000/health`
2. Check firewall allows port 8000
3. Verify Pod ID in config matches RunPod URL
4. Test with curl before Clawdbot

## Cost Optimization

1. **Use Tier 1 for development** - $2/hr vs $8/hr
2. **Stop pods when not in use** - RunPod charges per minute
3. **Use network volumes** - Avoid re-downloading models
4. **Consider spot instances** - Up to 80% cheaper

## License

MIT

## Resources

- [Clawdbot Documentation](https://github.com/clawdbot/clawdbot)
- [vLLM Documentation](https://docs.vllm.ai/)
- [RunPod Documentation](https://docs.runpod.io/)
- [GLM-4.7 Announcement](https://z.ai/blog/glm-4.7)
- [MiMo-V2-Flash GitHub](https://github.com/XiaomiMiMo/MiMo-V2-Flash)
