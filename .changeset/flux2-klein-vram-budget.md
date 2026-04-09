---
"a2go": patch
---

fix: correct flux2 klein vram budget based on measured values

SDNQ model weight budget was 3,500 MB (only transformer + VAE), now
5,300 MB (includes Qwen3 text encoder). Runtime overhead measured at
2,500 MB for 1024x1024 generation with attention slicing (was 500 MB).

MLX model weight budget confirmed at 4,400 MB. Runtime overhead measured
at 9,700 MB for 1024x1024 generation (was 0 MB) — mflux lacks attention
slicing so full computation runs in one shot.
