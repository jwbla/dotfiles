#!/usr/bin/env bash
# Start the Quickshell (neu) shell, with a fallback to waybar if it doesn't come up.
#
# This is what hyprland.lua autostarts instead of `qs -d -c commandcenter`. The
# neu shell owns the bar, the dock, the launcher and notifications, so a QML error
# would otherwise leave a session with no bar and no launcher. Here a broken shell
# costs a worse-looking bar, not a dead desktop.
set -uo pipefail

CONFIG=commandcenter
TIMEOUT=${NEU_SHELL_TIMEOUT:-8}
LOG=${XDG_STATE_HOME:-$HOME/.local/state}/neu-shell.log

mkdir -p "$(dirname "$LOG")"

note() { printf '[neu-shell %(%H:%M:%S)T] %s\n' -1 "$*" | tee -a "$LOG" >&2; }

start_fallback() {
    note "falling back to waybar + dunst"
    pkill -x waybar 2>/dev/null
    waybar >>"$LOG" 2>&1 &
    if ! pgrep -x dunst >/dev/null 2>&1; then
        dunst >>"$LOG" 2>&1 &
    fi
    command -v notify-send >/dev/null && notify-send -u critical \
        "neu shell did not start" \
        "Fell back to waybar. Log: $LOG — see NEU_THEME.md for the exits." || true
}

# Already running? Nothing to do.
if pgrep -f "^qs .*-c $CONFIG" >/dev/null 2>&1; then
    note "already running"
    exit 0
fi

pkill -x waybar 2>/dev/null

note "starting quickshell config '$CONFIG'"
qs -d -c "$CONFIG" >>"$LOG" 2>&1

# Wait for the bar to actually put a layer surface on screen. This checks the
# compositor rather than the process, so a shell that starts and then throws
# still counts as failed.
for _ in $(seq 1 $((TIMEOUT * 4))); do
    if hyprctl layers 2>/dev/null | grep -q 'namespace: neu:bar'; then
        note "bar up"
        exit 0
    fi
    if ! pgrep -f "^qs .*-c $CONFIG" >/dev/null 2>&1; then
        note "quickshell exited during startup"
        break
    fi
    sleep 0.25
done

note "bar did not appear within ${TIMEOUT}s"
pkill -f "^qs .*-c $CONFIG" 2>/dev/null
start_fallback
exit 1
