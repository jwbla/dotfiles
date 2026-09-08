#!/usr/bin/env python3
"""Drive pi.dev's coding agent, speaking the neu sidebar's protocol.

pi is a real harness: Read, Write, Edit and Bash, its own agent loop, sessions,
TypeScript extensions. It already runs headless -- `pi --mode rpc` is JSONL over
stdin and stdout, bidirectional, with dialog requests the client answers. That
is the same shape bin/neu-llm.py defines for the panel, so this file is a
translator and almost nothing else:

    pi                          ->   the sidebar
    text_delta                  ->   {"t":"token"}
    thinking_delta              ->   {"t":"reasoning"}
    tool_execution_start/end    ->   {"t":"tool"} / {"t":"tool_result"}
    extension_ui_request        ->   {"t":"approve"}  -> the approval card
    agent_end                   ->   {"t":"done"}

The same CLI as the builtin, so bin/neu-llm-harness.sh can hand either of them
the identical arguments:

    neu-llm-pi.py --panel --conv default --model openai/gpt-oss-120b
    echo 'what changed here?' | neu-llm-pi.py --stdin

WHY THE PERMISSIONS ARE PI'S AND NOT OURS: the builtin refuses writes in code
because it owns its tools. pi owns its own, and gates them through the dialogs
its extensions raise -- so the honest thing is to surface those dialogs rather
than pretend to a sandbox we are no longer enforcing. A turn under pi can run
bash. That is the trade for a harness that can actually do the work.

    NEU_LLM_URL          endpoint, as for the builtin (read from llm.env)
    NEU_LLM_PI_PROVIDER  pi provider name           (default openai)
    NEU_LLM_PI_ARGS      extra arguments for pi, split on spaces
"""

from __future__ import annotations

import argparse
import json
import os
import select
import shutil
import subprocess
import sys
import time
from pathlib import Path

try:
    sys.stdout.reconfigure(encoding="utf-8")
except (AttributeError, OSError):
    pass

STATE_DIR = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "neu/llm"
ENV_FILE = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "neu/llm.env"
MODEL_FILE = STATE_DIR / "model"

APPROVE_TIMEOUT = 180
START_TIMEOUT = 30


def load_env_file(path: Path = ENV_FILE) -> None:
    """Same file the builtin reads, so one endpoint serves every harness."""
    try:
        raw = path.read_text()
    except OSError:
        return
    for line in raw.splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, val = line.partition("=")
        key = key.strip().removeprefix("export ").strip()
        val = val.strip()
        if len(val) >= 2 and val[0] == val[-1] and val[0] in "\"'":
            val = val[1:-1]
        if key and key not in os.environ:
            os.environ[key] = val


load_env_file()

BASE_URL = os.environ.get("NEU_LLM_URL", "http://localhost:1234/v1").rstrip("/")
PROVIDER = os.environ.get("NEU_LLM_PI_PROVIDER", "openai")
EXTRA_ARGS = [a for a in os.environ.get("NEU_LLM_PI_ARGS", "").split(" ") if a]


def emit(**event) -> None:
    try:
        sys.stdout.write(json.dumps(event, ensure_ascii=False) + "\n")
        sys.stdout.flush()
    except BrokenPipeError:
        # Whoever was reading us is gone -- the panel closed, or the shell
        # reloaded. There is nobody to tell, so stop rather than unwind through
        # every caller printing tracebacks at a closed pipe.
        os._exit(0)


def remembered_model() -> str:
    try:
        return MODEL_FILE.read_text().strip()
    except OSError:
        return ""


def loaded_model() -> str:
    """Whatever the endpoint currently holds, which outranks a stale memory."""
    try:
        import requests
        r = requests.get(f"{BASE_URL.rsplit('/v1', 1)[0]}/api/v0/models", timeout=5)
        for m in r.json().get("data", []):
            if m.get("state") in ("loaded", "loading") and m.get("type") in ("llm", "vlm"):
                return m["id"]
    except Exception:
        pass
    return ""


def audit(tool: str, args: dict, verdict: str) -> None:
    try:
        STATE_DIR.mkdir(parents=True, exist_ok=True)
        with (STATE_DIR / "tools.log").open("a") as fh:
            fh.write(json.dumps({"ts": time.strftime("%F %T"), "harness": "pi",
                                 "tool": tool, "args": args,
                                 "verdict": verdict}) + "\n")
    except OSError:
        pass


# ------------------------------------------------------------------ the pipe --

