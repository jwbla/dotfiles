#!/usr/bin/env python3
"""One chat turn against a local OpenAI-compatible server, streamed as NDJSON.

The backend half of the neu shell's LLM sidebar. Same shape as every other
service in this repo: a script owns the protocol and emits machine-readable
lines, the QML singleton only draws. That keeps the fiddly part -- SSE framing,
streamed tool-call assembly, path sandboxing -- testable from a terminal:

    echo 'what is in ~/dev/dotfiles/bin?' | neu-llm.py --stdin

Settings come from the environment, and the operator writes the endpoint into a
file of their own (bin/neu-llm.env.example is the template) so nothing in the
repo has to know where the model lives:

    NEU_LLM_URL     base url, OpenAI-compatible, no trailing /  (default
                    http://localhost:1234/v1 -- LM Studio's default listener)
    NEU_LLM_MODEL   model id; empty asks /models and takes the first
    NEU_LLM_KEY     bearer token; LM Studio ignores it, llama-server may not
    NEU_LLM_ROOTS   colon-separated dirs the tools may read  (default
                    ~/dev:~/.config:~/.local/state/neu)
    NEU_LLM_TOOLS   1 to offer the read-only tools, 0 for plain chat (default 1)
    NEU_LLM_CTX     turns of history replayed to the model    (default 12)
    NEU_LLM_MAX_STEPS  tool round-trips allowed in one turn   (default 6)
    NEU_LLM_TIMEOUT seconds of silence before giving up on a turn (default
                    1200 -- see READ_TIMEOUT; a queue in front of the endpoint
                    is silence too)

WHY A TOOL LOOP HERE RATHER THAN A FRAMEWORK: the loop is thirty lines and the
part that actually matters is the sandbox below it, which no framework would
write for us. A local 20b model is credulous -- it will happily be talked into
reading ~/.ssh by a README it just read -- so the refusal has to live in code
that runs before the filesystem is touched, not in a system prompt.

Every tool is READ-ONLY by design. There is no write, no delete, no shell. When
writes arrive they get an approval round-trip through the panel first; until
then the worst a confused model can do is read a file it was already allowed to.
"""

from __future__ import annotations

import argparse
import difflib
import fnmatch
import json
import os
import select
import subprocess
import sys
import time
from pathlib import Path

try:
    import requests
except ImportError:  # pragma: no cover - install-time problem, not a runtime one
    print(json.dumps({"t": "error", "msg": "python-requests is not installed"}),
          flush=True)
    sys.exit(1)

# ---------------------------------------------------------------- settings --

# The panel launches this with whatever environment the shell had, and running
# it by hand from a terminal has to behave identically, so the endpoint is read
# from the operator's own file here rather than exported by the caller. A real
# environment variable still wins -- that is what makes
# `NEU_LLM_URL=... neu-llm.py` work for testing against a second server.

ENV_FILE = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "neu/llm.env"


def load_env_file(path: Path = ENV_FILE) -> None:
    try:
        raw = path.read_text()
    except OSError:
        return  # no file yet is the normal state before first setup
    for line in raw.splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, val = line.partition("=")
        key = key.strip()
        if key.startswith("export "):
            key = key[len("export "):].strip()
        val = val.strip()
        if len(val) >= 2 and val[0] == val[-1] and val[0] in "\"'":
            val = val[1:-1]
        if key and key not in os.environ:
            os.environ[key] = val


load_env_file()

BASE_URL = os.environ.get("NEU_LLM_URL", "http://localhost:1234/v1").rstrip("/")
MODEL = os.environ.get("NEU_LLM_MODEL", "").strip()
API_KEY = os.environ.get("NEU_LLM_KEY", "").strip()
USE_TOOLS = os.environ.get("NEU_LLM_TOOLS", "1") != "0"
CAN_WRITE = os.environ.get("NEU_LLM_WRITE", "1") != "0"

# The one directory the model may write to without asking. Anything else inside
# the roots costs an approval; anything outside them is refused outright.
SCRATCH = Path(os.environ.get(
    "NEU_LLM_SCRATCH", str(Path.home() / "dev/llm-scratch"))).expanduser()
CTX_TURNS = int(os.environ.get("NEU_LLM_CTX", "12"))
MAX_STEPS = int(os.environ.get("NEU_LLM_MAX_STEPS", "6"))

STATE_DIR = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "neu/llm"

# A first token can be minutes away when the server loads the model on demand,
# so the read timeout is generous; connecting, by contrast, either works at once
# or the box is not there.
#
# Behind the compute gateway it has to be more generous still, for a reason
# that is easy to miss: its drop-in BLOCKS. It buffers the upstream answer and
# sends the whole thing at the end, so not one byte comes down the socket until
# the job has been through the queue AND finished generating -- and requests
# measures a read timeout BETWEEN bytes. Against LM Studio directly that clock
# is reset by every token and 600s means "600s of silence mid-answer"; against
# the gateway the same number has to cover the wait and the generation
# together. The gateway's own upstream timeout is 900s, so anything at or below
# that here turns its answer into our timeout instead.
CONNECT_TIMEOUT = 5
READ_TIMEOUT = int(os.environ.get("NEU_LLM_TIMEOUT", "1200"))

