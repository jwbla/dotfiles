#!/usr/bin/env python3
"""Drive `opencode serve`, speaking the neu sidebar's protocol.

opencode is the heaviest of the three harnesses and the only one that is a
server rather than a subprocess: it holds sessions, MCP servers and a real
permission model, and clients talk to it over HTTP + SSE. So this adapter runs
a server (or joins one already running), starts a session, and translates:

    opencode                        ->   the sidebar
    message.part.updated text       ->   {"t":"token"}   (suffix-diffed)
    message.part.updated reasoning  ->   {"t":"reasoning"}
    message.part.updated tool       ->   {"t":"tool"} / {"t":"tool_result"}
    permission.asked                ->   {"t":"approve"} -> the approval card
    session.idle / session.error    ->   {"t":"done"} / {"t":"error"}

WHY SUFFIX-DIFFING: opencode publishes the whole part on every update, not the
delta. Emitting it raw would repaint the message on every token, so we remember
what we have already sent per part and emit only what is new.

WHY THE PERMISSION BLOCK MATTERS: opencode allows bash by default. Under this
harness a model can run shell commands on this machine unattended unless
opencode.json says otherwise -- and then nothing ever reaches the approval card,
because nothing is ever asked. `--check` reports what the config actually does.

    NEU_LLM_OC_PORT      port to run or join   (default 4096)
    NEU_LLM_OC_PROVIDER  provider id in opencode.json  (default lmstudio)
    NEU_LLM_OC_DIR       working directory for the session (default $HOME)
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import signal
import subprocess
import sys
import time
from pathlib import Path

try:
    sys.stdout.reconfigure(encoding="utf-8")
except (AttributeError, OSError):
    pass

try:
    import requests
except ImportError:
    print(json.dumps({"t": "error", "msg": "python-requests is not installed"}), flush=True)
    sys.exit(1)

STATE_DIR = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "neu/llm"
ENV_FILE = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "neu/llm.env"
MODEL_FILE = STATE_DIR / "model"


def load_env_file(path: Path = ENV_FILE) -> None:
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

PORT = int(os.environ.get("NEU_LLM_OC_PORT", "4096"))
PROVIDER = os.environ.get("NEU_LLM_OC_PROVIDER", "lmstudio")
WORKDIR = os.environ.get("NEU_LLM_OC_DIR", str(Path.home()))
BASE = f"http://127.0.0.1:{PORT}"
APPROVE_TIMEOUT = 180


def emit(**event) -> None:
    try:
        sys.stdout.write(json.dumps(event, ensure_ascii=False) + "\n")
        sys.stdout.flush()
    except BrokenPipeError:
        # Whoever was reading us is gone -- the panel closed, or the shell
        # reloaded. There is nobody to tell, so stop rather than unwind through
        # every caller printing tracebacks at a closed pipe.
        os._exit(0)


def audit(tool: str, args: dict, verdict: str) -> None:
    try:
        STATE_DIR.mkdir(parents=True, exist_ok=True)
        with (STATE_DIR / "tools.log").open("a") as fh:
            fh.write(json.dumps({"ts": time.strftime("%F %T"), "harness": "opencode",
                                 "tool": tool, "args": args, "verdict": verdict}) + "\n")
    except OSError:
        pass


# ------------------------------------------------------------------- server --

def server_up(timeout: float = 2) -> bool:
    try:
        return requests.get(f"{BASE}/global/health", timeout=timeout).ok
    except Exception:
        return False


def ensure_server() -> subprocess.Popen | None:
    """Join a server if one is listening, otherwise start one we own.

    Joining matters: the same server backs a terminal `opencode` session, and
    two of them on one port would fight.
    """
    if server_up():
        return None
    proc = subprocess.Popen(
        ["opencode", "serve", "--port", str(PORT), "--hostname", "127.0.0.1"],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, cwd=WORKDIR,
        start_new_session=True)
    for _ in range(60):
        if server_up(timeout=1):
            (STATE_DIR / "opencode.pid").write_text(str(proc.pid))
            return proc
        time.sleep(0.5)
    proc.terminate()
    raise RuntimeError("opencode serve did not come up")


# ---------------------------------------------------------------- approvals --

AUTO_ANSWER = [False]  # was the last yes a person's, or a held-open gate?


def ask_panel(request: dict) -> bool:
    emit(t="approve", **request)
    deadline = time.monotonic() + APPROVE_TIMEOUT
    import select
    while time.monotonic() < deadline:
        ready, _, _ = select.select([sys.stdin], [], [], max(0.0, deadline - time.monotonic()))
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


# ------------------------------------------------------------------- stream --

def summarise(state: dict) -> str:
    out = (state or {}).get("output") or ""
    if out:
        return out.strip().splitlines()[0][:160]
    return json.dumps((state or {}).get("input") or {})[:160]


def run_turn(sid: str, prompt: str, model: str, approver, conv: str) -> int:
    """Post the prompt, then translate the event stream until the turn settles."""
    body = {"parts": [{"type": "text", "text": prompt}]}
    if model:
        body["model"] = {"providerID": PROVIDER, "modelID": model}

    stream = requests.get(f"{BASE}/event", stream=True, timeout=(5, 3600))
    stream.encoding = "utf-8"

    r = requests.post(f"{BASE}/session/{sid}/prompt_async", json=body, timeout=30)
    if r.status_code >= 400:
        emit(t="error", msg=f"{r.status_code} {r.text[:200]}")
        return 1

    sent: dict[str, int] = {}       # part id -> characters already emitted
    tools: dict[str, dict] = {}     # part id -> what we have reported about it
    roles: dict[str, str] = {}      # message id -> role
    started = time.monotonic()
    # opencode counts tokens itself and publishes them on step-finish, so the
    # only thing we have to measure is when the first token reached the screen.
    first_at: float | None = None
    tokens = {"input": 0, "output": 0}

    for raw in stream.iter_lines(decode_unicode=True):
        if not raw or not raw.startswith("data:"):
            continue
        try:
            ev = json.loads(raw[5:].strip())
        except json.JSONDecodeError:
            continue
        kind = ev.get("type", "")
        props = ev.get("properties", {}) or {}

        if kind == "permission.asked":
            if props.get("sessionID") not in (None, sid):
                continue
            meta = props.get("metadata") or {}
            name = props.get("permission") or "tool"
            # `patterns` is the thing itself -- the command, or the file being
            # edited. `always` is what a blanket yes would cover, which is the
            # more important number to show: "df *" is a wider grant than "df -h /".
            patterns = props.get("patterns") or []
            always = props.get("always") or []
            detail = "\n".join(str(x) for x in patterns) or \
                meta.get("command") or meta.get("filePath") or json.dumps(meta)[:200]
            preview = detail
            if always:
                preview += "\n\nalways would allow: " + ", ".join(str(a) for a in always)
            ok = approver({"id": props.get("id", ""), "tool": name,
                           "path": str(detail)[:200], "preview": preview[:1500]})
            audit(name, {"detail": str(detail)[:200]},
                  ("approved (auto-approve on)" if AUTO_ANSWER[0] else "approved by operator")
                  if ok else "declined")
            try:
                requests.post(
                    f"{BASE}/session/{props.get('sessionID', sid)}/permissions/{props.get('id')}",
                    json={"response": "once" if ok else "reject"}, timeout=15)
            except Exception as exc:
                emit(t="error", msg=f"could not answer the permission: {exc}")
            continue

        if props.get("sessionID") not in (None, sid):
            continue

        if kind in ("message.updated", "message.part.removed"):
            info = props.get("info") or props.get("message") or {}
            if info.get("id"):
                roles[info["id"]] = info.get("role", "")

        if kind == "message.part.updated":
            part = props.get("part") or {}
            pid = part.get("id", "")
            ptype = part.get("type")

            # The prompt we just sent comes back as a part of the user message.
            # Echoing it would open every answer with the question.
            if roles.get(part.get("messageID", ""), "") == "user":
                continue
            if ptype == "text" and (part.get("text") or "").strip() == prompt.strip():
                continue

            if ptype in ("text", "reasoning"):
                # opencode republishes the whole part; emit only what is new.
                text = part.get("text") or ""
                already = sent.get(pid, 0)
                if len(text) > already:
                    if first_at is None:
                        first_at = time.monotonic()
                    emit(t="token" if ptype == "text" else "reasoning",
                         v=text[already:])
                    sent[pid] = len(text)

            elif ptype == "step-finish":
                tk = part.get("tokens") or {}
                tokens["input"] += tk.get("input") or 0
                tokens["output"] += tk.get("output") or 0

            elif ptype == "tool":
                state = part.get("state") or {}
                status = state.get("status", "")
                inp = state.get("input") or {}
                seen = tools.setdefault(pid, {"announced": False, "done": False})
                # A tool part is published repeatedly -- first bare, then with
                # its arguments, then with its result. Announce it once, when
                # there is something worth showing.
                if not seen["announced"] and (inp or status in ("running", "completed", "error")):
                    seen["announced"] = True
                    emit(t="tool", id=pid, name=part.get("tool", "tool"), args=inp)
                if status in ("completed", "error") and not seen["done"]:
                    seen["done"] = True
                    emit(t="tool_result", id=pid, name=part.get("tool", "tool"),
                         ok=status == "completed", summary=summarise(state))
                    audit(part.get("tool", "tool"), inp, "opencode ran it")

        elif kind == "session.error":
            err = (props.get("error") or {}).get("data", {}).get("message") \
                or json.dumps(props.get("error"))[:200]
            emit(t="error", msg=err)
            emit(t="done", conv=conv, ms=int((time.monotonic() - started) * 1000))
            return 1

        elif kind == "session.idle":
            now = time.monotonic()
            gen_s = max(0.001, now - (first_at or started))
            emit(t="stats", ms=int((now - started) * 1000),
                 ttft_ms=int((first_at - started) * 1000) if first_at else None,
                 input=tokens["input"], output=tokens["output"],
                 tps=round(tokens["output"] / gen_s, 1), exact=True)
            emit(t="done", conv=conv, ms=int((now - started) * 1000))
            return 0

    emit(t="error", msg="the opencode event stream ended mid-turn")
    return 1


# --------------------------------------------------------------------- main --

def loaded_model() -> str:
    """Whatever LM Studio currently holds in memory, if we can see it."""
    endpoint = os.environ.get("NEU_LLM_URL", "").rstrip("/")
    if not endpoint:
        return ""
    try:
        r = requests.get(f"{endpoint.rsplit('/v1', 1)[0]}/api/v0/models", timeout=5)
        for m in r.json().get("data", []):
            if m.get("state") in ("loaded", "loading") and m.get("type") in ("llm", "vlm"):
                return m["id"]
    except Exception:
        pass
    return ""


def session_file(conv: str) -> Path:
    safe = "".join(c for c in conv if c.isalnum() or c in "-_") or "default"
    return STATE_DIR / f"opencode-{safe}.session"


def get_session(conv: str) -> str:
    """One opencode session per neu conversation, remembered between turns."""
    path = session_file(conv)
    if path.exists():
        sid = path.read_text().strip()
        try:
            if requests.get(f"{BASE}/session/{sid}", timeout=10).ok:
                return sid
        except Exception:
            pass
    sid = requests.post(f"{BASE}/session", json={}, timeout=30).json()["id"]
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(sid)
    return sid


def permission_report() -> dict:
    """What opencode's config actually gates. Silence here means 'allowed'."""
    try:
        cfg = requests.get(f"{BASE}/config", timeout=10).json()
    except Exception as exc:
        return {"error": str(exc)[:120]}
    perm = cfg.get("permission")
    if not perm:
        return {"configured": False,
                "note": "no permission block: bash and edits run unasked"}
    return {"configured": True, "permission": perm}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("prompt", nargs="*")
    ap.add_argument("--stdin", action="store_true")
    ap.add_argument("--panel", action="store_true")
    ap.add_argument("--conv", default="default")
    ap.add_argument("--reset", action="store_true")
    ap.add_argument("--history", action="store_true")
    ap.add_argument("--probe", action="store_true")
    ap.add_argument("--check", action="store_true",
                    help="report what opencode's permission config gates")
    ap.add_argument("--stop-server", action="store_true",
                    help="stop the opencode server this adapter started")
    ap.add_argument("--end-session", action="store_true",
                    help="forget the session and stop a server we started")
    ap.add_argument("--model", default="")
    ap.add_argument("--select", default="")
    ap.add_argument("--yes", action="store_true")
    args = ap.parse_args()

    STATE_DIR.mkdir(parents=True, exist_ok=True)

    if args.select:
        MODEL_FILE.write_text(args.select.strip() + "\n")
        emit(t="selected", model=args.select)
        return 0

    if args.end_session:
        # The session id is ours to forget; the server is only ours to stop if
        # we were the ones who started it -- a terminal opencode may be using it.
        session_file(args.conv).unlink(missing_ok=True)
        args.stop_server = True

    if args.stop_server:
        pid_file = STATE_DIR / "opencode.pid"
        try:
            os.kill(int(pid_file.read_text().strip()), signal.SIGTERM)
            pid_file.unlink(missing_ok=True)
            emit(t="session_ended", harness="opencode", stopped=True)
        except (OSError, ValueError):
            # Nothing of ours was running -- the session is still forgotten,
            # which is the part the button promised.
            emit(t="session_ended", harness="opencode", stopped=False)
        return 0

    if not shutil.which("opencode"):
        emit(t="probe" if args.probe else "error", ok=False,
             msg="opencode is not installed -- pacman -S opencode")
        return 1

    owned = None
    try:
        owned = ensure_server()

        if args.check:
            emit(t="permissions", **permission_report())
            return 0

        if args.probe:
            try:
                providers = requests.get(f"{BASE}/config/providers", timeout=20).json()
            except Exception as exc:
                emit(t="probe", ok=False, endpoint=BASE, msg=str(exc)[:90])
                return 1
            # opencode knows which ids it will accept; only LM Studio knows
            # which one is in memory. The picker wants both.
            state = {}
            endpoint = os.environ.get("NEU_LLM_URL", "").rstrip("/")
            if endpoint:
                try:
                    r = requests.get(f"{endpoint.rsplit('/v1', 1)[0]}/api/v0/models", timeout=5)
                    state = {m["id"]: m for m in r.json().get("data", [])}
                except Exception:
                    pass

            models = []
            for prov in (providers.get("providers") or []):
                if prov.get("id") != PROVIDER:
                    continue
                for mid in (prov.get("models") or {}):
                    live = state.get(mid, {})
                    models.append({"id": mid, "type": live.get("type", "llm"),
                                   "state": live.get("state", ""),
                                   "ctx": live.get("loaded_context_length")
                                          or live.get("max_context_length", 0)})
            hot = next((m["id"] for m in models if m["state"] in ("loaded", "loading")), "")
            remembered = MODEL_FILE.read_text().strip() if MODEL_FILE.exists() else ""
            emit(t="probe", ok=True, endpoint=BASE, harness="opencode",
                 current=args.model or hot or remembered, models=models,
                 gates=permission_report())
            return 0

        if args.reset:
            session_file(args.conv).unlink(missing_ok=True)

        if args.history:
            # opencode owns the transcript; the sidebar opens clean rather than
            # re-rendering a session it does not manage.
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

        # Explicit pick, then whatever the box actually holds, then a memory.
        # A remembered model that has been evicted costs a load that may not
        # even fit -- which is exactly the failure this ordering avoids.
        model = args.model or loaded_model() \
            or (MODEL_FILE.read_text().strip() if MODEL_FILE.exists() else "")
        sid = get_session(args.conv)
        emit(t="start", conv=args.conv, model=model or "opencode default",
             endpoint=BASE, harness="opencode")

        def stop(_sig, _frm):
            try:
                requests.post(f"{BASE}/session/{sid}/abort", timeout=5)
            except Exception:
                pass
            emit(t="error", msg="cancelled")
            sys.exit(130)

        signal.signal(signal.SIGTERM, stop)
        signal.signal(signal.SIGINT, stop)
        return run_turn(sid, text, model, approver, args.conv)

    except Exception as exc:
        emit(t="error", msg=f"{type(exc).__name__}: {exc}"[:200])
        return 1
    # Deliberately no teardown: a server started here outlives the turn so the
    # next message joins it instead of paying eight seconds of startup again.
    # `--stop-server` ends it, and its pid is in the state directory.


if __name__ == "__main__":
    sys.exit(main())
