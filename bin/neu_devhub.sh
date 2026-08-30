#!/usr/bin/env bash
# Local dev state for the neu Dev Hub panel (SUPER+`).
#
# Deliberately *local* and complementary to the rgtv glance on SUPER+R: that one
# answers "what is the fleet doing" (Gitea PRs, CI, Prometheus); this one answers
# "what am I in the middle of" -- which repos are dirty, what branch, how far
# ahead/behind, and which have a tmux session already running.
set -uo pipefail

ROOT="${NEU_DEV_ROOT:-$HOME/dev}"
MAX_AGE_DAYS="${NEU_DEV_MAX_AGE:-120}"

sessions=$(tmux list-sessions -F '#{session_name}' 2>/dev/null | tr '\n' '|')

esc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

first=1
printf '{"repos":['
for d in "$ROOT"/*/; do
    [[ -d "$d/.git" ]] || continue
    name=$(basename "$d")

    # Anything untouched for months is noise on a "what am I working on" panel.
    last_epoch=$(git -C "$d" log -1 --format=%ct 2>/dev/null) || continue
    [[ -z "$last_epoch" ]] && continue
    age_days=$(( ( $(date +%s) - last_epoch ) / 86400 ))
    (( age_days > MAX_AGE_DAYS )) && continue

    branch=$(git -C "$d" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")
    dirty=$(git -C "$d" status --porcelain 2>/dev/null | wc -l)
    staged=$(git -C "$d" diff --cached --name-only 2>/dev/null | wc -l)

    ahead=0 behind=0
    if up=$(git -C "$d" rev-parse --abbrev-ref '@{upstream}' 2>/dev/null); then
        read -r behind ahead < <(git -C "$d" rev-list --left-right --count "$up...HEAD" 2>/dev/null || echo "0 0")
    fi

    subject=$(git -C "$d" log -1 --format=%s 2>/dev/null | cut -c1-72)
    stashes=$(git -C "$d" stash list 2>/dev/null | wc -l)
    session=false
    [[ "$sessions" == *"$name|"* ]] && session=true

    (( first )) || printf ','
    first=0
    printf '{"name":"%s","branch":"%s","dirty":%s,"staged":%s,"ahead":%s,"behind":%s,"stashes":%s,"ageDays":%s,"subject":"%s","session":%s,"path":"%s"}' \
        "$(esc "$name")" "$(esc "$branch")" "${dirty:-0}" "${staged:-0}" \
        "${ahead:-0}" "${behind:-0}" "${stashes:-0}" "$age_days" \
        "$(esc "$subject")" "$session" "$(esc "${d%/}")"
done
printf '],"sessions":['
first=1
while IFS= read -r s; do
    [[ -z "$s" ]] && continue
    (( first )) || printf ','
    first=0
    printf '"%s"' "$(esc "$s")"
done < <(tmux list-sessions -F '#{session_name}' 2>/dev/null)
printf ']}'
