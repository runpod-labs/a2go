---
"a2go": minor
---

feat: show parameter size on image and audio model cards

- Display parameter count (e.g., 4B, 1.5B) as a pill in the specs table for image and audio models
- Strip size from display name so card titles read cleanly (e.g., "FLUX.2 Klein" instead of "FLUX.2 Klein 4B")
- Group Qwen3-TTS 0.6B and 1.7B into one family entry with switchable size pills, matching LLM behavior
