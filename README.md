# Gemini CLI — student sandbox (GitHub Codespace)

[![CI](https://github.com/rtfisher/gemini-cli-sandbox/actions/workflows/ci.yml/badge.svg)](https://github.com/rtfisher/gemini-cli-sandbox/actions/workflows/ci.yml)
[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/rtfisher/gemini-cli-sandbox)

A ready-to-run GitHub Codespace for experimenting with Google's **Gemini CLI**.
The CLI is **pre-installed**; a student's only setup step is pasting one **free**
API key. No Anthropic key, no billing, no credit card.

> **Students — use the template, not the button.** The **Open in GitHub
> Codespaces** button opens a Codespace on *this* repo directly (handy for a quick
> look, or for the repo owner). But your personal `GEMINI_API_KEY` secret only
> attaches to a repo *you own*, so for the workshop click **Use this template**
> first, then open a Codespace from your own copy. See
> [Distributing to students](#distributing-to-students-codespace-secrets-gotcha).

## Quickstart (≈2 minutes)

1. **Get a free API key** — go to <https://aistudio.google.com/apikey> and create
   a key. It's free, no billing. *(On a school/Workspace Google account that
   blocks AI Studio, use a personal `@gmail.com` — see [Why an API key](#why-an-api-key-and-not-log-in-with-google).)*
2. **Get your own copy of this repo** — click **Use this template** (or **Fork**)
   so it lives under *your* account. This matters: Codespaces secrets only attach
   to repos you own — see [Distributing to students](#distributing-to-students-codespace-secrets-gotcha).
3. **Add your key as a Codespace secret** — your account **Settings → Codespaces
   → Secrets**, name it **`GEMINI_API_KEY`**, paste the key, and grant it to your
   copy of the repo.
4. **Open your copy in a Codespace.** `postCreateCommand` runs setup automatically:
   installs Gemini CLI, preloads `~/.gemini/settings.json` (so you're never
   prompted for auth or telemetry), and checks your key with a live call.
5. **Verify and run:**
   ```bash
   make doctor     # confirms the key works end-to-end
   make start      # launches Gemini CLI   (or just run: gemini)
   ```

That's the whole flow. Once the key is set, `gemini` just works.

### Local (outside a Codespace)
```bash
cp .env.example .env      # put GEMINI_API_KEY in it
make setup && make doctor && make start
```

---

## Distributing to students (Codespace secrets gotcha)

Personal Codespaces secrets attach to repositories **you own**. So if a student
creates a Codespace **directly on the instructor's repo**, their personal
`GEMINI_API_KEY` secret is *not* available and `make doctor` reports the key as
missing. Give each student their **own copy**:

1. **Use this template** (green button) — or **Fork** — to create a copy under
   the student's own account.
2. In the student's account: **Settings → Codespaces → Secrets**, add
   `GEMINI_API_KEY` and grant it to that repo (or "All repositories").
3. Open a Codespace **from their copy**. The secret now attaches.

*(Advanced alternative, no copy needed: in the secret's **Repository access**
list, explicitly add the instructor's repo. But the template/fork route is
simpler and more reliable for a class.)*

**Fallback if the secret still isn't detected** — paste the key into a local
`.env` instead (it's gitignored, so it never leaves the Codespace):
```bash
cp .env.example .env       # then edit .env: GEMINI_API_KEY=...
make setup
```

---

## Why an API key, and not "Log in with Google"?

You might expect to just authenticate with Google. Two things make that
impractical right now, which is why this sandbox uses an API key instead:

- **Google deprecated the free "Login with Google" path for Gemini CLI on
  June 18, 2026.** Personal-account free login no longer serves Gemini CLI;
  Google moved that experience to a separate tool (Antigravity CLI).
- **School/Workspace Google accounts** additionally required per-user Google
  Cloud project setup for OAuth — extra friction for a class.

The **API-key path sidesteps both**: no OAuth browser-callback problem in a
Codespace, no Cloud project. The one wrinkle: some **education/Workspace accounts
are restricted from creating AI Studio keys** — if yours is, create the key on a
personal `@gmail.com`. The key, once created, works anywhere.

---

## What the free tier gives you — and what hitting the limit looks like

The free (unpaid AI Studio key) tier is **Flash-tier** — the default model is
`gemini-3.5-flash` (Google retired `gemini-2.5-flash` for new users in Jul 2026).
"Free" is governed by **three separate meters running at once** — trip *any* one
and you get **HTTP 429**:

| Meter | Rough free-tier value | What trips it |
|---|---|---|
| Requests / day | ~1,500 (reported) | many prompts across the day |
| Requests / minute | ~15 | rapid bursts |
| **Tokens / minute** | **~250,000** | **one big turn — this is the usual wall** |

Exact numbers live in your AI Studio dashboard (<https://aistudio.google.com/rate-limit>)
and are subject to change. The counter-intuitive part: **you can be at 10% of your
daily requests and still get 429'd** because a single large turn blew the
**per-minute token** limit. `make doctor` explains all three.

### Why this repo ships with subagents and model-routing OFF

Early testing showed a "simple" task burning **27 API requests and 323,000 input
tokens in ~12 minutes** — because two Gemini CLI defaults quietly multiply usage:

- **Subagents** (`experimental.enableAgents`, default *on*) auto-delegate work to
  helper agents that each re-send full context. In that test, **21 of 27 requests
  and ~75% of all tokens** came from subagents.
- **The model router** (`experimental.useModelRouter`, default *on*) makes the
  effective model `auto` and silently overrode the pinned model — and subagents
  inherit that routing.

So this repo's `settings.json` **disables both**, and `start.sh` pins the model
three ways (`--model` flag + `GEMINI_MODEL` env + settings) because `model.name`
alone is known to get overridden. `make doctor` verifies the guards are active.
The result is predictable, single-model, no-fan-out sessions that fit the free
tier. **Trade-off:** you lose auto-delegation and the `/model` switcher — both
intentional for a low-cost, reproducible workshop. To experiment with them, set
`experimental.enableAgents` / `experimental.useModelRouter` back to `true` in
`~/.gemini/settings.json` (and expect much faster quota burn).

### Keeping per-request context modest

You **can't shrink the model's context *window*** — it's a fixed ~1M-token
property of Flash. What you *can* do is limit how much context the CLI **sends
per request** (the thing that actually costs tokens). This repo's `settings.json`
sets:

- `context.includeDirectoryTree: false` — drops the repo directory listing from
  the first request.
- `context.discoveryMaxDirs: 1` + `context.fileName: GEMINI.md` — load only the
  single root memory file, not a walked tree of them.
- `summarizeToolOutput.run_shell_command.tokenBudget: 2000` — caps how much
  shell-command output is fed back to the model.
- `model.maxSessionTurns: 25` — a runaway-session guard. **Caveat:** it does *not*
  shrink individual requests, and in interactive mode the CLI **stops responding**
  once the cap is hit (start a new session). Raise or remove it in
  `~/.gemini/settings.json` if it ever cuts you off mid-task.

Two levers we intentionally left alone: **`tools.core`** (an allowlist that trims
per-request tool-schema tokens — the biggest single lever, but a wrong tool name
silently disables a capability, so enable it yourself from the gemini-cli
"built-in tools" list if you want it), and **`model.compressionThreshold`** (left
at its default — on a ~1M window it won't trigger within a short free-tier
session, and each trigger spends an extra request).

> **One honest caveat:** because Google changed CLI access at the June 2026
> deprecation, it isn't officially guaranteed that *unpaid* keys keep working in
> the CLI indefinitely. That's exactly why `make doctor` does a **live
> round-trip** — you'll know on day one, not mid-semester. If a key that worked
> stops, create a fresh AI Studio key.

---

## Commands

| Command | What it does |
|---|---|
| `make setup` | Install Gemini CLI, preload settings, validate the key |
| `make start` | Launch Gemini CLI (`ARGS="..."` to pass flags), or just run `gemini` |
| `make doctor` | Check CLI, settings, key, and a live round-trip |
| `make test` | Run the offline test suite locally (same as CI) |

Configuration: `.env` (local) or Codespace secrets. See `.env.example`. To pin a
model or CLI version, set `GEMINI_MODEL` / `GEMINI_CLI_VERSION`.

---

## CI/CD

`.github/workflows/ci.yml` runs on **every push and PR** (no secrets needed):

- **lint** — `shellcheck` + `bash -n` on the scripts.
- **tests** — `tests/` pytest suite: `settings.template.json` preconfigures
  api-key auth with telemetry off, `devcontainer.json` is valid and declares the
  `GEMINI_API_KEY` secret, `.env.example` documents the vars with no committed
  key, and the Makefile/GEMINI.md are present.

A gated **smoke** job does a live `make setup && doctor` — only on manual
dispatch / a daily schedule (to avoid spending the small free-tier budget on
every commit), and it self-skips if `GEMINI_API_KEY` isn't set as an Actions
secret. Run the offline suite locally with `make test`.

---

## Troubleshooting

**`doctor` says HTTP 400/403.** The key was rejected. Create a fresh key at
<https://aistudio.google.com/apikey> and update the `GEMINI_API_KEY` secret. If a
previously-working key stopped, see the June-2026 caveat above.

**`doctor` says HTTP 404 "no longer available."** The pinned model was retired —
Google does this periodically (`gemini-2.5-flash` went 404 for new users in
Jul 2026). Pull the latest repo and **rebuild the Codespace**, or set
`GEMINI_MODEL` to a current model (`gemini-3.5-flash`, or the auto-updating alias
`gemini-flash-latest`) and re-run `make setup`.

**Everything returns 429.** You hit the free daily/per-minute cap. Wait for the
reset (per-minute limits clear in ~60s), or use a different key. Keep sessions lean.

**"Account not eligible" / can't create a key.** Your school/Workspace account is
restricted from AI Studio. Use a personal `@gmail.com` to create the key.

**`gemini: command not found`.** Run `make setup` (or rebuild the Codespace). The
CLI needs Node 20+, which the devcontainer image provides.

**Want a stronger model (Gemini 3 Pro)?** Pro needs a **paid** key; set
`GEMINI_MODEL` accordingly. Flash models — including the default
`gemini-3.5-flash` — are free.
