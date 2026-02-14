# openclaw2go-llamacpp Fork Scaffolding

This directory contains templates and workflows for the `runpod-workers/openclaw2go-llamacpp` fork.

## Setup (done)

Fork created at `runpod-workers/openclaw2go-llamacpp`. Branch `main` has all cherry-picks applied.

Cherry-picked PRs on `main`:
- PR #18641 (liquid-audio: TTS/STT for LFM2.5)
- PR #12794 (OuteTTS 1.0 native TTS support)
- PR #18039 (Eagle-3 speculative decoding)

Already merged upstream (no cherry-pick needed):
- PR #19460 (glm-dsa: GLM-5 MoE dynamic sparse attention)

## Tag Convention

`{upstream-tag}-openclaw.{patch}` (e.g., `b4567-openclaw.1`)

## Maintenance

- The CI workflow checks daily for new upstream releases
- Clean rebases auto-create tags and update main
- Conflicting rebases create a PR for manual resolution
- If a PR gets merged upstream, drop the cherry-pick (less maintenance)
- If a cherry-pick can't be resolved: fall back to separate engine for that feature
