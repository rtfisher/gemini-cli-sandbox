# CLAUDE.md — gemini-cli-sandbox

Guidance for Claude Code (and collaborators) working in this repo.

## What this is

A ready-to-run **GitHub Codespace for a workshop on Google's Gemini CLI**. The CLI
is pre-installed; a student's only manual step is pasting one **free** Google AI
Studio API key. No Anthropic key, no billing, no OAuth. Optimized for **minimal
student setup** and **staying inside the free tier**.

## How it works (flow)

1. Student gets their own copy of the repo (it's a **template**), adds a
   `GEMINI_API_KEY` Codespace secret, opens a Codespace.
2. `.devcontainer/devcontainer.json` → `postCreateCommand` runs `scripts/setup.sh`.
3. `setup.sh` installs `@google/gemini-cli`, generates `~/.gemini/settings.json`
   from `config/settings.template.json` (patching `model.name` via `jq`), and
   validates the key with a live `generateContent` round-trip.
4. `make doctor` re-checks everything; `make start` (or bare `gemini`) launches it.

## Key files

| File | Role |
|---|---|
| `.devcontainer/devcontainer.json` | Node 20 image, postCreate→setup.sh, `GEMINI_API_KEY` secret, `containerEnv.GEMINI_MODEL` pin |
| `scripts/lib.sh` | Shared: endpoints, defaults (`GEMINI_MODEL`, `GEMINI_CLI_VERSION`), env loading, logging |
| `scripts/setup.sh` | Install CLI, generate settings.json, validate key |
| `scripts/doctor.sh` | Verify CLI/settings/key + live round-trip; reports quota-guard status |
| `scripts/start.sh` | Launch `gemini --model "$GEMINI_MODEL"` |
| `config/settings.template.json` | Source for `~/.gemini/settings.json` (auth, quota guards, context trims) |
| `GEMINI.md` | Project context loaded by the CLI; nudges the agent to be quota-economical |
| `tests/test_static.py` | Offline CI checks (config integrity + quota-guard regression) |

## Non-obvious design decisions (READ before editing)

These were learned the hard way in testing — don't undo them without cause.

- **Model default = `gemini-3.5-flash`.** `gemini-2.5-flash` was **retired for new
  users (Jul 2026)** and returns HTTP 404. `setup.sh`/`doctor.sh` handle 404 with a
  "model retired → update `GEMINI_MODEL`" message.
- **The model is pinned THREE ways** because `settings.json` `model.name` alone
  gets overridden by the CLI's model router (known bugs): the `--model` flag in
  `start.sh` (highest precedence), `GEMINI_MODEL` in devcontainer `containerEnv`
  (covers a bare `gemini`), and `model.name` in settings.
- **⚠️ Changing the model means editing FOUR places** (keep them in sync):
  `scripts/lib.sh`, `.devcontainer/devcontainer.json` (`containerEnv`),
  `.env.example`, and `config/settings.template.json`.
- **Quota guards must stay OFF** in `settings.template.json` — `experimental.enableAgents`
  (subagents) and `experimental.useModelRouter` (router). In testing they turned a
  "simple" task into 27 requests / 323K input tokens (subagents ≈ 75% of that) and
  drifted the model. A CI test (`test_settings_template_protects_free_quota`)
  enforces both stay `false`. Trade-off: no auto-delegation, no `/model` switcher.
- **Context trims** in settings keep per-request tokens modest: `context.includeDirectoryTree:false`,
  `context.discoveryMaxDirs:1`, `summarizeToolOutput.run_shell_command.tokenBudget:2000`,
  `model.maxSessionTurns:25`. There is **no** "context window size" knob (window is
  a fixed model property); these limit what the CLI *sends*. `tools.core` and
  `compressionThreshold` were intentionally left alone (see README for why).
- **Auth is API-key only.** Login-with-Google was deprecated for Gemini CLI
  (Jun 2026); it also fails in Codespaces (random OAuth port) and needs a Cloud
  project on Workspace/edu accounts. The API-key path sidesteps all of that.
- **Codespace secrets gotcha (the #1 student support issue):** personal Codespaces
  secrets attach only to repos **you own**. Students must use **"Use this template →
  Create a new repository"** (NOT "Open in a codespace", and NOT a Codespace on the
  instructor's repo) so their secret attaches. The repo is marked as a **template**.

## Free-tier reality

Three meters run at once; tripping any returns **HTTP 429**: ~1,500 req/day,
~15 req/min, **~250K tokens/min** (the per-minute token cap is the usual wall — a
big/subagent turn can blow it alone). Exact numbers live behind the AI Studio
dashboard and change often; treat repo figures as directional.

## Commands

`make setup | start | doctor | test`. Config lives in `.env` (local) or Codespace
secrets; see `.env.example`. `make test` = the offline CI suite (shellcheck +
`bash -n` + pytest).

## CI

`.github/workflows/ci.yml`: **lint + tests run on every push/PR** (no secrets,
fork-safe). A **live `smoke`** job (real `setup && doctor`) runs **only on manual
dispatch / daily schedule** and self-skips without `GEMINI_API_KEY` — deliberately
kept off the per-push path so it doesn't spend the free-tier budget on every commit.

## Making changes safely

- After any change: run **`make test`** (mirrors CI).
- Config generation is `jq` in `setup.sh` (`del(."//") | .model.name=$m`) over the
  template — the template's other keys pass through, so add new settings there.
- Keep live API calls **off** the per-push CI path.
- Commit style: `type: summary`, and end the body with the
  `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>` trailer.
