#!/usr/bin/env bash
# start.sh — launch Gemini CLI. Args after `--` pass through to `gemini`.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
load_env

if ! command -v gemini >/dev/null 2>&1; then
  err "gemini not installed — run 'make setup' first."
  exit 1
fi

if ! key_present; then
  err "GEMINI_API_KEY not set."
  note "Free key (no billing): https://aistudio.google.com/apikey"
  note "Add it as Codespace secret GEMINI_API_KEY (or to .env), then try again."
  exit 1
fi

# Ensure settings are in place (first run after adding a key, etc.).
if [ ! -f "$GEMINI_SETTINGS_FILE" ]; then
  info "settings missing — running setup"
  bash "${REPO_ROOT}/scripts/setup.sh"
fi

info "launching Gemini CLI (model ${GEMINI_MODEL}, subagents off, free tier)"
# Pin the model with belt-and-suspenders precedence: the --model flag is
# documented as "always used" (highest precedence) and GEMINI_MODEL (exported by
# lib.sh) is next — together they defeat the auto model-router and known bugs
# where settings.json model.name alone gets overridden. Auth type + the quota
# guards (subagents/router off) come from ~/.gemini/settings.json; the API key
# comes from GEMINI_API_KEY. A user-supplied --model in "$@" still wins (last one).
exec gemini --model "$GEMINI_MODEL" "$@"
