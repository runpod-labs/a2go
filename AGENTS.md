# AGENTS.md

OpenClaw2Go on Runpod: self-contained Docker images with LLM + media services for GPU pods.

## Architecture

### Unified Image (primary)

One Docker image works on all GPUs (A100/H100/B200/RTX 5090). Configuration at runtime via `OPENCLAW_CONFIG` env var.

**Core abstraction: models + GPU VRAM = what fits.** The system detects GPU VRAM, computes which models fit, and auto-adjusts context length. Users pick models, not infrastructure.

```
OPENCLAW_CONFIG examples:
  {"llm": true, "audio": true, "image": true}         — all default models
  {"llm": true, "audio": true}                         — LLM + audio only (more VRAM for context)
  {"llm": "glm47-flash-gguf", "contextLength": 200000} — specific model + context override
  {"profile": "rtx5090-full-stack"}                    — use a preset (optional shorthand)
  {}                                                    — auto-detect GPU, use all defaults that fit
```

### Registry (`registry/`)

JSON-based configuration registry. Models declare their VRAM cost; the system computes fit at runtime.

```
registry/
├── engines.json                    # Engine definitions (llamacpp, llamacpp-audio, image-gen)
├── models/                         # Model specs (VRAM, repo, start args)
│   ├── glm47-flash-gguf.json       # LLM: GLM-4.7-Flash Q4_K_M (default: true)
│   ├── lfm25-audio.json            # Audio: LFM2.5-Audio-1.5B (default: true)
│   └── flux2-klein-sdnq.json       # Image: FLUX.2 Klein 4B SDNQ (default: true)
├── gpus/                           # GPU specs (VRAM, arch, CUDA requirements)
│   ├── rtx-5090.json               # 32GB, SM120, Blackwell
│   ├── a100-80gb.json              # 80GB, SM80, Ampere
│   ├── h100-80gb.json              # 80GB, SM90, Hopper
│   └── b200-180gb.json             # 180GB, SM100, Blackwell
└── profiles/                       # Optional presets (convenience shortcuts)
    ├── rtx5090-full-stack.json     # LLM + Audio + Image with tuned gpuLayers
    ├── rtx5090-llm-audio.json      # LLM + Audio only
    └── rtx5090-llm-only.json       # LLM only
```

Each model has `"default": true` marking it as the recommended/most-capable choice for its type.

### Engine Isolation

LLM and Audio use separate llama.cpp builds with incompatible shared libraries. They are isolated via `LD_LIBRARY_PATH`:

```
/opt/engines/
├── llamacpp-llm/       # LLM: main branch llama.cpp
│   ├── bin/llama-server
│   └── lib/*.so
├── llamacpp-audio/     # Audio: PR #18641 branch
│   ├── bin/llama-liquid-audio-server
│   └── lib/*.so
└── image-gen/          # Image: Python venv (torch cu128 + diffusers + sdnq)
    └── venv/
```

### Resolution Flow

1. Parse `OPENCLAW_CONFIG` env var (JSON)
2. `resolve-profile.py` → detect GPU via `nvidia-smi`, resolve models, compute VRAM fit + context length
3. Entrypoint downloads models, starts services with correct engine/env/args
4. Web proxy + OpenClaw gateway start

## Codebase Structure

```
openclaw2go/
├── Dockerfile.unified              # Unified multi-stage build (primary)
├── registry/                       # Configuration registry (models, GPUs, presets)
├── models/                         # Legacy per-GPU Dockerfiles
│   ├── glm47-flash-gguf-llamacpp/  # RTX 5090 - llama.cpp (legacy)
│   ├── glm47-flash-awq-4bit/       # A100 80GB - vLLM (disabled)
│   ├── glm47-flash-fp16/           # H100/A100 - vLLM (disabled)
│   ├── glm47-flash-nvfp4-5090/     # RTX 5090 - vLLM (disabled)
│   └── glm47-reap-w4a16/           # B200 - vLLM (disabled)
├── scripts/
│   ├── entrypoint-unified.sh       # Unified entrypoint (primary)
│   ├── entrypoint-common.sh        # Shared helpers (SSH, auth, skills)
│   ├── resolve-profile.py          # Config resolution + GPU detection + VRAM budget
│   ├── vram-budget.py              # Standalone VRAM budget calculator
│   ├── openclaw-profiles            # CLI: list models, check fit, manage presets
│   ├── openclaw-image-gen           # Image generation CLI
│   ├── openclaw-image-server        # FLUX.2 persistent server
│   ├── openclaw-tts                 # Text-to-speech CLI
│   ├── openclaw-stt                 # Speech-to-text CLI
│   └── openclaw-web-proxy           # Reverse proxy + media UI
├── skills/                          # Agent capabilities
│   └── image-gen/                   # FLUX.2 image generation
├── config/
│   ├── openclaw.json                # OpenClaw config template
│   └── workspace/                   # Files copied to /workspace/openclaw/
├── web/                             # Media proxy web UI
├── plugins/                         # OpenClaw plugins
└── tests/                           # Test scripts
```

