---
"a2go": patch
---

fix: copy skills into hermes directory instead of symlinking

Hermes skill discovery uses `os.walk()` without `followlinks=True`, so symlinked
skill directories are invisible to the prompt builder. Skills were installed but
never shown to the AI. Replace symlinks with file copies so skills are discoverable.
Also handles migration from existing symlink-based installs.
