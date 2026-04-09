---
"a2go": patch
---

fix: mac audio requires explicit model, web proxy stt supports multipart

Mac audio server no longer starts without an explicit model (it can't
serve TTS/STT without one). Web proxy STT endpoint now accepts multipart
file uploads matching the Docker media server and OpenAI API convention.