# Caps chosen so one greedy tool call cannot blow the context window: a 20b
# model with 8k of context has no room for a 200k file, and truncation it can
# see is far better than a stall it cannot explain.
MAX_READ_BYTES = 64 * 1024
MAX_READ_LINES = 400
MAX_MATCHES = 60
TOOL_TIMEOUT = 15
MAX_WRITE_BYTES = 256 * 1024

# How long a write waits for a human. The panel can be dismissed with a turn in
# flight, and a tool call blocked forever on a closed sidebar is a process that
# never exits. Silence is a no.
APPROVE_TIMEOUT = 180

DEFAULT_ROOTS = "~/dev:~/.config:~/.local/state/neu"

# Deny wins over the allowlist, always. Matched against every path component so
# a root that happens to contain ~/.config/neu/llm.env still cannot serve it.
DENY_GLOBS = [
    ".ssh", ".gnupg", ".password-store", ".age", ".aws", ".docker", ".kube",
    "*.key", "*.pem", "*.p12", "*.pfx", "*.gpg", "*.kdbx", "*.jks",
    "id_rsa*", "id_ed25519*", "id_ecdsa*", "*.env", ".env*", ".netrc",
    ".git-credentials", "credentials*", "*secret*", "*token*", "*password*",
    "shadow", "*.sqlite-wal",
]


def roots() -> list[Path]:
    raw = os.environ.get("NEU_LLM_ROOTS", DEFAULT_ROOTS)
    out = []
    for part in raw.split(":"):
        part = part.strip()
        if not part:
            continue
        try:
            out.append(Path(part).expanduser().resolve())
        except OSError:
            continue
    return out


# ------------------------------------------------------------------ output --

try:
    sys.stdout.reconfigure(encoding="utf-8")   # the panel parses UTF-8 lines
except (AttributeError, OSError):
    pass


def emit(**event) -> None:
    """One NDJSON event per line. The panel reads these with a SplitParser."""
    try:
        sys.stdout.write(json.dumps(event, ensure_ascii=False) + "\n")
        sys.stdout.flush()
    except BrokenPipeError:
        # Whoever was reading us is gone -- the panel closed, or the shell
        # reloaded. There is nobody to tell, so stop rather than unwind through
        # every caller printing tracebacks at a closed pipe.
        os._exit(0)


def audit(name: str, args: dict, verdict: str) -> None:
    """Every tool call, allowed or refused, lands in a file you can read later.

    A sidebar that quietly reads files is only trustworthy if there is a record
    of what it read.
    """
    try:
        STATE_DIR.mkdir(parents=True, exist_ok=True)
        line = json.dumps({"ts": time.strftime("%F %T"), "tool": name,
                           "args": args, "verdict": verdict})
        with (STATE_DIR / "tools.log").open("a") as fh:
            fh.write(line + "\n")
    except OSError:
        pass  # an unwritable log must never take the chat down


# ----------------------------------------------------------------- sandbox --

class Denied(Exception):
    """A path the tools refuse to touch. The message goes back to the model."""


def safe_path(raw: str, must_be_dir: bool = False) -> Path:
    """Resolve `raw` and prove it sits inside an allowed root.

    resolve() first, check second: the check has to run on the real path or a
    symlink inside an allowed root would be a door out of it.
    """
    if not raw or not str(raw).strip():
        raise Denied("no path given")
    try:
        p = Path(str(raw)).expanduser().resolve()
    except (OSError, RuntimeError) as exc:
        raise Denied(f"cannot resolve {raw}: {exc}") from exc

    allowed = roots()
    if not any(p == r or r in p.parents for r in allowed):
        raise Denied(f"{p} is outside the allowed roots "
                     f"({', '.join(str(r) for r in allowed)})")

    for part in p.parts:
        low = part.lower()
        for pat in DENY_GLOBS:
            if fnmatch.fnmatch(low, pat):
                raise Denied(f"{part} is on the deny list (secrets are not readable)")

    if not p.exists():
        raise Denied(f"{p} does not exist")
    if must_be_dir and not p.is_dir():
        raise Denied(f"{p} is not a directory")
    if not must_be_dir and p.is_dir():
        raise Denied(f"{p} is a directory -- use list_dir")
    return p


