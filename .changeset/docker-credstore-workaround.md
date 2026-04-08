---
"a2go": patch
---

fix: auto-workaround docker credential store error on pull

Docker Desktop's credsStore requires a desktop session, failing over SSH.
PullImage now detects this, temporarily removes credsStore, retries the
pull, then restores the config automatically.
