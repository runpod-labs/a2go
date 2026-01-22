# NVFP4 + vLLM Issues on RTX 5090 (Blackwell SM120)

**Status**: NOT WORKING as of Jan 2026
**Workaround**: Use [glm47-flash-gguf-llamacpp](../glm47-flash-gguf-llamacpp/) with llama.cpp

---

## Summary

Attempting to run `GadflyII/GLM-4.7-Flash-NVFP4` with vLLM 0.14.0 on RTX 5090 fails due to multiple issues with the GLM-4.7 MLA (Multi-Latent Attention) architecture not being properly supported by vLLM's TransformersMoE fallback.

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

**Status**: UNRESOLVED - requires native Glm4MoeLite support in vLLM

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
vLLM: 0.14.0 (nightly)
Transformers: 5.0.0.dev0
Model: GadflyII/GLM-4.7-Flash-NVFP4
```

## When to Retry

Check these before retrying:
1. vLLM has native `Glm4MoeLiteForCausalLM` (not TransformersMoE fallback)
2. vLLM Issue #32109 resolved
3. NVIDIA cuDNN Blackwell FP4 support

## Working Alternative

Use **llama.cpp with GGUF**: [glm47-flash-gguf-llamacpp](../glm47-flash-gguf-llamacpp/)
- 200k context working
- ~175 tokens/sec on RTX 5090
- Q8 KV cache quantization
