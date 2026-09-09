#!/usr/bin/env bash
# Gitea Actions runners on this box, as one JSON blob for the bar's CI module.
#
# Only the flagship laptop (ThinkPad T480, `rgtv-flagship`) runs any: a host-mode
# act_runner under a systemd *user* unit for the android/linux lanes, and a
# docker-mode one in a container for generic jobs. Every other machine in this
# set has neither, so the first thing this does is look for a registration file
# and print `present:false` -- two stat calls and no forks. Ci.qml drops to a
# five-minute heartbeat once it sees that, which is what keeps a module for one
# laptop from costing anything on the others.
#
# "Is a job running" is read the same way ~/dev/flagship's scripts read it, which
# is the way that has been proven on that box:
#   docker mode -- act_runner names each job container GITEA-ACTIONS-TASK-*, so
#                  the running ones are a `docker ps` away.
#   host mode   -- a host-executor job's steps run as children of the daemon, so
#                  the daemon having children means it is working. Bazel's server
#                  survives a build for hours but reparents away from the daemon,
#                  so it does not count here (it fooled an earlier version of the
#                  loop in flagship/20-narrow-host-runner.sh, which matched argv).
#
# Never prints a token: `.runner` holds the registration secret alongside the
# name, and only the name and instance URL are read out of it.
set -uo pipefail

HOST_DIR="${NEU_CI_HOST_DIR:-$HOME/.config/act_runner}"
DOCKER_DIR="${NEU_CI_DOCKER_DIR:-$HOME/.local/share/act-runner-docker}"

# act_runner writes .runner beside its config, but an older install can leave it
# in $HOME instead -- flagship/20-narrow-host-runner.sh looks in both, so this
# does too.
host_reg=""
for f in "$HOST_DIR/.runner" "$HOME/.runner"; do
    [[ -f "$f" ]] && { host_reg="$f"; break; }
done
docker_reg="$DOCKER_DIR/data/.runner"

if [[ -z "$host_reg" && ! -f "$docker_reg" ]]; then
    echo '{"present":false,"jobs":0,"runners":[]}'
    exit 0
fi

esc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

# One string field out of a .runner. Deliberately not python/jq: this runs on a
# timer, and both cost more to start than the whole rest of the script.
reg_str() {
    grep -o "\"$2\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$1" 2>/dev/null \
        | head -1 | sed 's/^.*:[[:space:]]*"//; s/"$//'
}

cap_of() {
    [[ -r "$1" ]] || { echo 0; return; }
    awk '/^[[:space:]]*capacity:[[:space:]]*[0-9]+/ { print $2; exit }' "$1"
}

runners="" total=0 url=""

# ---- docker-mode runner ----------------------------------------------------
# One `docker ps` answers both questions: how many job containers exist, and
# whether the runner container itself is still up.
if [[ -f "$docker_reg" ]]; then
    names=$(docker ps --format '{{.Names}}' 2>/dev/null)
    jobs=$(grep -c 'GITEA-ACTIONS-TASK' <<<"$names")
    [[ "$jobs" =~ ^[0-9]+$ ]] || jobs=0
    up=false
    grep -qx 'act-runner' <<<"$names" && up=true

    name=$(reg_str "$docker_reg" name)
    url=$(reg_str "$docker_reg" address)
    cap=$(cap_of "$DOCKER_DIR/data/config.yaml")

    total=$((total + jobs))
    runners+="${runners:+,}{\"name\":\"$(esc "${name:-act-runner}")\",\"kind\":\"docker\",\"jobs\":$jobs,\"capacity\":${cap:-0},\"up\":$up}"
fi

# ---- host-mode runner ------------------------------------------------------
# Children of the daemon, not a container count -- and a count of them rather
# than a yes/no, because with capacity 2 two concurrent jobs are two children.
# It can read 0 for the moment between two steps of one job; Ci.qml holds the
# icon on for a few seconds so that gap does not blink the bar.
if [[ -n "$host_reg" ]]; then
    jobs=0 up=false
    pid=$(pgrep -f 'act_runner daemon' 2>/dev/null | head -1)
    if [[ -n "$pid" ]]; then
        up=true
        kids=$(pgrep -P "$pid" 2>/dev/null | wc -l)
        [[ "$kids" =~ ^[0-9]+$ ]] && jobs=$kids
    fi

    name=$(reg_str "$host_reg" name)
    [[ -z "$url" ]] && url=$(reg_str "$host_reg" address)
    cap=$(cap_of "$HOST_DIR/config.yaml")
    [[ "${cap:-0}" == 0 ]] && cap=$(cap_of "$HOST_DIR/config.yml")

    total=$((total + jobs))
    runners+="${runners:+,}{\"name\":\"$(esc "${name:-act_runner}")\",\"kind\":\"host\",\"jobs\":$jobs,\"capacity\":${cap:-0},\"up\":$up}"
fi

printf '{"present":true,"jobs":%d,"url":"%s","runners":[%s]}\n' "$total" "$(esc "$url")" "$runners"
