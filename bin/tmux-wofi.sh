#!/usr/bin/env bash
# Wofi-driven tmux session picker. Fallback for the quickshell Command Center,
# which is what SUPER+A is bound to.
# Reuses _tms_list_projects from tmux-session-manager.sh and delegates the
# attach (session creation + ghostty reuse + hyprctl focus) to tms-attach.sh.

set -u

command -v wofi &> /dev/null || { echo "Error: wofi required" >&2; exit 1; }
command -v tmux &> /dev/null || { echo "Error: tmux required" >&2; exit 1; }

# Resolve through the ~/.local/bin symlink so the siblings are found in the repo.
here="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
source "$here/tmux-session-manager.sh"

pkill wofi

choice=$(_tms_list_projects | wofi --dmenu --prompt="tmux project> ")
[[ -z "$choice" ]] && exit 0

exec "$here/tms-attach.sh" "${choice#* }"
