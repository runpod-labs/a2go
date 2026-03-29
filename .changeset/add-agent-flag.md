---
"a2go": minor
---

feat: add `--agent` flag with Hermes support and unified `a2go tool` subcommands

Add required `--agent` CLI flag (`openclaw` or `hermes`) to select agent framework. Integrates Hermes Agent (NousResearch) as a second option alongside OpenClaw with full tool calling, skills (SKILL.md), terminal exec, and memory support.

Replace 3 separate Python scripts (openclaw-image-gen, openclaw-tts, openclaw-stt) with `a2go tool` subcommands (image-generate, text-to-speech, speech-to-text) that go through the unified web proxy on port 8080. Move skills to config/workspace/skills/ and update Docker path to /opt/a2go/skills.
