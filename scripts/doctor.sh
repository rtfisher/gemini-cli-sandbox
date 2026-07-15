#!/usr/bin/env bash
# doctor.sh — diagnose the Gemini CLI sandbox; never fail opaquely.
#
# Exit-code contract:
#   0  key works OR is merely rate-limited (throttled != broken).
#   1  genuinely broken: CLI missing, no key, or key rejected.
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
load_env

FAIL=0
echo
info "doctor — Gemini CLI student sandbox"
echo

# --- 1. CLI installed --------------------------------------------------------
info "[1/4] Gemini CLI"
if command -v gemini >/dev/null 2>&1; then
  ok "installed: $(gemini --version 2>/dev/null | head -n1)"
else
  err "gemini not found — run 'make setup'"
  FAIL=1
fi

# --- 2. settings preloaded ---------------------------------------------------
info "[2/4] settings"
if [ -f "$GEMINI_SETTINGS_FILE" ] && jq -e . "$GEMINI_SETTINGS_FILE" >/dev/null 2>&1; then
  authtype="$(jq -r '.security.auth.selectedType // "?"' "$GEMINI_SETTINGS_FILE")"
  model="$(jq -r '.model.name // "?"' "$GEMINI_SETTINGS_FILE")"
  ok "${GEMINI_SETTINGS_FILE} (auth=${authtype}, model=${model})"
else
  err "missing/invalid ${GEMINI_SETTINGS_FILE} — run 'make setup'"
  FAIL=1
fi

# --- 3. API key present ------------------------------------------------------
info "[3/4] API key"
if key_present; then
  ok "GEMINI_API_KEY is set"
else
  err "GEMINI_API_KEY not set"
  note "free key (no billing): https://aistudio.google.com/apikey"
  note "add it as Codespace secret GEMINI_API_KEY (or to .env), then re-run"
  FAIL=1
fi

# --- 4. live round-trip (the deprecation-risk check) -------------------------
info "[4/4] live round-trip (model ${GEMINI_MODEL})"
RATELIMITED=0
if key_present; then
  body="$(mktemp)"
  code="$(curl -sS -o "$body" -w '%{http_code}' --max-time 30 \
      -X POST "${GEMINI_API_HOST}/models/${GEMINI_MODEL}:generateContent" \
      -H "x-goog-api-key: ${GEMINI_API_KEY}" \
      -H "Content-Type: application/json" \
      -d '{"contents":[{"parts":[{"text":"reply with one word: pong"}]}],"generationConfig":{"maxOutputTokens":5}}' \
      || echo "000")"
  case "$code" in
    200)
      reply="$(jq -r '.candidates[0].content.parts[0].text // empty' "$body" 2>/dev/null | tr -d '\n')"
      ok "completion OK (HTTP 200) — model replied: ${reply:-<empty>}";;
    400|403)
      err "key rejected (HTTP $code)"
      note "$(jq -r '.error.message // empty' "$body" 2>/dev/null)"
      note "if this key used to work, note that unpaid keys' CLI access changed after the June 2026 deprecation — try a fresh AI Studio key"
      FAIL=1;;
    429)
      RATELIMITED=1
      warn "rate-limited (HTTP 429) — the free-tier daily cap is hit (throttled, not broken)"
      note "free unpaid key: ~250 requests/day, Flash-only; resets on a rolling daily window";;
    000) err "no response (timeout/network)"; FAIL=1;;
    *)   err "unexpected HTTP $code"; note "$(head -c 300 "$body" 2>/dev/null)"; FAIL=1;;
  esac
  rm -f "$body"
else
  warn "skipped — no key to test with"
fi

echo
note "Free-tier reality (subject to change; exact numbers live in your AI Studio dashboard):"
note "  ~250 requests/day, Flash-only for an unpaid AI Studio key. Hitting it looks like HTTP 429."
echo
if [ "$FAIL" -eq 0 ]; then
  if [ "$RATELIMITED" -eq 1 ]; then
    ok "doctor: healthy but throttled — setup is correct, the daily cap is currently hit."
  else
    ok "doctor: all checks passed — ready. Run 'make start' or 'gemini'."
  fi
  exit 0
else
  err "doctor: not ready — see messages above."
  exit 1
fi
