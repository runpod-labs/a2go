# AGENTS.md

High-level guide for AI agents and new developers.

## What This Is

OpenClaw on RunPod: Docker images that run an AI coding assistant (OpenClaw) with GLM-4.7 LLM on various GPUs.

## Architecture

```
┌─────────────────────────────────────────────────┐
│                  RunPod Pod                      │
│  ┌───────────────┐    ┌───────────────────────┐ │
│  │  llama.cpp /  │    │      OpenClaw         │ │
│  │    vLLM       │◄──►│   (AI Assistant)      │ │
│  │   :8000       │    │      :18789           │ │
│  └───────────────┘    └───────────────────────┘ │
│           ▲                                      │
│           │ GPU (GLM-4.7 model)                 │
└─────────────────────────────────────────────────┘
```

## Model Variants

| Folder | GPU Target | Inference |
|--------|------------|-----------|
| `glm47-flash-gguf-llamacpp/` | RTX 5090 | llama.cpp |
| `glm47-flash-awq-4bit/` | A100 80GB | vLLM |
| `glm47-flash-fp16/` | H100/A100 | vLLM |
| `glm47-flash-nvfp4-5090/` | RTX 5090 | vLLM |
| `glm47-reap-w4a16/` | B200 | vLLM |

## Key Folders

- `models/` — Dockerfiles per GPU variant
- `scripts/` — Entrypoints, startup logic
- `skills/` — Agent capabilities (image gen, etc.)
- `config/workspace/` — Files copied into container for OpenClaw

## Skills

### Image Generation
```bash
openclaw-image-gen --prompt "a robot" --width 1024 --height 1024 --output /workspace/openclaw/images/out.png
```
Uses FLUX.2 Klein SDNQ (4-bit). Requires PyTorch cu128 for RTX 5090.

## Quick Commands

```bash
# Build
docker build -f models/glm47-flash-gguf-llamacpp/Dockerfile -t openclaw-gguf .

# SSH into running pod
ssh -i ~/.ssh/id_runpod root@<ip> -p <port>

# Test on pod
curl http://localhost:8000/health
openclaw-image-gen --prompt "test" --width 512 --height 512 --output /tmp/test.png
```

## Current Focus

- RTX 5090 (Blackwell sm_120) support
- Image generation with FLUX.2 Klein SDNQ
- PyTorch cu128 required for Blackwell GPUs