def write_path(raw: str) -> tuple[Path, bool]:
    """Resolve a path to write to, and say whether it is free of charge.

    The scratch directory is the only place the model may write unasked, so it
    is checked on the RESOLVED path -- "~/dev/llm-scratch/../../.bashrc" is not
    in the scratch directory no matter how it is spelled. Everything else in the
    roots is writable only with a human's say-so, and the deny list is absolute:
    no approval makes ~/.ssh or a *.env file writable.
    """
    if not raw or not str(raw).strip():
        raise Denied("no path given")
    try:
        p = Path(str(raw)).expanduser()
        p = (p if p.is_absolute() else SCRATCH / p).resolve()
    except (OSError, RuntimeError) as exc:
        raise Denied(f"cannot resolve {raw}: {exc}") from exc

    for part in p.parts:
        low = part.lower()
        for pat in DENY_GLOBS:
            if fnmatch.fnmatch(low, pat):
                raise Denied(f"{part} is on the deny list and is never writable")

    scratch = SCRATCH.resolve() if SCRATCH.exists() else SCRATCH
    if p == scratch or scratch in p.parents:
        return p, True

    if not any(p == r or r in p.parents for r in roots()):
        raise Denied(f"{p} is outside the allowed roots -- write it under "
                     f"{SCRATCH} instead")
    return p, False


def write_preview(p: Path, content: str) -> str:
    """What the human is being asked to agree to, in a few lines."""
    new_lines = content.splitlines()
    if p.exists():
        try:
            old_lines = p.read_text(errors="replace").splitlines()
        except OSError:
            old_lines = []
        diff = list(difflib.unified_diff(old_lines, new_lines,
                                         fromfile="current", tofile="proposed",
                                         lineterm="", n=1))
        body = "\n".join(diff[:30]) or "(identical)"
        return f"overwrites {len(old_lines)} lines\n{body}"
    head = "\n".join(new_lines[:12])
    more = "" if len(new_lines) <= 12 else f"\n… {len(new_lines) - 12} more lines"
    return f"new file, {len(new_lines)} lines\n{head}{more}"


def tool_write_file(path: str = "", content: str = "", **_) -> str:
    if not CAN_WRITE:
        return "denied: writing is turned off (NEU_LLM_WRITE=0)"
    if len(content.encode("utf-8")) > MAX_WRITE_BYTES:
        return f"error: refusing to write more than {MAX_WRITE_BYTES} bytes"

    p, free = write_path(path)
    if not free:
        verdict = APPROVER({"tool": "write_file", "path": str(p),
                            "preview": write_preview(p, content),
                            "bytes": len(content.encode("utf-8"))})
        if not verdict:
            audit("write_file", {"path": str(p)}, "declined by operator")
            return (f"denied: the operator declined the write to {p}. Do not try "
                    f"another path -- ask them what they want instead.")

    try:
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(content)
    except OSError as exc:
        return f"error: {exc}"
    audit("write_file", {"path": str(p)}, "auto (scratch)" if free
          else ("approved (auto-approve on)" if AUTO_ANSWER[0] else "approved by operator"))
    return f"wrote {len(content.splitlines())} lines to {p}"


def run(cmd: list[str], cwd: Path | None = None) -> str:
    """argv only, never a shell string: nothing the model emits reaches sh."""
    try:
        cp = subprocess.run(cmd, cwd=str(cwd) if cwd else None, timeout=TOOL_TIMEOUT,
                            capture_output=True, text=True, check=False)
    except FileNotFoundError:
        return f"error: {cmd[0]} is not installed"
    except subprocess.TimeoutExpired:
        return f"error: {cmd[0]} timed out after {TOOL_TIMEOUT}s"
    out = (cp.stdout or "") + (cp.stderr or "")
    return out.strip() or "(no output)"


# ------------------------------------------------------------------- tools --

def tool_list_dir(path: str = ".", **_) -> str:
    p = safe_path(path, must_be_dir=True)
    rows = []
    for entry in sorted(p.iterdir(), key=lambda e: (not e.is_dir(), e.name.lower())):
        if entry.name.startswith(".") and entry.name not in (".config",):
            continue
        try:
            size = entry.stat().st_size
        except OSError:
            size = 0
        rows.append(f"{'dir ' if entry.is_dir() else 'file'}  {entry.name}"
                    + ("" if entry.is_dir() else f"  ({size}b)"))
        if len(rows) >= 200:
            rows.append("... truncated at 200 entries")
            break
    return f"{p}:\n" + ("\n".join(rows) if rows else "(empty)")


def tool_read_file(path: str = "", start: int = 1, lines: int = MAX_READ_LINES, **_) -> str:
    p = safe_path(path)
    try:
        if p.stat().st_size > MAX_READ_BYTES * 8:
            return f"error: {p} is too large to read ({p.stat().st_size}b)"
        text = p.read_text(errors="replace")
    except OSError as exc:
        return f"error: {exc}"
    all_lines = text.splitlines()
    start = max(1, int(start or 1))
    lines = max(1, min(int(lines or MAX_READ_LINES), MAX_READ_LINES))
    chunk = all_lines[start - 1:start - 1 + lines]
    body = "\n".join(f"{start + i}\t{ln}" for i, ln in enumerate(chunk))
    if len(body) > MAX_READ_BYTES:
        body = body[:MAX_READ_BYTES] + "\n... truncated"
    tail = "" if start - 1 + len(chunk) >= len(all_lines) else \
        f"\n... {len(all_lines) - (start - 1 + len(chunk))} more lines"
    return f"{p} ({len(all_lines)} lines):\n{body}{tail}"


