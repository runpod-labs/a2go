# NVFP4 + vLLM Issues on RTX 5090 (Blackwell SM120)

**Status**: NOT WORKING as of Jan 2026
**Workaround**: Use [glm47-flash-gguf-llamacpp](../glm47-flash-gguf-llamacpp/) with llama.cpp

---

## Summary

Attempting to run `GadflyII/GLM-4.7-Flash-NVFP4` with vLLM on RTX 5090 fails due to multiple issues with the GLM-4.7 MLA (Multi-Latent Attention) architecture and SM120 kernel support.

## Upstream status (as of 2026-01-29)

- vLLM Issue #32109 is **closed** and was closed by PR #33285.
- PR #33285 **restricts** FP8 MoE CUTLASS backend to SM90/SM100 (does not add SM120 MoE support).
- PR #32237 (SM120 FP8 MoE support) was **closed and not merged**.
- vLLM now includes `Glm4MoeLiteForCausalLM` support, but NVFP4 on SM120 is still unverified.

Net: there is no confirmed upstream fix for NVFP4 + GLM-4.7 on RTX 5090 yet.

## Issues Encountered

### 1. `e_score_correction_bias` Not Recognized

```
ValueError: There is no module or parameter named 'model.layers.11.mlp.gate.e_score_correction_bias' in TransformersMoEForCausalLM
```

**Fix**: Added to `ignore_unexpected_suffixes` in vLLM's `base.py`

**Related**: vLLM Issue #32109, PR #32237

### 2. Extra Layer 47 Weights

```
ValueError: There is no module or parameter named 'model.layers.47.embed_tokens' in TransformersMoEForCausalLM
```

Extra weights not in standard architecture:
- `model.layers.47.embed_tokens`
- `model.layers.47.eh_proj`
- `model.layers.47.enorm`
- `model.layers.47.hnorm`
- `model.layers.47.shared_head`

**Fix**: Added to `ignore_unexpected_prefixes`

### 3. Config Layer Count Mismatch

Model weights have 48 layers but config says 47.

**Fix**: `sed -i 's/"num_hidden_layers": 47/"num_hidden_layers": 48/' config.json`

### 4. Attention Dimension Mismatch (BLOCKING)

```
RuntimeError: mat1 and mat2 shapes cannot be multiplied (8192x1280 and 5120x2048)
```

Expected: 20 heads × 256 = 5120
Actual: 5 heads × 256 = 1280

vLLM's attention produces wrong output dimensions for GLM-4.7's MLA architecture.

**Status**: UNRESOLVED - still reproduced on SM120

### 5. SGLang cuDNN Error

```
cudnnGraphNotSupportedError: [cudnn_frontend] Error: No execution plans support the graph.
```

cuDNN doesn't support NVFP4 GEMM on Blackwell SM120.

**Status**: UNRESOLVED - requires NVIDIA cuDNN update

## Environment

```
GPU: RTX 5090 (Blackwell SM120, 32GB)
CUDA: 12.8
vLLM: 0.14.x (nightly at the time)
Transformers: 5.0.0.dev0
Model: GadflyII/GLM-4.7-Flash-NVFP4
```

## When to Retry

Check these before retrying:
1. vLLM has native `Glm4MoeLiteForCausalLM` path for GLM-4.7 in production builds
2. SM120 FP8 MoE kernels are supported (not just gated off)
3. NVIDIA cuDNN Blackwell FP4 support is available

## Known working nightly tag (from upstream reports)

Community reports in vLLM Issue #32109 mention the following as working at the time:
- `docker.io/vllm/vllm-openai:nightly-0d4044edd85de30d7d4558aeea4d1e95c7c556d6`

Reported commit window:
- last working: `ffc0a2798b118f7ceb21645df59d2bfdfc461d42`
- first broken: `5dcd7ef1f219068e6b6be5b614bc43978f028651`

These are historical references for retesting.

## Verification plan (recommended)

1. Baseline: run the known working nightly image above with NVFP4 and confirm it still starts.
2. Candidate: run the latest vLLM release or nightly (v0.15.x) with the same config.
3. Compare logs for MLA mismatch or SM120 kernel selection errors.
4. Record results here and update status.

## Runpod test checklist (NVFP4, no custom image)

Goal: validate NVFP4 on RTX 5090 using official vLLM images (no custom build).

### 1) Create a pod
- GPU: RTX 5090 32GB
- Volume: 100GB+ mounted at `/workspace`
- Ports: `8000/http`, `22/tcp`
- Image: use one of the two images below:
  - Baseline (reported working): `vllm/vllm-openai:nightly-0d4044edd85de30d7d4558aeea4d1e95c7c556d6`
  - Candidate (latest): `vllm/vllm-openai:latest`

### 2) Environment variables
- `HF_TOKEN` (optional but recommended)
- `VLLM_API_KEY` (required)
- `MODEL_NAME=GadflyII/GLM-4.7-Flash-NVFP4`
- `SERVED_MODEL_NAME=glm-4.7-flash`
- `MAX_MODEL_LEN=200000`
- `TOOL_CALL_PARSER=glm47`
- `REASONING_PARSER=glm45`
- `GPU_MEMORY_UTILIZATION=0.95`
- `HF_HOME=/workspace/huggingface`

### 3) Start command
Use the same command for both baseline and candidate images:
```
vllm serve ${MODEL_NAME} \
  --host 0.0.0.0 \
  --port 8000 \
  --max-model-len ${MAX_MODEL_LEN} \
  --gpu-memory-utilization ${GPU_MEMORY_UTILIZATION} \
  --served-model-name ${SERVED_MODEL_NAME} \
  --api-key ${VLLM_API_KEY} \
  --enable-auto-tool-choice \
  --tool-call-parser ${TOOL_CALL_PARSER} \
  --reasoning-parser ${REASONING_PARSER}
```

### 4) Health check
```
curl http://localhost:8000/health
```

### 5) Minimal chat test
```
curl http://localhost:8000/v1/chat/completions \
  -H "Authorization: Bearer ${VLLM_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "glm-4.7-flash",
    "messages": [{"role": "user", "content": "Hello!"}],
    "max_tokens": 64
  }'
```

### 6) Log triage (what to watch for)
- `No compiled cutlass_scaled_mm for CUDA device capability: 120`
- `mat1 and mat2 shapes cannot be multiplied` (MLA mismatch)
- CUDA graph or cuDNN errors on SM120

### 7) Record results
- Image tag used
- vLLM version reported in logs
- Pass/fail and error signatures

## Working Alternative

Use **llama.cpp with GGUF**: [glm47-flash-gguf-llamacpp](../glm47-flash-gguf-llamacpp/)
- 200k context working
- ~175 tokens/sec on RTX 5090
- Q8 KV cache quantization
