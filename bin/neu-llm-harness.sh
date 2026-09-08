#!/usr/bin/env bash
# Pick the agent harness behind SUPER+I, and hand it the arguments unchanged.
#
# The panel speaks one protocol -- NDJSON events on stdout, control lines on
# stdin (see bin/neu-llm.py, which defines it). Every harness below is reached
# through an adapter that speaks that protocol, so the sidebar does not know or
# care which one is answering:
#
#   builtin    bin/neu-llm.py          talks to the OpenAI-compatible endpoint
#                                      directly. Read-only tools, a ~200 token
#                                      system prompt -- the only one that fits
#                                      in a small context window.
#   pi         bin/neu-llm-pi.py       pi.dev's harness in `--mode rpc`. Read,
#                                      Write, Edit, Bash; its confirm dialogs
#                                      become the panel's approval cards.
#   opencode   bin/neu-llm-opencode.py `opencode serve` over HTTP + SSE, with
#                                      its permission API wired to the same
#                                      cards. Brings MCP servers and agents.
#
# WHY NOT DEFAULT TO A REAL HARNESS: pi and opencode carry system prompts of
# ~10k tokens. That is fine against a model loaded with a large context and an
# instant failure against one loaded at 4096, which is how LM Studio ships. So
# the choice is explicit -- set NEU_LLM_HARNESS, or pick one in the panel --
# and the builtin stays the default because it always works.
#
#   --detect   print one JSON line describing every harness on this box
#              (install.sh reports it; the panel's picker reads it)
#
# Anything else is passed through to the active harness verbatim.

set -uo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/neu/llm"
CHOICE_FILE="$STATE_DIR/harness"
ENV_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/neu/llm.env"

# The adapters read llm.env themselves, but the choice of adapter is made here,
# before any of them runs -- so NEU_LLM_HARNESS has to be picked up early or
# setting it in that file would silently do nothing. Only that one key is read;
# everything else stays the adapters' business.
if [[ -z "${NEU_LLM_HARNESS:-}" && -r "$ENV_FILE" ]]; then
    line="$(grep -E '^[[:space:]]*(export[[:space:]]+)?NEU_LLM_HARNESS=' "$ENV_FILE" | tail -1)"
    if [[ -n "$line" ]]; then
        want="${line#*=}"
        want="${want%\"}"; want="${want#\"}"
        want="${want%\'}"; want="${want#\'}"
        NEU_LLM_HARNESS="$(printf '%s' "$want" | tr -d '[:space:]')"
    fi
fi

have() { command -v "$1" >/dev/null 2>&1; }

version_of() {
    case "$1" in
        pi)       have pi       && pi --version 2>/dev/null | head -1 ;;
        opencode) have opencode && opencode --version 2>/dev/null | head -1 ;;
        builtin)  python3 -c "import requests" 2>/dev/null && echo "python3" ;;
    esac
}

available() {
    case "$1" in
        pi)       have pi ;;
        opencode) have opencode ;;
        builtin)  python3 -c "import requests" 2>/dev/null ;;
        *)        return 1 ;;
    esac
}

# Explicit environment beats the panel's remembered pick beats the safe default.
active() {
    local want="${NEU_LLM_HARNESS:-}"
    [[ -z "$want" && -r "$CHOICE_FILE" ]] && want="$(tr -d '[:space:]' < "$CHOICE_FILE")"
    [[ -z "$want" ]] && want="builtin"
    if ! available "$want"; then
        [[ "$want" != "builtin" ]] && \
            printf '{"t":"error","msg":"%s is not installed -- falling back to the builtin harness"}\n' "$want"
        want="builtin"
    fi
    printf '%s' "$want"
}

# The panel writes the picker's choice here; the next launch reads it above.
if [[ "${1:-}" == "--select-harness" ]]; then
    if ! available "${2:-}"; then
        printf '{"t":"error","msg":"unknown or unavailable harness: %s"}\n' "${2:-}"
        exit 1
    fi
    mkdir -p "$STATE_DIR"
    printf '%s\n' "$2" > "$CHOICE_FILE"
    printf '{"t":"harness_selected","harness":"%s"}\n' "$2"
    exit 0
fi

if [[ "${1:-}" == "--detect" ]]; then
    python3 - "$(active)" <<'PY'
import json, shutil, subprocess, sys

def version(cmd, *args):
    try:
        out = subprocess.run([cmd, *args], capture_output=True, text=True, timeout=10)
        return (out.stdout or out.stderr).strip().splitlines()[0][:40]
    except Exception:
        return ""

def has_module(name):
    try:
        __import__(name); return True
    except ImportError:
        return False

rows = [{
    "id": "builtin",
    "name": "neu built-in",
    "available": has_module("requests"),
    "version": sys.version.split()[0],
    "install": "python3 -m pip install --user requests",
    "note": "read-only tools, tiny system prompt -- works in a 4k context",
}, {
    "id": "pi",
    "name": "pi",
    "available": bool(shutil.which("pi")),
    "version": version("pi", "--version") if shutil.which("pi") else "",
    "install": "npm install -g @earendil-works/pi-coding-agent",
    "note": "read/write/edit/bash, confirm dialogs become approval cards",
}, {
    "id": "opencode",
    "name": "opencode",
    "available": bool(shutil.which("opencode")),
    "version": version("opencode", "--version") if shutil.which("opencode") else "",
    "install": "sudo pacman -S opencode",
    "note": "full agent, MCP servers, permission API -- wants a big context",
}]
print(json.dumps({"t": "harnesses", "active": sys.argv[1], "harnesses": rows}))
PY
    exit 0
fi

case "$(active)" in
    pi)       exec neu-llm-pi.py "$@" ;;
    opencode) exec neu-llm-opencode.py "$@" ;;
    *)        exec neu-llm.py "$@" ;;
esac
