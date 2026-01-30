---
name: image-gen
description: Generate images with a local FLUX.2 Klein SDNQ model.
metadata: {"openclaw":{"emoji":"🖼️","requires":{"bins":["openclaw-image-gen"]}}}
---
Use this skill to generate an image from a prompt. Invoke the `exec` tool to run
the CLI and save the output under `/workspace/openclaw/images/`.

Required inputs:
- prompt (string)
- width/height *or* aspect ratio (e.g. `1:1`, `16:9`)

Examples:
- `openclaw-image-gen --prompt "<prompt>" --width 1024 --height 1024 --output /workspace/openclaw/images/output.png`
- `openclaw-image-gen --prompt "<prompt>" --aspect 16:9 --output /workspace/openclaw/images/output.png`

If the user does not specify size, default to 1024x1024.
