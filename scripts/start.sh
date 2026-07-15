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

info "launching Gemini CLI (model ${GEMINI_MODEL}, free tier)"
# gemini reads GEMINI_API_KEY from the environment and auth type from settings.json.
exec gemini "$@"
