# GLM-4.7-Flash GGUF on RTX 5090 (llama.cpp)

**Working solution for running GLM-4.7-Flash on RTX 5090 Blackwell GPUs.**

## Why llama.cpp?

vLLM with NVFP4 quantization has unresolved bugs with GLM-4.7's MLA (Multi-Latent Attention) architecture on Blackwell GPUs. See [NVFP4_VLLM_ISSUES.md](./NVFP4_VLLM_ISSUES.md) for details.

llama.cpp has native support for `Glm4MoeLite` architecture (PR #18936 merged Jan 2026).

## Specifications

| Spec | Value |
|------|-------|
| Model | unsloth/GLM-4.7-Flash-GGUF (Q4_K_M) |
| Model Size | ~17GB |
| VRAM (total) | ~28GB |
| Context Window | **200,000 tokens** |
| GPU | RTX 5090 (32GB, Blackwell SM120) |
| Inference Speed | ~175 tokens/sec |

## Key Features

- **200k context** - Full model capacity on 32GB GPU
- **Q8 KV cache quantization** - Fits 200k context in VRAM
- **OpenAI-compatible API** - Works with Clawdbot, Claude Code, etc.
- **Native chat template** - Uses `--jinja` for correct GLM-4.7 formatting

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `MODEL_FILE` | `GLM-4.7-Flash-Q4_K_M.gguf` | GGUF file to use |
| `MAX_MODEL_LEN` | `200000` | Context length |
| `LLAMA_API_KEY` | `changeme` | API authentication |
| `CLAWDBOT_WEB_PASSWORD` | `clawdbot` | Web UI password |
| `TELEGRAM_BOT_TOKEN` | - | Optional Telegram integration |
| `GITHUB_TOKEN` | - | Optional GitHub CLI auth |

## Build & Run

```bash
# Build
docker build -t clawdbot-glm47-gguf-llamacpp .

# Run on RTX 5090
docker run --gpus all -p 8000:8000 -p 18789:18789 \
  -v /path/to/workspace:/workspace \
  -e LLAMA_API_KEY=your-key \
  clawdbot-glm47-gguf-llamacpp
```

## API Usage

```bash
# Health check
curl http://localhost:8000/health

# Chat completion (OpenAI-compatible)
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your-key" \
  -d '{
    "model": "glm-4.7-flash",
    "messages": [{"role": "user", "content": "Hello!"}],
    "max_tokens": 100
  }'
```

## Alternative Quantizations

You can use different GGUF quantizations by changing `MODEL_FILE`:

| Quantization | Size | Quality | VRAM |
|--------------|------|---------|------|
| Q4_K_M | 17GB | Good | ~28GB |
| Q5_K_M | 19GB | Better | ~30GB |
| Q8_0 | 32GB | Best | Won't fit |

## Comparison with vLLM NVFP4

| Feature | llama.cpp GGUF | vLLM NVFP4 |
|---------|---------------|------------|
| Works on RTX 5090 | ✅ Yes | ❌ No (bugs) |
| 200k context | ✅ Yes | ❌ OOM |
| Inference speed | ~175 tok/s | N/A |
| KV cache quant | ✅ Q8 | ❌ FP16 only |
