# NVFP4 + vLLM Issues on RTX 5090 (Blackwell SM120)

This document tracks the issues encountered trying to run `GadflyII/GLM-4.7-Flash-NVFP4` with vLLM on RTX 5090.

**Status**: NOT WORKING as of Jan 2026
**Workaround**: Use llama.cpp with GGUF (see main README)

---

## Issue 1: `e_score_correction_bias` Not Recognized

**Error:**
```
ValueError: There is no module or parameter named 'model.layers.11.mlp.gate.e_score_correction_bias' in TransformersMoEForCausalLM
```

**Cause:** The NVFP4 quantized model has MoE gate parameters that vLLM's TransformersMoEForCausalLM doesn't recognize.

**Related Issues:**
- vLLM GitHub Issue #32109 - Blackwell SM120 FP8 MoE path failing
- vLLM PR #32237 (closed/incomplete)

**Fix Applied:**
Patched `/usr/local/lib/python3.12/dist-packages/vllm/model_executor/models/transformers/base.py` line 154:
```python
# Before:
self.ignore_unexpected_suffixes: list[str] = []

# After:
self.ignore_unexpected_suffixes: list[str] = ["e_score_correction_bias"]
```

**Result:** Fixed this specific error, but exposed more issues.

---

## Issue 2: Extra Layer 47 Weights

**Error:**
```
ValueError: There is no module or parameter named 'model.layers.47.embed_tokens' in TransformersMoEForCausalLM
```

**Cause:** The NVFP4 model has extra weights in layer 47 that don't exist in the standard Glm4MoeLiteForCausalLM:
- `model.layers.47.embed_tokens`
- `model.layers.47.eh_proj`
- `model.layers.47.enorm`
- `model.layers.47.hnorm`
- `model.layers.47.shared_head`

**Fix Applied:**
Added these to `ignore_unexpected_prefixes` in base.py:
```python
self.ignore_unexpected_prefixes: list[str] = [
    "model.layers.47.embed_tokens",
    "model.layers.47.eh_proj",
    "model.layers.47.enorm",
    "model.layers.47.hnorm",
    "model.layers.47.shared_head"
]
```

**Result:** Weights load successfully (100%), but runtime error appears.

---

## Issue 3: Layer Count Mismatch

**Error:**
```
ValueError: There is no module or parameter named 'model.layers.47' in TransformersMoEForCausalLM
```

**Cause:** Model weights have 48 layers (indices 0-47) but `config.json` said `num_hidden_layers: 47`.

**Fix Applied:**
```bash
sed -i 's/"num_hidden_layers": 47/"num_hidden_layers": 48/' config.json
```

**Result:** Fixed loading, but exposed the main issue.

---

## Issue 4: Attention Output Dimension Mismatch (BLOCKING)

**Error:**
```
RuntimeError: mat1 and mat2 shapes cannot be multiplied (8192x1280 and 5120x2048)
```

**Location:** `self.o_proj(attn_output)` in attention forward pass

**Analysis:**
- Expected attention output: `(batch, seq, 5120)` (20 heads × 256 v_head_dim)
- Actual attention output: `(batch, seq, 1280)` (5 heads × 256 v_head_dim)
- Only 5 heads worth of attention output instead of 20

**Root Cause:**
vLLM's `TransformersMoEForCausalLM` fallback doesn't correctly handle GLM-4.7's MLA (Multi-Latent Attention) architecture. The attention computation produces wrong dimensions.

**Attempts that didn't work:**
1. `enforce_eager=True` - Same error
2. `VLLM_ATTENTION_BACKEND=TORCH_SDPA` - Same error
3. `VLLM_USE_V1=0` (v0 engine) - Same error

**Status:** UNRESOLVED - Requires vLLM to add native Glm4MoeLite support

---

## Issue 5: SGLang cuDNN Error

Tried SGLang as alternative to vLLM.

**Error:**
```
cudnnGraphNotSupportedError: [cudnn_frontend] Error: No execution plans support the graph.
```

**Cause:** cuDNN doesn't support NVFP4 GEMM operations on Blackwell SM120 architecture yet.

**Status:** UNRESOLVED - Requires NVIDIA cuDNN update

---

## Environment Details

```
GPU: NVIDIA GeForce RTX 5090 (Blackwell, SM120, 32GB)
CUDA: 12.8
vLLM: 0.14.0 (nightly from wheels.vllm.ai)
Transformers: 5.0.0.dev0 (from git main)
Model: GadflyII/GLM-4.7-Flash-NVFP4
Quantization: compressed-tensors NVFP4
```

---

## Files Modified During Debugging

1. `/usr/local/lib/python3.12/dist-packages/vllm/model_executor/models/transformers/base.py`
   - Added `e_score_correction_bias` to ignore_unexpected_suffixes
   - Added layer 47 prefixes to ignore_unexpected_prefixes

2. `/workspace/models/GLM-4.7-Flash-NVFP4/config.json`
   - Changed `num_hidden_layers` from 47 to 48

3. `/tmp/sglang/python/sglang/srt/configs/utils.py` (SGLang attempt)
   - Fixed `AutoImageProcessor.register()` signature for transformers 5.0

---

## Recommended Solution

Use **llama.cpp with GGUF** instead:
- Native Glm4MoeLite support (PR #18936)
- Q8 KV cache quantization for 200k context
- Works on RTX 5090 out of the box

See main README.md for setup instructions.

---

## Future: When to Retry vLLM

Check these before retrying:
1. vLLM has native `Glm4MoeLiteForCausalLM` support (not TransformersMoE fallback)
2. vLLM Issue #32109 is resolved
3. NVIDIA releases cuDNN update with Blackwell FP4 support
