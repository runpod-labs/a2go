---
name: a2go
description: Use open weight models (LLM, image, audio) with open source agents on Mac, Linux, and Windows.
metadata:
  author: runpod
---

# a2go

Run open weight models with open source agents. Browse models: https://a2go.run

## CLI

```bash
a2go doctor                                              # One-time setup
a2go run --agent <agent> --llm <repo>:<bits>bit [--engine <engine>] [--audio <repo>:<bits>bit]
a2go models [--type llm] [--engine wandler] [--os mac] [--max-vram 24]
a2go status / a2go stop
```

Agents: `hermes` or `openclaw`. Engines: `llamacpp` (default linux), `mlx` (default mac), `wandler` (onnx, all platforms).

## Docker

Image: `runpod/a2go:latest`. Configure via `A2GO_CONFIG` env var:

```json
{"agent":"openclaw", "engine":"wandler", "llm":"onnx-community/gemma-4-E4B-it-ONNX:4bit"}
```

Fields: `agent` (required), `engine` (llamacpp/mlx/wandler), `llm`, `audio`, `image`, `contextLength`. Also set `A2GO_AUTH_TOKEN` and `A2GO_API_KEY`.

## Ports

- **8000** — LLM API (`/v1/chat/completions`)
- **8080** — Web UI + media server
- **8642** — Hermes gateway
- **18789** — OpenClaw gateway