def tool_search_files(pattern: str = "", path: str = ".", glob: str = "", **_) -> str:
    if not pattern:
        return "error: no pattern given"
    p = safe_path(path, must_be_dir=True)
    cmd = ["rg", "--line-number", "--no-heading", "--color=never",
           "--max-count=5", "--max-filesize=1M", "-e", str(pattern)]
    if glob:
        cmd += ["--glob", str(glob)]
    out = run(cmd + ["--", "."], cwd=p)
    rows = out.splitlines()
    if len(rows) > MAX_MATCHES:
        rows = rows[:MAX_MATCHES] + [f"... {len(out.splitlines()) - MAX_MATCHES} more matches"]
    return "\n".join(rows) if rows else "(no matches)"


def tool_git_info(repo: str = ".", what: str = "status", **_) -> str:
    p = safe_path(repo, must_be_dir=True)
    what = (what or "status").lower()
    if what == "log":
        return run(["git", "log", "--oneline", "-15"], cwd=p)
    if what == "diff":
        return run(["git", "--no-pager", "diff", "--stat"], cwd=p)
    if what == "branch":
        return run(["git", "branch", "--show-current"], cwd=p)
    return run(["git", "status", "--short", "--branch"], cwd=p)


def tool_system_status(**_) -> str:
    """The desktop's own numbers -- the one thing a terminal LLM cannot answer."""
    return run(["neu_sysinfo.sh"])


TOOLS = {
    "list_dir": (tool_list_dir, {
        "description": "List the files and directories at a path.",
        "properties": {"path": {"type": "string", "description": "Directory path."}},
        "required": ["path"],
    }),
    "read_file": (tool_read_file, {
        "description": "Read a text file, with line numbers. Returns at most "
                       f"{MAX_READ_LINES} lines; pass start to page further in.",
        "properties": {
            "path": {"type": "string", "description": "File path."},
            "start": {"type": "integer", "description": "First line, 1-based."},
            "lines": {"type": "integer", "description": "How many lines to read."},
        },
        "required": ["path"],
    }),
    "search_files": (tool_search_files, {
        "description": "Search file contents for a regular expression (ripgrep).",
        "properties": {
            "pattern": {"type": "string", "description": "Regular expression."},
            "path": {"type": "string", "description": "Directory to search in."},
            "glob": {"type": "string", "description": "Optional filename glob, e.g. *.qml"},
        },
        "required": ["pattern"],
    }),
    "git_info": (tool_git_info, {
        "description": "Read-only git state for a repository.",
        "properties": {
            "repo": {"type": "string", "description": "Path inside the repository."},
            "what": {"type": "string", "enum": ["status", "log", "diff", "branch"]},
        },
        "required": ["repo", "what"],
    }),
    "write_file": (tool_write_file, {
        "description": "Write a text file. Call it directly, whatever the path: "
                       f"under the scratch directory ({SCRATCH}) -- where a "
                       "relative path goes -- it is written at once, and "
                       "anywhere else the operator is shown a diff and approves "
                       "or declines it themselves. Overwrites what is there.",
        "properties": {
            "path": {"type": "string",
                     "description": "File path, or a bare name for scratch."},
            "content": {"type": "string", "description": "Full file contents."},
        },
        "required": ["path", "content"],
    }),
    "system_status": (tool_system_status, {
        "description": "This desktop's battery, network, volume, cpu, memory and "
                       "disk, as JSON.",
        "properties": {},
        "required": [],
    }),
}


def tool_schema() -> list[dict]:
    return [{"type": "function",
             "function": {"name": name,
                          "description": spec["description"],
                          "parameters": {"type": "object",
                                         "properties": spec["properties"],
                                         "required": spec["required"]}}}
            for name, (_, spec) in TOOLS.items()]


def deny_all(_request: dict) -> bool:
    """Terminal default: nobody is watching, so nothing outside scratch lands."""
    return False


def approve_all(_request: dict) -> bool:
    return True


def ask_panel(request: dict) -> bool:
    """Put the write in front of the human and block until they answer.

    The panel is the only thing on the other end of stdin during a turn, so the
    request goes out as an event and the reply comes back as one line of JSON.
    """
    emit(t="approve", id=APPROVAL_ID[0], **request)
    deadline = time.monotonic() + APPROVE_TIMEOUT
    while time.monotonic() < deadline:
        ready, _, _ = select.select([sys.stdin], [], [],
                                    max(0.0, deadline - time.monotonic()))
        if not ready:
            break
        line = sys.stdin.readline()
        if line == "":       # the panel went away
            break
        line = line.strip()
        if not line:
            continue
        try:
            msg = json.loads(line)
        except json.JSONDecodeError:
            continue
        if str(msg.get("id", "")) == str(APPROVAL_ID[0]):
            AUTO_ANSWER[0] = bool(msg.get("auto"))
            return bool(msg.get("approve"))
    emit(t="approve_timeout", id=APPROVAL_ID[0])
    return False


APPROVER = deny_all
APPROVAL_ID = [""]     # the tool call currently awaiting an answer
AUTO_ANSWER = [False]  # was the last yes a person's, or a held-open gate?