class Pi:
    """pi in RPC mode, with the two things a translator needs: send and read."""

    def __init__(self, model: str, session_dir: Path):
        cmd = ["pi", "--mode", "rpc", "--session-dir", str(session_dir)]
        if PROVIDER:
            cmd += ["--provider", PROVIDER]
        if model:
            cmd += ["--model", model]
        cmd += EXTRA_ARGS

        env = dict(os.environ)
        # pi reaches an OpenAI-compatible server the same way everything else
        # does; the endpoint in llm.env is the single source of truth.
        env.setdefault("OPENAI_BASE_URL", BASE_URL)
        env.setdefault("OPENAI_API_KEY", os.environ.get("NEU_LLM_KEY", "local"))

        self.proc = subprocess.Popen(
            cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
            stderr=subprocess.PIPE, text=True, env=env, bufsize=1)

    def send(self, **command) -> None:
        if self.proc.stdin is None or self.proc.poll() is not None:
            return
        try:
            self.proc.stdin.write(json.dumps(command) + "\n")
            self.proc.stdin.flush()
        except (BrokenPipeError, ValueError):
            pass

    def events(self):
        assert self.proc.stdout is not None
        for line in self.proc.stdout:
            line = line.strip()
            if not line:
                continue
            try:
                yield json.loads(line)
            except json.JSONDecodeError:
                continue

    def stop(self) -> None:
        self.send(type="abort")
        try:
            self.proc.stdin and self.proc.stdin.close()
        except Exception:
            pass
        try:
            self.proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            self.proc.kill()


# ---------------------------------------------------------------- approvals --

AUTO_ANSWER = [False]  # was the last yes a person's, or a held-open gate?


def ask_panel(request: dict) -> bool:
    """Put pi's dialog on the sidebar and block until someone answers."""
    emit(t="approve", **request)
    deadline = time.monotonic() + APPROVE_TIMEOUT
    while time.monotonic() < deadline:
        ready, _, _ = select.select([sys.stdin], [], [],
                                    max(0.0, deadline - time.monotonic()))
        if not ready:
            break
        line = sys.stdin.readline()
        if line == "":
            break
        line = line.strip()
        if not line:
            continue
        try:
            msg = json.loads(line)
        except json.JSONDecodeError:
            continue
        if str(msg.get("id", "")) == str(request["id"]):
            AUTO_ANSWER[0] = bool(msg.get("auto"))
            return bool(msg.get("approve"))
    emit(t="approve_timeout", id=request["id"])
    return False


# ------------------------------------------------------------------ the loop --

def first_text(result: dict) -> str:
    for part in (result or {}).get("content", []) or []:
        if part.get("type") == "text" and part.get("text"):
            return part["text"].strip().splitlines()[0][:160]
    return ""


def translate(pi: Pi, approver, conv: str) -> int:
    """Read pi's events, write ours, answer its dialogs. Returns an exit code."""
    started = time.monotonic()
    first_at: float | None = None
    usage: dict = {}
    for ev in pi.events():
        kind = ev.get("type")

        if kind == "message_update":
            # pi reports running totals on every update; the last one wins.
            if ev.get("usage"):
                usage = ev["usage"]
            delta = ev.get("assistantMessageEvent") or {}
            if delta.get("type") in ("text_delta", "thinking_delta") and delta.get("delta"):
                if first_at is None:
                    first_at = time.monotonic()
                emit(t="token" if delta["type"] == "text_delta" else "reasoning",
                     v=delta["delta"])

        elif kind == "tool_execution_start":
            emit(t="tool", id=ev.get("toolCallId", ""),
                 name=ev.get("toolName", "tool"), args=ev.get("args") or {})
            audit(ev.get("toolName", "tool"), ev.get("args") or {}, "pi ran it")

        elif kind == "tool_execution_end":
            emit(t="tool_result", id=ev.get("toolCallId", ""),
                 name=ev.get("toolName", "tool"),
                 ok=not ev.get("isError"), summary=first_text(ev.get("result")))

        elif kind == "extension_ui_request":
            method = ev.get("method")
            if method in ("confirm", "select"):
                # pi's own gate. Everything it asks about goes to the human --
                # this adapter never answers on their behalf.
                ok = approver({
                    "id": ev.get("id", ""),
                    "tool": ev.get("title") or method,
                    "path": ev.get("message") or "",
                    "preview": "\n".join(ev.get("options") or []),
                })
                audit("dialog", {"title": ev.get("title")},
                      ("approved (auto-approve on)" if AUTO_ANSWER[0] else "approved by operator")
                      if ok else "declined")
                if method == "confirm":
                    pi.send(type="extension_ui_response", id=ev.get("id"), confirmed=ok)
                else:
                    options = ev.get("options") or ["Allow", "Block"]
                    pi.send(type="extension_ui_response", id=ev.get("id"),
                            value=options[0] if ok else options[-1])
            elif method in ("input", "editor"):
                # A sidebar has one input, and it is the composer. Cancel these
                # rather than hang: pi treats a cancellation as "carry on".
                pi.send(type="extension_ui_response", id=ev.get("id"), cancelled=True)
            # notify / setStatus / setWidget / setTitle are fire-and-forget.

        elif kind == "response" and not ev.get("success", True):
            emit(t="error", msg=f"{ev.get('command', 'command')}: {ev.get('error', '')}")

        elif kind in ("agent_end", "agent_settled"):
            now = time.monotonic()
            gen_s = max(0.001, now - (first_at or started))
            out = usage.get("output") or 0
            emit(t="stats", ms=int((now - started) * 1000),
                 ttft_ms=int((first_at - started) * 1000) if first_at else None,
                 input=usage.get("input") or 0, output=out,
                 tps=round(out / gen_s, 1), exact=bool(usage))
            emit(t="done", conv=conv, ms=int((now - started) * 1000))
            return 0

    # pi's stdout closed without ever settling.
    err = ""
    if pi.proc.stderr is not None:
        err = (pi.proc.stderr.read() or "").strip().splitlines()[-1:] or [""]
        err = err[0][:200]
    emit(t="error", msg=err or "pi exited without answering")
    return 1


