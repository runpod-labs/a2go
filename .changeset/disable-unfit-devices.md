---
"a2go": patch
---

feat(site): disable device buttons that can't fit selected model's vram

Devices whose VRAM (× device count) is insufficient for the current
config are now dimmed and non-clickable in the configurator.