def call_tool(name: str, args: dict) -> str:
    fn = TOOLS.get(name)
    if fn is None:
        audit(name, args, "unknown")
        return f"error: no such tool {name}"
    try:
        result = fn[0](**args) if isinstance(args, dict) else fn[0]()
        # write_file records its own verdict (auto / approved / declined), which
        # is the more useful line; a generic "ok" beside it is just noise.
        if name != "write_file":
            audit(name, args, "ok")
        return result
    except Denied as exc:
        audit(name, args, f"denied: {exc}")
        return f"denied: {exc}"
    except TypeError as exc:
        audit(name, args, f"bad args: {exc}")
        return f"error: bad arguments -- {exc}"
    except Exception as exc:  # a tool must never take the turn down
        audit(name, args, f"error: {exc}")
        return f"error: {exc}"


# ----------------------------------------------------------------- history --

def conv_path(conv: str) -> Path:
    safe = "".join(c for c in conv if c.isalnum() or c in "-_") or "default"
    return STATE_DIR / f"{safe}.jsonl"


def load_history(conv: str) -> list[dict]:
    path = conv_path(conv)
    if not path.exists():
        return []
    out = []
    for line in path.read_text(errors="replace").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            out.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    return out


def append_history(conv: str, message: dict) -> None:
    path = conv_path(conv)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a") as fh:
        fh.write(json.dumps(message, ensure_ascii=False) + "\n")


SYSTEM_PROMPT = (
    "You are the assistant docked in jwbla's Hyprland desktop (Arch Linux, "
    "quickshell bar and panels, tmux, zsh). Answer briefly and concretely -- "
    "this is a narrow sidebar, not a document. "
    "You have read-only tools for the filesystem, ripgrep, git and this "
    "machine's own sensors; use them instead of guessing, and say plainly when "
    "a path is denied rather than trying another way around it. "
    "Never claim to have done something you have not: say what the tools "
    "actually returned. "
    "Do not ask for permission in prose. Writing outside the scratch directory "
    "puts the request in front of the operator by itself, with a diff, and they "
    "can decline it -- so call the tool and let them answer there. Asking first "
    "in text only makes them answer twice."
)


# ------------------------------------------------------------------ client --

def short_error(exc: Exception) -> str:
    """One line, because the panel header has one line.

    requests raises three lines of urllib3 internals for "nothing is listening",
    and the only fact in there worth showing is which endpoint stayed quiet --
    which the panel already knows.
    """
    if isinstance(exc, requests.exceptions.ConnectionError):
        return "nothing listening"
    if isinstance(exc, requests.exceptions.Timeout):
        return "timed out"
    text = str(exc).strip().splitlines()
    return (text[0][:90] if text else exc.__class__.__name__)


def headers() -> dict:
    h = {"Content-Type": "application/json"}
    if API_KEY:
        h["Authorization"] = f"Bearer {API_KEY}"
    # Job declaration for the compute gateway (RGTVINFRA-K-e7c8ff). Ignored by
    # LM Studio, so NEU_LLM_URL can point at either and this file does not
    # branch -- which is the whole reason the gateway speaks the same protocol.
    #
    # INTERACTIVE is the one that matters here. This panel is bound to a
    # keystroke, so it must never be queued behind a bake that holds the card
    # for twenty minutes. The gateway either lets it through or refuses it
    # quickly; what it must not do is make the user wait silently.
    #
    # Deliberately NO cache key: a chat turn depends on the conversation so far,
    # so there is nothing here worth serving twice.
    h["X-Compute-Job"] = "neu-llm.panel"
    h["X-Compute-Interactive"] = "true"
    h["X-Compute-Expect-Seconds"] = "30"
    return h


# Does this endpoint have a queue in front of it? None until we have looked,
# False for a bare LM Studio -- which 404s /v1/queue -- and True for the
# gateway. Asked once per process: the answer cannot change under a running
# turn, and probing before each of six tool round-trips would be five wasted
# requests against an endpoint that has already said it has no queue.
HAS_QUEUE: bool | None = None


