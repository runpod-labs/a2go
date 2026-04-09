---
"a2go": patch
---

fix: use temp DOCKER_CONFIG for credstore workaround

Docker pull credstore workaround now uses a temporary config directory
instead of modifying the user's ~/.docker/config.json. Safer against
interruptions and doesn't touch user's Docker Desktop settings.
