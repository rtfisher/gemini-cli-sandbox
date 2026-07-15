#!/usr/bin/env bash
# lib.sh — shared helpers for the Gemini CLI student sandbox.
# Endpoints, defaults, env loading, key checks, and logging in one place.

# --- endpoints (Gemini native REST; used for live key validation) ------------
# We validate the key against the native generateContent endpoint. This proves
# the free AI Studio key actually works for the chosen model — important because
# it's not officially confirmed that unpaid keys still serve requests after the
# June 18 2026 "Login with Google" deprecation. `make doctor` surfaces the truth
# rather than assuming.
export GEMINI_API_HOST="https://generativelanguage.googleapis.com/v1beta"

# --- defaults (overridable via env / .env / Codespace secrets) ---------------
: "${GEMINI_MODEL:=gemini-2.5-flash}"   # free unpaid key is Flash-only
: "${GEMINI_CLI_VERSION:=latest}"       # pin a tested version for a class
export GEMINI_MODEL GEMINI_CLI_VERSION

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export REPO_ROOT
export GEMINI_SETTINGS_DIR="${HOME}/.gemini"
export GEMINI_SETTINGS_FILE="${GEMINI_SETTINGS_DIR}/settings.json"

# --- logging -----------------------------------------------------------------
if [ -t 1 ]; then
  _C_RESET=$'\033[0m'; _C_BLUE=$'\033[34m'; _C_GREEN=$'\033[32m'
  _C_YELLOW=$'\033[33m'; _C_RED=$'\033[31m'; _C_DIM=$'\033[2m'
else
  _C_RESET=""; _C_BLUE=""; _C_GREEN=""; _C_YELLOW=""; _C_RED=""; _C_DIM=""
fi
info()  { printf '%s\n' "${_C_BLUE}==>${_C_RESET} $*"; }
ok()    { printf '%s\n' "${_C_GREEN}  ok${_C_RESET} $*"; }
warn()  { printf '%s\n' "${_C_YELLOW}  --${_C_RESET} $*"; }
err()   { printf '%s\n' "${_C_RED} fail${_C_RESET} $*" >&2; }
note()  { printf '%s\n' "${_C_DIM}     $*${_C_RESET}"; }

# --- env loading -------------------------------------------------------------
# In a Codespace the GEMINI_API_KEY secret is already in the environment; .env is
# purely additive for local use.
load_env() {
  if [ -f "${REPO_ROOT}/.env" ]; then
    set -a
    # shellcheck disable=SC1091
    . "${REPO_ROOT}/.env"
    set +a
  fi
}

# True if a Gemini API key is present.
key_present() { [ -n "${GEMINI_API_KEY:-}" ]; }
