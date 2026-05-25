#!/usr/bin/env bash
# Wofi-driven tmux session picker. Bound to Super+A in hyprland.conf.
# Reuses _tms_list_projects and _tms_create_session from tmux-session-manager.sh.

set -u

command -v wofi &> /dev/null || { echo "Error: wofi required" >&2; exit 1; }
command -v tmux &> /dev/null || { echo "Error: tmux required" >&2; exit 1; }
command -v ghostty &> /dev/null || { echo "Error: ghostty required" >&2; exit 1; }
command -v hyprctl &> /dev/null || { echo "Error: hyprctl required" >&2; exit 1; }
command -v jq &> /dev/null || { echo "Error: jq required" >&2; exit 1; }

source "${HOME}/dev/dotfiles/tmux-session-manager.sh"

pkill wofi

choice=$(_tms_list_projects | wofi --dmenu --prompt="tmux project> ")
[[ -z "$choice" ]] && exit 0

name="${choice#* }"

if ! tmux has-session -t "$name" 2>/dev/null; then
  _tms_create_session "$name" || exit 1
fi

# Try to reuse an existing ghostty window that already has a tmux client attached.
# Walk up the process tree from a process on the client's tty until we find ghostty.
client_tty=$(tmux list-clients -F '#{client_tty}' 2>/dev/null | head -1)
if [[ -n "$client_tty" ]]; then
  tty_short="${client_tty#/dev/}"
  pid=$(pgrep -t "$tty_short" 2>/dev/null | head -1)
  while [[ -n "$pid" && "$pid" -gt 1 ]]; do
    comm=$(ps -o comm= -p "$pid" 2>/dev/null | tr -d ' ')
    if [[ "$comm" == "ghostty" ]]; then
      tmux switch-client -c "$client_tty" -t "$name"
      addr=$(hyprctl clients -j 2>/dev/null | jq -r --argjson p "$pid" '.[] | select(.pid == $p) | .address' | head -1)
      [[ -n "$addr" ]] && hyprctl dispatch focuswindow "address:$addr" > /dev/null
      exit 0
    fi
    pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
  done
fi

# No reusable client found — open a new ghostty.
exec ghostty -e tmux attach-session -t "$name"
