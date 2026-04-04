---
"a2go": patch
---

fix: remove unsupported model types from registry

Remove registry entries for model types (reranking, vision, embedding) that
are not yet supported, eliminating the "SKIP: unknown type" warnings on startup.