def queue_wait() -> str:
    """Why nothing is happening yet, in one sentence, or "" to stay quiet.

    The gateway's drop-in BLOCKS: it holds the connection through the queue and
    the whole generation, then answers in one piece, so there is no position to
    read off a response we have not received. A panel that just sits there is
    indistinguishable from a crashed one, and GET /v1/queue -- which is not
    itself queued -- is the only thing that can say otherwise.

    Every failure here is silence, deliberately. A plain LM Studio 404s this
    path and has to go on behaving exactly as it always did; and if the box is
    genuinely down, the chat request a moment later says so far better than a
    probe could.
    """
    global HAS_QUEUE
    if HAS_QUEUE is False:
        return ""
    try:
        r = requests.get(f"{BASE_URL}/queue", timeout=CONNECT_TIMEOUT)
        q = r.json() if r.ok else None
    except Exception:
        q = None
    if not isinstance(q, dict):
        HAS_QUEUE = False
        return ""
    HAS_QUEUE = True

    running = [j for j in (q.get("running") or []) if isinstance(j, dict)]
    queued = [j for j in (q.get("queued") or []) if isinstance(j, dict)]
    if not running:
        return ""  # card is free; anything queued sorts behind us anyway

    # What we wait for is the job HOLDING the card, not the length of the line
    # behind it: we declare ourselves interactive, so we go to the front of the
    # queue, but nothing interrupts work already in flight. Naming the model is
    # the useful part -- a different one there is exactly the eviction the
    # gateway exists to stop, and explains a slow answer even after our turn.
    what = running[0].get("model") or running[0].get("kind") or "another job"

    # The remaining time on the card is not published for a running job, but
    # the job at the head of the queue is waiting for precisely that and its
    # eta_seconds says so. Borrow it when there is one, and say nothing rather
    # than guess when there is not.
    eta = queued[0].get("eta_seconds") if queued else None
    left = f", about {int(eta)}s left" if isinstance(eta, (int, float)) and eta > 0 else ""
    behind = f"; {len(queued)} waiting behind it" if queued else ""
    return f"the GPU is busy with {what}{left} -- you are next{behind}"


MODEL_FILE = STATE_DIR / "model"


def remembered_model() -> str:
    """The panel's dropdown choice, which has to outlive a shell restart."""
    try:
        return MODEL_FILE.read_text().strip()
    except OSError:
        return ""


def remember_model(name: str) -> None:
    MODEL_FILE.parent.mkdir(parents=True, exist_ok=True)
    MODEL_FILE.write_text(name.strip() + "\n")


def catalogue() -> list[dict]:
    """Every model on the box, with its type and whether it is hot.

    LM Studio's own /api/v0/models says both, and "loaded vs not-loaded" is the
    difference between an answer in two seconds and a minute of JIT loading a
    120b -- worth showing in the picker. Anything else OpenAI-compatible only
    has /v1/models, which is a list of ids and no more.
    """
    try:
        r = requests.get(f"{BASE_URL.rsplit('/v1', 1)[0]}/api/v0/models",
                         headers=headers(), timeout=CONNECT_TIMEOUT)
        if r.ok:
            out = []
            for m in r.json().get("data") or []:
                kind = m.get("type", "llm")
                if kind == "embeddings":
                    continue  # cannot hold a conversation with an embedder
                out.append({"id": m.get("id", ""), "type": kind,
                            "state": m.get("state", ""),
                            "ctx": m.get("max_context_length", 0)})
            if out:
                return out
    except Exception:
        pass

    try:
        r = requests.get(f"{BASE_URL}/models", headers=headers(), timeout=CONNECT_TIMEOUT)
        r.raise_for_status()
        return [{"id": m.get("id", ""), "type": "llm", "state": "", "ctx": 0}
                for m in (r.json().get("data") or [])]
    except Exception:
        return []


def loaded_model(found: list[dict] | None = None) -> str:
    """Whatever the box currently holds in memory, if anything."""
    for m in (found if found is not None else catalogue()):
        if m["state"] in ("loaded", "loading") and m["type"] in ("llm", "vlm"):
            return m["id"]
    return ""


def resolve_model(override: str = "") -> str:
    """Explicit pick, then the environment, then the box, then a remembered one.

    The loaded model outranks the remembered one on purpose: the server holds
    one at a time, so naming a different one costs an eviction and a minute of
    loading. An explicit --model still wins -- that IS the request to switch.
    """
    for candidate in (override, MODEL):
        if candidate:
            return candidate

    found = catalogue()
    hot = loaded_model(found)
    remembered = remembered_model()
    if remembered:
        if not hot or remembered == hot:
            return remembered
        return hot
    # Nothing chosen yet. Prefer one already in VRAM -- picking a cold 120b as
    # a default means the first question of the day takes four minutes.
    found = catalogue()
    if hot:
        return hot
    for m in found:
        if m["type"] == "llm" and m["id"]:
            return m["id"]
    return found[0]["id"] if found else "local-model"


