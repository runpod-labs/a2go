---
"a2go": minor
---

feat: add `--agent` flag with Hermes support

Add required `--agent` CLI flag (`openclaw` or `hermes`) to select agent framework. Integrates Hermes Agent (NousResearch) as a second option alongside OpenClaw with full tool calling, skills (SKILL.md), terminal exec, and memory support. Includes Docker support (amd64 + arm64), site configurator framework selection, and placeholder secret workaround for Hermes compatibility.
