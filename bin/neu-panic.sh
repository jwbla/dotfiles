#!/usr/bin/env bash
# Panic exit from the neu shell. Bound to SUPER+SHIFT+ESCAPE.
#
# Level 1 of three (see NEU_THEME.md): kills the Quickshell shell and brings back
# waybar + dunst + wofi. Touches no files, so nothing needs undoing afterwards —
# `neu-shell.sh` puts the neu shell back, or just log out and in.
set -uo pipefail

echo "neu: panic — dropping to waybar/dunst/wofi"

pkill -f '^qs .*-c commandcenter' 2>/dev/null

pkill -x waybar 2>/dev/null
waybar >/dev/null 2>&1 &

pgrep -x dunst >/dev/null 2>&1 || dunst >/dev/null 2>&1 &

# Hand SUPER+SPACE back to wofi for the rest of this session. hyprctl keybind
# changes are session-only, so nothing here survives a reboot.
hyprctl keyword bind 'SUPER, SPACE, exec, wofi --show drun' >/dev/null 2>&1

sleep 0.5
command -v notify-send >/dev/null && notify-send \
    "neu shell stopped" \
    "waybar + wofi restored for this session. neu-shell.sh brings it back." || true