def stream_turn(model: str, messages: list[dict], stats: dict | None = None) -> dict:
    """One request. Streams tokens out as they land, returns the finished message.

    Two things make this more than a loop over lines: reasoning models put their
    thinking in a separate delta field (LM Studio exposes gpt-oss's analysis
    channel as `reasoning` or `reasoning_content` depending on build), and
    tool calls arrive as fragments keyed by index that have to be concatenated
    before the arguments parse as JSON.
    """
    body = {
        "model": model,
        "messages": messages,
        "stream": True,
        "temperature": 0.4,
        # The server counts tokens properly; asking beats guessing from the
        # number of chunks, which is only ever an approximation of one token.
        "stream_options": {"include_usage": True},
    }
    if USE_TOOLS:
        body["tools"] = tool_schema()
        body["tool_choice"] = "auto"

    content: list[str] = []
    calls: dict[int, dict] = {}
    finish = None

    # Asked BEFORE the request, because afterwards there is nothing to ask: the
    # drop-in blocks and we would be reading the queue from inside our own wait
    # on it. One line now is the difference between "the GPU is busy" and a
    # panel that looks hung. Silent against anything without a queue.
    waiting = queue_wait()
    if waiting:
        emit(t="wait", msg=waiting)

    with requests.post(f"{BASE_URL}/chat/completions", headers=headers(),
                       json=body, stream=True,
                       timeout=(CONNECT_TIMEOUT, READ_TIMEOUT)) as resp:
        if resp.status_code in (429, 503):
            # NOT "the GPU is busy". The gateway never refuses for that -- it
            # queues, which is the whole point of it, and being busy is what
            # the wait line above reports. 429/503 here means the endpoint
            # itself is unwilling: a gateway shutting down, or a hosted
            # OpenAI-compatible server rate-limiting us. Say the true thing.
            raise RuntimeError(
                f"{BASE_URL} is not taking requests right now "
                f"({resp.status_code}) -- try again shortly"
            )
        if resp.status_code >= 400:
            raise RuntimeError(f"{resp.status_code} {resp.text[:300]}")
        # requests falls back to ISO-8859-1 for any text/* without an explicit
        # charset, and text/event-stream almost never carries one -- which
        # silently turns every apostrophe and em dash the model writes into
        # mojibake. SSE is UTF-8 by specification; say so.
        resp.encoding = "utf-8"
        # chunk_size=1: iter_lines otherwise waits for its 512-byte buffer to
        # fill before yielding anything, so a slow first token and a fast one
        # look identical and the words arrive in clumps. SSE wants them as they
        # land, which costs a little more syscall traffic and is worth it.
        for raw in resp.iter_lines(decode_unicode=True, chunk_size=1):
            if not raw or not raw.startswith("data:"):
                continue
            payload = raw[5:].strip()
            if payload == "[DONE]":
                break
            try:
                chunk = json.loads(payload)
            except json.JSONDecodeError:
                continue
            # The usage chunk arrives last and carries no choices.
            usage = chunk.get("usage")
            if usage and stats is not None:
                stats["input"] = stats.get("input", 0) + (usage.get("prompt_tokens") or 0)
                stats["output"] = stats.get("output", 0) + (usage.get("completion_tokens") or 0)
                stats["counted"] = True

            choice = (chunk.get("choices") or [{}])[0]
            finish = choice.get("finish_reason") or finish
            delta = choice.get("delta") or {}

            think = delta.get("reasoning") or delta.get("reasoning_content")
            if think:
                if stats is not None:
                    stats.setdefault("first_at", time.monotonic())
                    stats["chunks"] = stats.get("chunks", 0) + 1
                emit(t="reasoning", v=think)

            piece = delta.get("content")
            if piece:
                if stats is not None:
                    stats.setdefault("first_at", time.monotonic())
                    stats["chunks"] = stats.get("chunks", 0) + 1
                content.append(piece)
                emit(t="token", v=piece)

            for frag in delta.get("tool_calls") or []:
                idx = frag.get("index", 0)
                slot = calls.setdefault(idx, {"id": "", "name": "", "args": ""})
                if frag.get("id"):
                    slot["id"] = frag["id"]
                fn = frag.get("function") or {}
                if fn.get("name"):
                    slot["name"] = fn["name"]
                if fn.get("arguments"):
                    slot["args"] += fn["arguments"]

    message: dict = {"role": "assistant", "content": "".join(content)}
    if calls:
        message["tool_calls"] = [
            {"id": c["id"] or f"call_{i}", "type": "function",
             "function": {"name": c["name"], "arguments": c["args"] or "{}"}}
            for i, c in sorted(calls.items())
        ]
    message["_finish"] = finish
    return message


