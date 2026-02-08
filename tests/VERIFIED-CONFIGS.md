# Verified GPU Configurations

Tested configurations for the unified OpenClaw2Go image. Each entry records the GPU, config, and verification results.

## Test Procedure

1. Create pod with target GPU and unified image
2. Set `OPENCLAW_CONFIG` env var to the test config
3. Verify services start:
   - LLM: `curl http://localhost:8000/health` + `curl http://localhost:8000/v1/models`
   - Audio: `openclaw-tts "Hello" --output /tmp/test.wav` (if audio enabled)
   - Image: `openclaw-image-gen --prompt "test" --width 512 --height 512 --output /tmp/test.png` (if image enabled)
4. Check VRAM usage: `nvidia-smi`

## Status Legend

- **PENDING** — not yet tested
- **PASS** — all services started and verified
- **FAIL** — one or more services failed (see notes)
- **SKIP** — skipped (not applicable or not available)

## Configurations

### RTX 5090 (32GB, Blackwell sm_120)

| Config | Services | Context | VRAM Used | Status | Date | Notes |
|--------|----------|---------|-----------|--------|------|-------|
| `{"llm":true,"audio":true,"image":true}` | LLM+Audio+Image | 150k | 30331 / 32607 MiB | **PASS** | 2026-02-08 | Full stack, ~2.3GB free |
| `{"llm":true,"audio":true}` | LLM+Audio | auto (~200k) | ~26 GB | PENDING | — | More context, no image |
| `{"llm":true}` | LLM only | auto (~200k) | ~22 GB | PENDING | — | Maximum context |

### RTX 4090 (24GB, Ada Lovelace sm_89)

| Config | Services | Context | VRAM Used | Status | Date | Notes |
|--------|----------|---------|-----------|--------|------|-------|
| `{}` (auto-detect) | LLM+Audio | 16.6k | 20489 / 24564 MiB | **PASS** | 2026-02-08 | Auto dropped image, ~4GB free |
| `{"llm":true,"audio":true}` | LLM+Audio | auto | — | PENDING | — | Should match auto-detect |
| `{"llm":true}` | LLM only | auto | — | PENDING | — | More context available |

### L40 (48GB, Ada Lovelace sm_89)

| Config | Services | Context | VRAM Used | Status | Date | Notes |
|--------|----------|---------|-----------|--------|------|-------|
| `{"llm":true,"audio":true,"image":true}` | LLM+Audio+Image | 150k | 30927 / 46068 MiB | **PASS** | 2026-02-08 | ~15GB free, plenty of headroom |

### A100 80GB (sm_80, Ampere)

| Config | Services | Context | VRAM Used | Status | Date | Notes |
|--------|----------|---------|-----------|--------|------|-------|
| `{"llm":true,"audio":true,"image":true}` | LLM+Audio+Image | auto (~150k) | ~30 GB | PENDING | — | Needs sm_80 in engines build |

### H100 80GB (sm_90, Hopper)

| Config | Services | Context | VRAM Used | Status | Date | Notes |
|--------|----------|---------|-----------|--------|------|-------|
| `{"llm":true,"audio":true,"image":true}` | LLM+Audio+Image | auto (~150k) | ~30 GB | PENDING | — | Needs sm_90 in engines build |

## Docker Image

- **Image**: `runpod/openclaw2go:<tag>`
- **Engines**: `runpod/openclaw2go-engines:<tag>`
- **Dockerfile**: `Dockerfile.unified` (runtime), `engines/Dockerfile` (llama.cpp builds)
- **CUDA Architectures**: sm_89 (RTX 4090/L40), sm_120 (RTX 5090) — add more as tested
