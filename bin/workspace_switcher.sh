#!/bin/bash

# Workspace switcher for Hyprland - simple alt+tab equivalent
# Pipes window list to wofi and focuses the selected window

# Check dependencies
command -v jq &> /dev/null || { echo "Error: jq required" >&2; exit 1; }
command -v wofi &> /dev/null || { echo "Error: wofi required" >&2; exit 1; }

# Kill any existing wofi instances
pkill wofi

# Get current workspace for indicator
current_ws=$(hyprctl activeworkspace -j | jq -r '.id')

# Build window list with embedded metadata at the end of each line
# Format shown to user: "▶ Workspace 1 | firefox - My Page"
# Hidden at end: "	ws_id	address" (tab-separated for easy extraction)
display_list=$(hyprctl clients -j | jq -r --argjson current "$current_ws" '
  .[] |
  select(.workspace.id > 0) |
  (if .workspace.id == $current then "▶ " else "  " end) as $indicator |
  (.title // "" | if length > 60 then .[:57] + "..." else . end) as $short_title |
  "\($indicator)Workspace \(.workspace.id) | \(.class)\(if $short_title != "" then " - " + $short_title else "" end)\t\(.workspace.id)\t\(.address)"
' | sort -t'|' -k1 -n)

# Add empty workspaces (those with no windows)
empty_workspaces=$(hyprctl workspaces -j | jq -r --argjson clients "$(hyprctl clients -j)" --argjson current "$current_ws" '
  .[] |
  select(.id > 0) |
  . as $ws |
  ($clients | map(select(.workspace.id == $ws.id)) | length) as $count |
  select($count == 0) |
  (if .id == $current then "▶ " else "  " end) as $indicator |
  "\($indicator)Workspace \(.id) | (empty)\t\(.id)\t"
')

# Combine and sort
all_entries=$(printf "%s\n%s" "$display_list" "$empty_workspaces" | grep -v '^$' | sort -t'	' -k2 -n)

# Pass to wofi - tabs act as column separators, only first column shown
selected=$(echo "$all_entries" | wofi --dmenu --insensitive --width=75% --prompt="Switch to: ")

# Exit if nothing selected
[[ -z "$selected" ]] && exit 0

# Extract workspace ID and window address directly from selection
workspace_id=$(echo "$selected" | cut -f2)
window_address=$(echo "$selected" | cut -f3)

# Focus the window (or just switch workspace if empty)
if [[ -n "$window_address" ]]; then
    hyprctl dispatch workspace "$workspace_id"
    sleep 0.1
    hyprctl dispatch focuswindow "address:$window_address"
else
    hyprctl dispatch workspace "$workspace_id"
fi
