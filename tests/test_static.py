"""Static repo-integrity checks: the shipped config is valid and consistent."""
import json
import os
import re

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def _read(*parts):
    with open(os.path.join(REPO_ROOT, *parts)) as fh:
        return fh.read()


def _load_jsonc(text):
    """Parse JSONC (JSON-with-comments). Prefer json5; fall back to stripping
    whole-line // comments so the suite runs where json5 isn't installed."""
    try:
        import json5
        return json5.loads(text)
    except ImportError:
        stripped = "\n".join(
            "" if re.match(r"\s*//", line) else line for line in text.splitlines()
        )
        return json.loads(stripped)


# --- settings template -------------------------------------------------------
def test_settings_template_is_valid_json():
    json.loads(_read("config", "settings.template.json"))


def test_settings_template_preconfigures_apikey_and_no_telemetry():
    s = json.loads(_read("config", "settings.template.json"))
    assert s["security"]["auth"]["selectedType"] == "gemini-api-key"
    assert s["privacy"]["usageStatisticsEnabled"] is False
    assert "name" in s["model"]


def test_settings_template_protects_free_quota():
    """The two settings that blew the free budget in testing must stay off:
    subagent auto-delegation (~75% of token burn) and the model router (which
    overrode the pinned model and drifted to a costlier one)."""
    s = json.loads(_read("config", "settings.template.json"))
    assert s["experimental"]["enableAgents"] is False, "subagents must be disabled"
    assert s["experimental"]["useModelRouter"] is False, "model router must be disabled"


# --- devcontainer ------------------------------------------------------------
def test_devcontainer_is_valid_jsonc():
    dc = _load_jsonc(_read(".devcontainer", "devcontainer.json"))
    assert "node" in dc["image"], "must use a Node base image (CLI needs Node 20+)"
    assert "setup.sh" in dc["postCreateCommand"]


def test_devcontainer_declares_gemini_key_secret():
    dc = _load_jsonc(_read(".devcontainer", "devcontainer.json"))
    assert "GEMINI_API_KEY" in dc.get("secrets", {})


def test_devcontainer_pins_model_in_env():
    """A bare `gemini` (not just `make start`) must default to the pinned model,
    so the model is fixed in the container environment too."""
    dc = _load_jsonc(_read(".devcontainer", "devcontainer.json"))
    assert dc.get("containerEnv", {}).get("GEMINI_MODEL", "").startswith("gemini-")


# --- .env.example ------------------------------------------------------------
def test_env_example_documents_vars():
    env = _read(".env.example")
    for key in ("GEMINI_API_KEY", "GEMINI_MODEL", "GEMINI_CLI_VERSION"):
        assert key in env, f"{key} must be documented in .env.example"


def test_env_example_has_no_real_key():
    for line in _read(".env.example").splitlines():
        if line.strip().startswith("GEMINI_API_KEY="):
            assert line.split("=", 1)[1].strip() == "", "key placeholder must be blank"


# --- makefile + context ------------------------------------------------------
def test_makefile_exposes_targets():
    mk = _read("Makefile")
    for target in ("setup", "start", "doctor", "test"):
        assert re.search(rf"^{re.escape(target)}:", mk, re.M), f"missing target {target}"


def test_gemini_md_present_and_nonempty():
    assert len(_read("GEMINI.md").strip()) > 50


def test_gitignore_protects_env():
    assert ".env" in _read(".gitignore")
