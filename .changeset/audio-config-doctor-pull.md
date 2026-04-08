---
"a2go": patch
---

fix: audio config deserialize + doctor always pulls latest image

AudioConfig now correctly deserializes both string and object forms from
saved configs, fixing wrong gateway shown in status. Doctor always attempts
to pull the latest image so users get updates, falling back to local only
if pull fails.