## Key Decisions

- **Unified image with multi-arch CUDA** — `DCMAKE_CUDA_ARCHITECTURES="80;90;100;120"` for A100/H100/B200/5090
- **Model-centric config** — users pick models, system computes VRAM fit + context length
- **RTX 5090 uses llama.cpp** — vLLM has dimension mismatch bugs with GLM-4.7 MLA attention on NVFP4
- **PyTorch cu128** — required for RTX 5090 Blackwell sm_120, works on all other GPUs too
- **Diffusers from git** — stable release lacks `Flux2KleinPipeline`
- **LLM and Audio binaries MUST be separate** — incompatible .so files. LLM libs in `/opt/engines/llamacpp-llm/lib/`, Audio in `/opt/engines/llamacpp-audio/lib/`. Mixing them breaks LLM server.
- **Persistent servers for low latency** — Audio (8001) and Image (8002) run with models pre-loaded. CLI scripts call via HTTP.

## Build Commands

```bash
# Build unified image (works on all GPUs)
docker build -f Dockerfile.unified -t openclaw2go .

# Run with auto-detection (all defaults)
docker run --gpus all openclaw2go

# Run with specific config
docker run --gpus all -e OPENCLAW_CONFIG='{"llm":true,"audio":true,"image":true}' openclaw2go

# Run LLM only with max context
docker run --gpus all -e OPENCLAW_CONFIG='{"llm":true,"contextLength":200000}' openclaw2go

# Legacy: build per-GPU image
docker build -f models/glm47-flash-gguf-llamacpp/Dockerfile -t openclaw-gguf .
```

## CLI Tools (inside container)

```bash
# List available models
openclaw-profiles models

# Show what fits on this GPU
openclaw-profiles fit

# Simulate fit on a specific VRAM
openclaw-profiles fit --vram 81920

# List preset profiles
openclaw-profiles presets

# VRAM budget calculator
python3 /opt/openclaw/scripts/vram-budget.py --gpu rtx-5090 --models glm47-flash-gguf,lfm25-audio
```

## Testing

```bash
curl http://localhost:8000/health
curl http://localhost:8000/v1/models
./tests/test-tool-calling.sh
openclaw-image-gen --prompt "test" --width 512 --height 512 --output /tmp/test.png
```

## Operational Gotchas

- Control UI requires device pairing; without it, chat stays disconnected and previews won't render.
  Use `OPENCLAW_GATEWAY_TOKEN=<token> openclaw devices list` then
  `OPENCLAW_GATEWAY_TOKEN=<token> openclaw devices approve <request-id>`.
- Image previews need a public proxy URL (port 8080). Runpod may 403 non-browser
  requests; verify with a browser user agent when testing.
- Disable external image skills in `/workspace/.openclaw/openclaw.json` so the model
  never tries GPT/OpenAI image tools. The entrypoint handles this automatically.

## Runpod Pod Access

```bash
ssh -i ~/.ssh/id_runpod root@<ip> -p <port>
nvidia-smi
curl http://localhost:8000/health
curl http://localhost:8000/v1/models
```

## Where to Make Changes

| Task | Location |
|------|----------|
| Add new model | Create JSON in `registry/models/` with VRAM costs + start args |
| Add new GPU | Create JSON in `registry/gpus/` |
| Add preset profile | Create JSON in `registry/profiles/` |
| Change startup logic | `scripts/entrypoint-unified.sh` or `scripts/entrypoint-common.sh` |
| Modify config resolution | `scripts/resolve-profile.py` |
| Add agent skill | Create folder in `skills/` with SKILL.md |
| Modify OpenClaw workspace | `config/workspace/` |
| Update CI/CD | `.github/workflows/docker-build.yml` |

## VRAM Usage (RTX 5090 - 32GB)

| Component | VRAM | Notes |
|-----------|------|-------|
| GLM-4.7 LLM (150k ctx) | ~28 GB | Model ~17.3GB + KV cache ~10GB (q8_0) |
| Audio Server (TTS/STT) | ~2 GB | LFM2.5-Audio-1.5B-Q4_0 |
| Image Server (FLUX.2) | ~4 GB | FLUX.2-klein-4B-SDNQ-4bit-dynamic |
| **All 3 (150k ctx)** | **~29-30 GB** | **~2 GB free** |
| **LLM + Audio (200k ctx)** | **~26 GB** | **~6 GB free** |
| **LLM only (200k ctx)** | **~22 GB** | **~10 GB free** |

Context length is auto-computed by `resolve-profile.py` based on available VRAM after accounting for all selected models.

## Important Notes

- Never start/stop servers in code — user handles that
- Use Runpod MCP tools to manage pods
- Model downloads go to `/workspace/models/` (persisted volume)
- **CRITICAL**: LLM and Audio .so files must stay in separate directories under `/opt/engines/`
