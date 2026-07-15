#!/usr/bin/env bash
# setup.sh — idempotent provisioning. Runs as the devcontainer postCreateCommand
# and via `make setup`. Installs Gemini CLI, preloads ~/.gemini/settings.json so
# students are never prompted, and validates the API key with a live round-trip.
#
# Succeeds even with no key yet (config is still written); the key check is
# reported clearly but doesn't block provisioning.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
load_env

info "Gemini CLI student sandbox — setup"

# --- system deps (jq, curl) --------------------------------------------------
if ! command -v jq >/dev/null 2>&1; then
  info "installing jq"
  if command -v sudo >/dev/null 2>&1; then sudo apt-get update -qq && sudo apt-get install -y -qq jq
  else apt-get update -qq && apt-get install -y -qq jq; fi
fi
ok "jq present"

# --- Node.js version gate ----------------------------------------------------
# Gemini CLI requires Node 20+, checked at runtime (not install time), so verify
# now for a clearer message than a first-run failure.
if command -v node >/dev/null 2>&1; then
  node_major="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"
  if [ "${node_major:-0}" -ge 20 ]; then ok "node $(node -v) (>=20)"
  else warn "node $(node -v) is < 20 — Gemini CLI needs Node 20+. The devcontainer pins Node 20; check your setup."; fi
else
  err "node not found — Gemini CLI needs Node 20+."
fi

# --- Gemini CLI --------------------------------------------------------------
if command -v gemini >/dev/null 2>&1; then
  ok "gemini present ($(gemini --version 2>/dev/null | head -n1))"
else
  info "installing @google/gemini-cli@${GEMINI_CLI_VERSION} (npm, global)"
  npm install -g "@google/gemini-cli@${GEMINI_CLI_VERSION}"
  ok "gemini installed ($(gemini --version 2>/dev/null | head -n1))"
fi

# --- preload settings.json (no prompts) --------------------------------------
info "writing ${GEMINI_SETTINGS_FILE} (auth=gemini-api-key, telemetry off, model=${GEMINI_MODEL})"
mkdir -p "$GEMINI_SETTINGS_DIR"
jq --arg m "$GEMINI_MODEL" 'del(."//") | .model.name=$m' \
   "${REPO_ROOT}/config/settings.template.json" > "$GEMINI_SETTINGS_FILE"
ok "settings written"

# --- validate the API key (live) ---------------------------------------------
if key_present; then
  info "validating GEMINI_API_KEY (live round-trip to ${GEMINI_MODEL})"
  body="$(mktemp)"
  code="$(curl -sS -o "$body" -w '%{http_code}' --max-time 30 \
      -X POST "${GEMINI_API_HOST}/models/${GEMINI_MODEL}:generateContent" \
      -H "x-goog-api-key: ${GEMINI_API_KEY}" \
      -H "Content-Type: application/json" \
      -d '{"contents":[{"parts":[{"text":"ping"}]}],"generationConfig":{"maxOutputTokens":5}}' \
      || echo "000")"
  case "$code" in
    200) ok "API key works (HTTP 200)";;
    400|403)
      err "API key rejected (HTTP $code)."
      note "$(jq -r '.error.message // "check the key and that ${GEMINI_MODEL} is available to it"' "$body" 2>/dev/null)"
      note "Get a fresh free key at https://aistudio.google.com/apikey and set it as Codespace secret GEMINI_API_KEY."
      note "Continuing; re-run 'make doctor' after fixing.";;
    429) warn "key valid but rate-limited right now (HTTP 429) — free-tier cap hit. It resets on a rolling daily window.";;
    000) warn "could not reach the Gemini API (network). Re-run 'make doctor' later.";;
    *)   warn "unexpected HTTP $code from Gemini API; see 'make doctor'.";;
  esac
  rm -f "$body"
else
  warn "GEMINI_API_KEY not set — add it to run Gemini CLI."
  note "Free key (no billing): https://aistudio.google.com/apikey"
  note "Then add it as Codespace secret GEMINI_API_KEY (or to .env locally) and re-run 'make setup'."
fi

ok "setup complete"
note "Next: 'make doctor' to verify, then 'make start' (or just run 'gemini')."
