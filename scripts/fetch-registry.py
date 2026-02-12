#!/usr/bin/env python3
"""
fetch-registry.py - Fetch external model registry for OpenClaw2Go.

Fetches catalog.json from a remote registry (GitHub Pages), validates entries,
and writes a merged registry to a cache directory. Falls back to the baked-in
registry on any failure.

Environment variables:
  OPENCLAW_REGISTRY_URL        Remote catalog URL (default: GitHub Pages v1)
  OPENCLAW_REGISTRY_OFFLINE    Set "true" to skip fetch entirely
  OPENCLAW_REGISTRY_TTL_SECONDS  Cache freshness in seconds (default: 3600)
  OPENCLAW_REGISTRY_DIR        Baked-in fallback registry (default: /opt/openclaw/registry)

On success, prints the path to the merged registry directory to stdout.
On failure, prints nothing (caller falls back to baked-in registry).

Stdlib only — no pip dependencies.
"""

import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

DEFAULT_REGISTRY_URL = (
    "https://runpod-workers.github.io/openclaw2go-registry/v1/catalog.json"
)
FETCH_TIMEOUT = 5  # seconds
BAKED_IN_DIR = Path(os.environ.get("OPENCLAW_REGISTRY_DIR", "/opt/openclaw/registry"))
CACHE_DIR = Path("/workspace/.openclaw/registry")
CACHE_META = CACHE_DIR / ".fetch-meta.json"

# Known engines that are physically present in the image
ALLOWED_ENGINES = {"llamacpp", "llamacpp-audio", "image-gen", "vllm"}

# Required fields for model validation
REQUIRED_MODEL_FIELDS = {"id", "name", "type", "engine", "vram"}
REQUIRED_PROFILE_FIELDS = {"id", "name", "services"}


def log(msg):
    print(f"[fetch-registry] {msg}", file=sys.stderr)


def is_cache_fresh(ttl_seconds):
    """Check if cached registry is fresh enough to skip fetching."""
    if not CACHE_META.exists():
        return False
    try:
        meta = json.loads(CACHE_META.read_text())
        fetched_at = meta.get("fetchedAt", 0)
        return (time.time() - fetched_at) < ttl_seconds
    except (json.JSONDecodeError, OSError):
        return False


def fetch_catalog(url):
    """Fetch catalog.json from remote URL. Returns parsed JSON or None."""
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "openclaw2go/1.0"})
        with urllib.request.urlopen(req, timeout=FETCH_TIMEOUT) as resp:
            data = resp.read()
            return json.loads(data)
    except (urllib.error.URLError, urllib.error.HTTPError, OSError, json.JSONDecodeError) as e:
        log(f"Fetch failed: {e}")
        return None


def validate_model(model, index):
    """Validate a single model entry. Returns list of warnings (empty = valid)."""
    warnings = []

    missing = REQUIRED_MODEL_FIELDS - set(model.keys())
    if missing:
        warnings.append(f"model[{index}]: missing fields: {missing}")
        return warnings

    engine = model.get("engine", "")
    if engine not in ALLOWED_ENGINES:
        warnings.append(f"model '{model['id']}': unknown engine '{engine}' (allowed: {ALLOWED_ENGINES})")

    download_dir = model.get("downloadDir", "")
    if download_dir and not download_dir.startswith("/workspace/models/"):
        warnings.append(f"model '{model['id']}': downloadDir must start with /workspace/models/, got '{download_dir}'")

    vram = model.get("vram", {})
    if not isinstance(vram, dict) or "model" not in vram:
        warnings.append(f"model '{model['id']}': vram must have 'model' field")

    model_type = model.get("type", "")
    if model_type not in ("llm", "audio", "image"):
        warnings.append(f"model '{model['id']}': unknown type '{model_type}'")

    return warnings


def validate_profile(profile, index, valid_model_ids):
    """Validate a single profile entry. Returns list of warnings."""
    warnings = []

    missing = REQUIRED_PROFILE_FIELDS - set(profile.keys())
    if missing:
        warnings.append(f"profile[{index}]: missing fields: {missing}")
        return warnings

    for i, svc in enumerate(profile.get("services", [])):
        model_ref = svc.get("model", "")
        if model_ref and model_ref not in valid_model_ids:
            warnings.append(f"profile '{profile['id']}' service[{i}]: references unknown model '{model_ref}'")

    return warnings


