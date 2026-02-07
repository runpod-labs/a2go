# Verified GPU Configurations

Tested configurations for the unified OpenClaw2Go image. Each entry records the GPU, config, and verification results.

## Test Procedure

1. Create pod with target GPU and unified image
2. Set `OPENCLAW_CONFIG` env var to the test config (strip `_test`/`_gpu`/`_expected` keys)
3. Verify services start:
   - LLM: `curl http://localhost:8000/health` + `curl http://localhost:8000/v1/models`
   - Audio: `curl http://localhost:8001/v1/models` (if audio enabled)
   - Image: `curl http://localhost:8002/health` (if image enabled)
4. Check VRAM usage: `nvidia-smi`
5. Run tool calling test: `./tests/test-tool-calling.sh` (if available)

## Status Legend

- **PENDING** — not yet tested
- **PASS** — all services started and verified
- **FAIL** — one or more services failed (see notes)
- **SKIP** — skipped (not applicable or not available)

## Configurations

### RTX 5090 (32GB, Blackwell sm_120)

| Config | Services | Context | VRAM Used | Status | Date | Notes |
|--------|----------|---------|-----------|--------|------|-------|
| `{"llm":true,"audio":true,"image":true}` | LLM+Audio+Image | auto (~150k) | ~29-30 GB | PENDING | — | Full stack reference |
| `{"llm":true,"audio":true}` | LLM+Audio | auto (~200k) | ~26 GB | PENDING | — | More context, no image |
| `{"llm":true}` | LLM only | auto (~200k) | ~22 GB | PENDING | — | Maximum context |

### RTX 4090 (24GB, Ada Lovelace sm_89)

| Config | Services | Context | VRAM Used | Status | Date | Notes |
|--------|----------|---------|-----------|--------|------|-------|
| `{"llm":true,"audio":true,"image":true}` | LLM+Audio+Image | auto | — | PENDING | — | May not fit, auto-adjusts |
| `{"llm":true,"audio":true}` | LLM+Audio | auto | — | PENDING | — | Should fit with ~100k ctx |
| `{"llm":true}` | LLM only | auto | — | PENDING | — | |

### L40 (48GB, Ada Lovelace sm_89)

| Config | Services | Context | VRAM Used | Status | Date | Notes |
|--------|----------|---------|-----------|--------|------|-------|
| `{"llm":true,"audio":true,"image":true}` | LLM+Audio+Image | auto (~150k) | ~30 GB | PENDING | — | Full stack, plenty of headroom |

### A100 80GB (sm_80, Ampere)

| Config | Services | Context | VRAM Used | Status | Date | Notes |
|--------|----------|---------|-----------|--------|------|-------|
| `{"llm":true,"audio":true,"image":true}` | LLM+Audio+Image | auto (~150k) | ~30 GB | PENDING | — | |

### H100 80GB (sm_90, Hopper)

| Config | Services | Context | VRAM Used | Status | Date | Notes |
|--------|----------|---------|-----------|--------|------|-------|
| `{"llm":true,"audio":true,"image":true}` | LLM+Audio+Image | auto (~150k) | ~30 GB | PENDING | — | |

## Docker Image

- **Image**: `<dockerhub-repo>/openclaw2go:<tag>`
- **Dockerfile**: `Dockerfile.unified`
- **CUDA Architectures**: 89 (RTX 4090/L40), 120 (RTX 5090) — add more as tested