def emit_stats(stats: dict) -> None:
    """What the turn cost, in the two units that matter: seconds and tokens.

    Time-to-first-token and generation rate are separate numbers on purpose. A
    slow answer from a cold model is nearly all TTFT and says nothing about the
    model's speed; a slow answer from a hot one is the rate. Reporting only the
    total would blur the two and make every cold start look like a slow model.
    """
    now = time.monotonic()
    total_ms = int((now - stats.get("started", now)) * 1000)
    first = stats.get("first_at")
    ttft_ms = int((first - stats["started"]) * 1000) if first else None
    out = stats.get("output") or 0
    if not stats.get("counted"):
        # No usage from the server: chunks are the honest fallback, and the
        # panel is told so rather than being handed a number that looks exact.
        out = stats.get("chunks", 0)
    gen_s = max(0.001, (now - (first or stats.get("started", now))))
    emit(t="stats", ms=total_ms, ttft_ms=ttft_ms,
         input=stats.get("input") or 0, output=out,
         tps=round(out / gen_s, 1), exact=bool(stats.get("counted")))


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("prompt", nargs="*", help="the message; omit with --stdin")
    ap.add_argument("--stdin", action="store_true",
                    help="read the message from stdin (keeps it out of ps)")
    ap.add_argument("--conv", default="default", help="conversation id")
    ap.add_argument("--reset", action="store_true", help="forget this conversation first")
    ap.add_argument("--history", action="store_true",
                    help="print the stored conversation as NDJSON and exit")
    ap.add_argument("--probe", action="store_true",
                    help="check the endpoint and print the model list, then exit")
    ap.add_argument("--model", default="",
                    help="model id for this turn, overriding the remembered one")
    ap.add_argument("--select", default="",
                    help="remember this model for later turns, then exit")
    ap.add_argument("--panel", action="store_true",
                    help="protocol mode: stdin carries JSON lines -- the prompt "
                         "first, then approvals. Used by the quickshell sidebar.")
    ap.add_argument("--yes", action="store_true",
                    help="approve writes outside the scratch directory without "
                         "asking. Only meaningful in terminal mode.")
    ap.add_argument("--end-session", action="store_true",
                    help="forget this conversation. Nothing else to tear down: "
                         "the builtin holds no server and no daemon.")
    args = ap.parse_args()

    STATE_DIR.mkdir(parents=True, exist_ok=True)

    if args.select:
        remember_model(args.select)
        emit(t="selected", model=args.select)
        return 0

    if args.probe:
        try:
            r = requests.get(f"{BASE_URL}/models", headers=headers(),
                             timeout=CONNECT_TIMEOUT)
            r.raise_for_status()
            emit(t="probe", ok=True, endpoint=BASE_URL, current=resolve_model(),
                 models=catalogue())
            return 0
        except Exception as exc:
            emit(t="probe", ok=False, endpoint=BASE_URL, msg=short_error(exc))
            return 1

    if args.end_session:
        conv_path(args.conv).unlink(missing_ok=True)
        emit(t="session_ended", harness="builtin", stopped=False)
        return 0

    if args.reset:
        conv_path(args.conv).unlink(missing_ok=True)

    if args.history:
        for m in load_history(args.conv):
            emit(t="history", m=m)
        emit(t="done", conv=args.conv)
        return 0

    # Three ways in, one meaning. The panel keeps stdin OPEN after the prompt
    # so a write can be put to a human mid-turn; the terminal closes it, and
    # says so by answering every such request itself.
    global APPROVER
    if args.panel:
        APPROVER = ask_panel
        first = sys.stdin.readline()
        try:
            text = (json.loads(first or "{}").get("prompt") or "").strip()
        except json.JSONDecodeError:
            text = first.strip()
    else:
        APPROVER = approve_all if args.yes else deny_all
        text = sys.stdin.read().strip() if args.stdin else " ".join(args.prompt).strip()

    if not text:
        emit(t="error", msg="empty prompt")
        return 2

    history = load_history(args.conv)
    user = {"role": "user", "content": text}
    append_history(args.conv, user)

    model = resolve_model(args.model)
    emit(t="start", conv=args.conv, model=model, endpoint=BASE_URL)

    # Only whole turns go back to the model, and only the last few: a 20b model
    # loses the plot long before it runs out of context, and tool output from
    # ten questions ago is noise by now.
    convo = [{"role": "system", "content": SYSTEM_PROMPT}]
    convo += [{k: v for k, v in m.items() if not k.startswith("_")}
              for m in history[-CTX_TURNS * 2:]]
    convo.append(user)

    started = time.monotonic()
    stats: dict = {"started": started}
    try:
        for _ in range(MAX_STEPS):
            reply = stream_turn(model, convo, stats)
            calls = reply.get("tool_calls") or []
            stored = {k: v for k, v in reply.items() if not k.startswith("_")}
            convo.append(stored)
            append_history(args.conv, stored)

            if not calls:
                break

            for call in calls:
                name = call["function"]["name"]
                try:
                    cargs = json.loads(call["function"]["arguments"] or "{}")
                except json.JSONDecodeError:
                    cargs = {}
                APPROVAL_ID[0] = call["id"]
                emit(t="tool", id=call["id"], name=name, args=cargs)
                result = call_tool(name, cargs)
                emit(t="tool_result", id=call["id"], name=name,
                     ok=not result.startswith(("error:", "denied:")),
                     summary=result.splitlines()[0][:160] if result else "")
                msg = {"role": "tool", "tool_call_id": call["id"],
                       "name": name, "content": result}
                convo.append(msg)
                append_history(args.conv, msg)
        else:
            emit(t="error", msg=f"gave up after {MAX_STEPS} tool rounds")
    except requests.exceptions.ConnectionError:
        emit(t="error", msg=f"no answer from {BASE_URL} -- is the server running "
                            "and serving on the network?")
        return 1
    except requests.exceptions.ReadTimeout:
        emit(t="error", msg=f"{BASE_URL} went quiet for {READ_TIMEOUT}s")
        return 1
    except KeyboardInterrupt:
        emit(t="error", msg="cancelled")
        return 130
    except Exception as exc:
        emit(t="error", msg=str(exc))
        return 1

    emit_stats(stats)
    emit(t="done", conv=args.conv, ms=int((time.monotonic() - started) * 1000))
    return 0


if __name__ == "__main__":
    sys.exit(main())