def merge_registry(catalog, baked_in_dir, cache_dir):
    """
    Merge external catalog with baked-in registry.

    Strategy:
    - engines.json: always from baked-in (maps to physical binaries)
    - gpus/: always from baked-in (changes rarely, wrong data = OOM)
    - models/: external overrides baked-in (by model ID)
    - profiles/: external overrides baked-in (by profile ID)
    """
    cache_dir.mkdir(parents=True, exist_ok=True)

    # Symlink engines.json from baked-in
    engines_src = baked_in_dir / "engines.json"
    engines_dst = cache_dir / "engines.json"
    if engines_src.exists():
        engines_dst.unlink(missing_ok=True)
        # Copy instead of symlink for robustness
        engines_dst.write_text(engines_src.read_text())

    # Symlink gpus/ from baked-in
    gpus_src = baked_in_dir / "gpus"
    gpus_dst = cache_dir / "gpus"
    if gpus_src.is_dir():
        if gpus_dst.is_symlink() or gpus_dst.exists():
            if gpus_dst.is_symlink():
                gpus_dst.unlink()
            else:
                import shutil
                shutil.rmtree(gpus_dst)
        gpus_dst.symlink_to(gpus_src)

    # Merge models: start with baked-in, override with external
    models_dst = cache_dir / "models"
    models_dst.mkdir(parents=True, exist_ok=True)

    # Clear old cached model files
    for f in models_dst.glob("*.json"):
        f.unlink()

    # Copy baked-in models
    baked_models_dir = baked_in_dir / "models"
    baked_model_ids = set()
    if baked_models_dir.is_dir():
        for f in baked_models_dir.glob("*.json"):
            dst = models_dst / f.name
            dst.write_text(f.read_text())
            try:
                data = json.loads(f.read_text())
                baked_model_ids.add(data.get("id", f.stem))
            except json.JSONDecodeError:
                pass

    # Overlay external models (validated)
    external_models = catalog.get("models", [])
    valid_model_ids = set(baked_model_ids)
    accepted = 0
    skipped = 0

    for i, model in enumerate(external_models):
        warnings = validate_model(model, i)
        if warnings:
            for w in warnings:
                log(f"SKIP: {w}")
            skipped += 1
            continue

        model_id = model["id"]
        # Use a safe filename derived from model ID
        safe_name = model_id.replace("/", "--") + ".json"
        (models_dst / safe_name).write_text(json.dumps(model, indent=2) + "\n")
        valid_model_ids.add(model_id)
        accepted += 1

    log(f"Models: {accepted} external accepted, {skipped} skipped, {len(baked_model_ids)} baked-in")

    # Merge profiles: same strategy
    profiles_dst = cache_dir / "profiles"
    profiles_dst.mkdir(parents=True, exist_ok=True)

    for f in profiles_dst.glob("*.json"):
        f.unlink()

    baked_profiles_dir = baked_in_dir / "profiles"
    if baked_profiles_dir.is_dir():
        for f in baked_profiles_dir.glob("*.json"):
            (profiles_dst / f.name).write_text(f.read_text())

    external_profiles = catalog.get("profiles", [])
    p_accepted = 0
    p_skipped = 0

    for i, profile in enumerate(external_profiles):
        warnings = validate_profile(profile, i, valid_model_ids)
        if warnings:
            for w in warnings:
                log(f"SKIP: {w}")
            p_skipped += 1
            continue

        profile_id = profile["id"]
        safe_name = profile_id.replace("/", "--") + ".json"
        (profiles_dst / safe_name).write_text(json.dumps(profile, indent=2) + "\n")
        p_accepted += 1

    log(f"Profiles: {p_accepted} external accepted, {p_skipped} skipped")

    # Write fetch metadata
    CACHE_META.write_text(json.dumps({
        "fetchedAt": time.time(),
        "url": os.environ.get("OPENCLAW_REGISTRY_URL", DEFAULT_REGISTRY_URL),
        "modelsAccepted": accepted,
        "modelsSkipped": skipped,
        "profilesAccepted": p_accepted,
        "profilesSkipped": p_skipped,
    }, indent=2) + "\n")

    return cache_dir


def main():
    # Check if offline mode
    if os.environ.get("OPENCLAW_REGISTRY_OFFLINE", "").lower() == "true":
        log("Offline mode — using baked-in registry")
        return

    url = os.environ.get("OPENCLAW_REGISTRY_URL", DEFAULT_REGISTRY_URL)
    ttl = int(os.environ.get("OPENCLAW_REGISTRY_TTL_SECONDS", "3600"))

    # Check cache freshness
    if is_cache_fresh(ttl) and (CACHE_DIR / "models").is_dir():
        log(f"Cache is fresh (TTL={ttl}s) — using cached registry")
        # Print cache dir path to stdout for entrypoint to consume
        print(str(CACHE_DIR))
        return

    # Fetch remote catalog
    log(f"Fetching registry from {url}")
    catalog = fetch_catalog(url)

    if catalog is None:
        # Check if stale cache exists — better than nothing
        if (CACHE_DIR / "models").is_dir():
            log("Fetch failed — using stale cached registry")
            print(str(CACHE_DIR))
        else:
            log("Fetch failed — falling back to baked-in registry")
        return

    # Validate top-level structure
    if not isinstance(catalog, dict):
        log("Invalid catalog: not a JSON object")
        return

    if "models" not in catalog and "profiles" not in catalog:
        log("Invalid catalog: no 'models' or 'profiles' key")
        return

    # Merge and write
    try:
        result_dir = merge_registry(catalog, BAKED_IN_DIR, CACHE_DIR)
        log(f"Registry merged to {result_dir}")
        # Print result dir to stdout for entrypoint
        print(str(result_dir))
    except Exception as e:
        log(f"Merge failed: {e}")
        # Fall back silently


if __name__ == "__main__":
    main()
