# OpenClaw Migration Plan (Runpod Images)

## Background & upstream signals

From the upstream OpenClaw project:
- The repository is now `openclaw/openclaw`, and the CLI shown in the README is `openclaw`.
- Install guidance includes `npm install -g openclaw@latest` and the one‑liner `curl -fsSL https://openclaw.ai/install.sh | bash`.
- The OpenClaw README documents new default paths:
  - Config file: `~/.openclaw/openclaw.json`
  - Workspace root: `~/.openclaw/workspace`

Sources:
- https://github.com/openclaw/openclaw (README)
- https://openclaw.ai (installer + quick start)

## Repo scan findings (current state)

The repo still referenced legacy names and paths in many places before migration:
- Dockerfiles: base image installs, labels, ENVs, entrypoint banners
- Entrypoints: legacy CLI names and legacy state dir paths
- Docs: `README.md`, model READMEs, `docs/video-script.md`
- Templates: `templates/runpod-template.json`, `templates/openclaw-vllm.json`
- Config: `config/openclaw.json`, `config/workspace/IDENTITY.md`
- Scripts: `scripts/entrypoint.sh`, `scripts/setup-openclaw.sh`
- Env examples: `.env.example`

No `OpenClaw` references exist yet in the repo.

## Decisions (no legacy)

1. **Package + binary naming**
   - Install `openclaw@latest`.
   - Use `openclaw` CLI only (no legacy binaries or symlinks).

2. **State directory**
   - Use `/workspace/.openclaw` as the only state directory in containers.

3. **Config file name**
   - Use `openclaw.json` only.

## Migration plan (proposed steps)

### 1) Dependency + CLI alignment
- Update Dockerfiles to install `openclaw@latest`.
- Use `openclaw` as the only CLI.

### 2) State dir and workspace setup
- Use `/workspace/.openclaw` for all state.
- Create expected subdirectories (`agents/main/sessions`, `credentials`) and enforce permissions.

### 3) Config generation + naming
- Generate `openclaw.json` with OpenAI‑compatible provider settings for the local model.
- Run `openclaw doctor --fix` to auto‑migrate schema after config write.

### 4) Rename commands and docs
- Update all scripts/entrypoints to call `openclaw`.
- Replace docs and templates to use “OpenClaw” branding and new paths.
- Update README tables and sample image tags if the Docker repo/name changes.

### 5) Environment variables and config keys
- Standardize on `OPENCLAW_STATE_DIR`, `OPENCLAW_WORKSPACE`, `OPENCLAW_WEB_PASSWORD`.
- Reflect in `.env.example` and Runpod templates.

### 6) Validation
- Build images for each model variant.
- Smoke test:
  - `openclaw doctor --fix` works
  - `openclaw gateway` starts
- Web UI reachable via Runpod proxy
  - Model inference via `/v1/chat/completions`
- Confirm the state dir and workspace are created under `/workspace/.openclaw`.

## Open questions

- Should image tags be renamed immediately or keep existing tags for continuity?
