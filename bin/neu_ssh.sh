#!/usr/bin/env bash
# The SSH phone book, as one JSON blob for the bar's Ssh module.
#
# Two sources, merged:
#   ~/.ssh/config        every non-wildcard Host block. Launched by ALIAS, never
#                        by a reconstructed user@host -- the alias is what makes
#                        ssh apply that block's IdentityFile/IdentitiesOnly/Port,
#                        and the rgtv deploy hosts depend on exactly that.
#   ~/.config/neu/ssh.json  optional, untracked, the same arrangement llm.env has:
#                        nothing links it, install.sh only says when it is absent.
#
# A name defined in the JSON wins over the same name in ~/.ssh/config, so the
# phone book can relabel or re-point a host without editing ssh's own config.
#
# Only ever reads Host/HostName/User/Port. IdentityFile paths are ignored on
# purpose: nothing about a key belongs in a list that gets drawn on a screen.
set -uo pipefail

CFG="${NEU_SSH_CONFIG:-$HOME/.ssh/config}"
JSON="${NEU_SSH_JSON:-$HOME/.config/neu/ssh.json}"

esc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

entries=""
declare -A seen=()

add() { entries+="${entries:+,}$1"; }

# ---- ~/.config/neu/ssh.json ------------------------------------------------
# python3 rather than a hand-rolled parser: this half is user-authored, and a
# JSON file people edit by hand is exactly where a trailing comma shows up.
# Skipped entirely when the file is absent, which is the common case.
if [[ -s "$JSON" ]]; then
    # \x1f, not a tab: tab is IFS *whitespace*, so bash collapses runs of it
    # and an empty field silently shifts every later field left -- which is how
    # a Host block with no HostName first reported its user as its address.
    while IFS=$'\x1f' read -r name obj; do
        [[ -n "$name" && -n "$obj" ]] || continue
        seen["$name"]=1
        add "$obj"
    done < <(python3 - "$JSON" <<'PY'
import json, sys

def emit(name, user, host, port, group):
    name = str(name).replace('\x1f', ' ').replace('\t', ' ').strip()
    host = (host or '').strip()
    if not name or not host:
        return
    user = (user or '').strip()
    target = f'{user}@{host}' if user else host
    o = {'name': name, 'target': target, 'detail': target,
         'port': int(port) if port else None,
         'group': (group or '').strip(), 'source': 'json'}
    print(name + '\x1f' + json.dumps(o, separators=(',', ':')))

try:
    d = json.load(open(sys.argv[1]))
except Exception as e:
    print('neu_ssh.sh: %s: %s' % (sys.argv[1], e), file=sys.stderr)
    raise SystemExit(0)

rows = d.get('hosts') if isinstance(d, dict) else d
if isinstance(rows, list):
    # The documented form: [{name, user, host, port?, group?}, ...]
    for r in rows:
        if isinstance(r, dict):
            emit(r.get('name') or r.get('host'), r.get('user'), r.get('host'),
                 r.get('port'), r.get('group'))
elif isinstance(d, dict):
    # The shorthand the phone book was asked for: {"label": "user@host"}.
    for k, v in d.items():
        if not isinstance(v, str):
            continue
        user, _, host = v.rpartition('@')
        emit(k, user, host or v, None, '')
PY
    )
fi

# ---- ~/.ssh/config ---------------------------------------------------------
# `Host a b c` declares several patterns for one block; the first non-wildcard
# token is the one worth showing (kudzu-demo, not the IP repeated after it).
# Keywords are case-insensitive in ssh_config, so the match is too.
if [[ -r "$CFG" ]]; then
    while IFS=$'\x1f' read -r alias host user port; do
        [[ -n "$alias" ]] || continue
        [[ -n "${seen[$alias]:-}" ]] && continue
        seen["$alias"]=1
        detail="${user:+$user@}${host:-$alias}"
        add "{\"name\":\"$(esc "$alias")\",\"target\":\"$(esc "$alias")\",\"detail\":\"$(esc "$detail")\",\"port\":null,\"group\":\"ssh config\",\"source\":\"config\"}"
    done < <(awk '
        function flush() {
            if (alias != "") printf "%s\37%s\37%s\37%s\n", alias, hostname, user, port
            alias = ""; hostname = ""; user = ""; port = ""
        }
        { sub(/#.*/, "") }
        tolower($1) == "host" {
            flush()
            for (i = 2; i <= NF; i++)
                if ($i !~ /[*?!]/) { alias = $i; break }
            next
        }
        tolower($1) == "hostname" { hostname = $2; next }
        tolower($1) == "user"     { user = $2; next }
        tolower($1) == "port"     { port = $2; next }
        END { flush() }
    ' "$CFG")
fi

printf '{"targets":[%s]}\n' "$entries"