# ---------------------------------------------------------------------- main --

def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("prompt", nargs="*")
    ap.add_argument("--stdin", action="store_true")
    ap.add_argument("--panel", action="store_true")
    ap.add_argument("--conv", default="default")
    ap.add_argument("--reset", action="store_true")
    ap.add_argument("--history", action="store_true")
    ap.add_argument("--probe", action="store_true")
    ap.add_argument("--model", default="")
    ap.add_argument("--select", default="")
    ap.add_argument("--yes", action="store_true")
    ap.add_argument("--end-session", action="store_true",
                    help="forget this conversation's pi session")
    args = ap.parse_args()

    STATE_DIR.mkdir(parents=True, exist_ok=True)
    sessions = STATE_DIR / "pi" / "".join(c for c in args.conv if c.isalnum() or c in "-_")

    if args.end_session:
        # pi is a subprocess per turn, so there is nothing to stop -- only the
        # stored session to forget.
        shutil.rmtree(sessions, ignore_errors=True)
        emit(t="session_ended", harness="pi", stopped=False)
        return 0

    if args.select:
        MODEL_FILE.parent.mkdir(parents=True, exist_ok=True)
        MODEL_FILE.write_text(args.select.strip() + "\n")
        emit(t="selected", model=args.select)
        return 0

    if not shutil.which("pi"):
        emit(t="probe" if args.probe else "error", ok=False, endpoint=BASE_URL,
             msg="pi is not installed -- npm install -g @earendil-works/pi-coding-agent")
        return 1

    if args.probe:
        # The model list is the endpoint's, not pi's: it is the same box either
        # way, and asking it directly is instant where starting pi is not.
        try:
            import requests
            r = requests.get(f"{BASE_URL.rsplit('/v1', 1)[0]}/api/v0/models", timeout=5)
            models = [{"id": m["id"], "type": m.get("type", "llm"),
                       "state": m.get("state", ""), "ctx": m.get("max_context_length", 0)}
                      for m in r.json().get("data", [])
                      if m.get("type") in ("llm", "vlm")]
        except Exception as exc:
            emit(t="probe", ok=False, endpoint=BASE_URL, msg=str(exc)[:90])
            return 1
        hot = next((m["id"] for m in models if m["state"] in ("loaded", "loading")), "")
        emit(t="probe", ok=True, endpoint=BASE_URL, harness="pi",
             current=args.model or hot or remembered_model()
                     or (models[0]["id"] if models else ""),
             models=models)
        return 0

    if args.reset:
        shutil.rmtree(sessions, ignore_errors=True)

    if args.history:
        # pi keeps its own sessions in its own format; the sidebar simply opens
        # empty under this harness rather than half-reading someone else's log.
        emit(t="done", conv=args.conv)
        return 0

    if args.panel:
        approver = ask_panel
        first = sys.stdin.readline()
        try:
            text = (json.loads(first or "{}").get("prompt") or "").strip()
        except json.JSONDecodeError:
            text = first.strip()
    else:
        approver = (lambda _r: True) if args.yes else (lambda _r: False)
        text = sys.stdin.read().strip() if args.stdin else " ".join(args.prompt).strip()

    if not text:
        emit(t="error", msg="empty prompt")
        return 2

    model = args.model or loaded_model() or remembered_model()
    sessions.mkdir(parents=True, exist_ok=True)
    emit(t="start", conv=args.conv, model=model or "pi default",
         endpoint=BASE_URL, harness="pi")

    pi = Pi(model, sessions)
    try:
        pi.send(type="prompt", message=text)
        return translate(pi, approver, args.conv)
    except KeyboardInterrupt:
        emit(t="error", msg="cancelled")
        return 130
    finally:
        pi.stop()


if __name__ == "__main__":
    sys.exit(main())
