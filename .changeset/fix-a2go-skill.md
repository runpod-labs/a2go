---
"a2go": patch
---

fix: update a2go skill with correct cli commands

Skill now uses `a2go run` (not `start`), includes required `--agent` flag,
and removes non-existent `--context` and `a2go logs` commands.
