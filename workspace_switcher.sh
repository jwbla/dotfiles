#!/bin/bash

# Workspace switcher for Hyprland
# Pipes hyprctl workspaces to wofi and switches to the selected workspace
# Creates separate entries for each program on a workspace

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed" >&2
    exit 1
fi

# Check if wofi is available
if ! command -v wofi &> /dev/null; then
    echo "Error: wofi is required but not installed" >&2
    exit 1
fi

# Kill any existing wofi instances to ensure only one is open
pkill wofi

# Get current active workspace ID
current_workspace_id=$(hyprctl activeworkspace -j | jq -r '.id')

# Get workspaces and clients, create separate entries for each client
# Format: workspace_id|window_address|class|title|workspace_name|monitor|is_current
workspace_list=$(hyprctl workspaces -j | jq -r --argjson clients "$(hyprctl clients -j)" --argjson current "$current_workspace_id" '
  .[] as $ws |
  ($clients | map(select(.workspace.id == $ws.id))) as $ws_clients |
  if ($ws_clients | length) > 0 then
    $ws_clients[] | "\($ws.id)|\(.address)|\(.class)|\(.title // ""|gsub("\\|"; "│"))|\($ws.name)|\($ws.monitor)|\(if $ws.id == $current then "1" else "0" end)"
  else
    "\($ws.id)||empty||\($ws.name)|\($ws.monitor)|\(if $ws.id == $current then "1" else "0" end)"
  end
')

# Format for display with current workspace indicator (without window address)
display_list=$(echo "$workspace_list" | awk -F'|' '{
  current_indicator = ($7 == "1") ? "▶ " : "  ";
  if ($3 == "empty") {
    printf "%sWorkspace %s: %s | %s | (empty)\n", current_indicator, $1, $5, $6
  } else {
    title_part = ($4 != "") ? " - " $4 : "";
    printf "%sWorkspace %s: %s | %s | %s%s\n", current_indicator, $1, $5, $6, $3, title_part
  }
}')

# Use wofi to select workspace (with case insensitive search)
selected=$(echo "$display_list" | wofi --dmenu --insensitive --width=75% --prompt="Select workspace: ")

# Exit if no workspace selected (user pressed Esc or Ctrl+C)
if [[ -z "$selected" ]]; then
    exit 0
fi

# Extract workspace ID, class, and title from the selected line
# Format: "▶ Workspace ID: Name | Monitor | Program - Title" or "  Workspace ID: Name | Monitor | (empty)"
workspace_id=$(echo "$selected" | sed -n 's/.*Workspace \([0-9]*\):.*/\1/p')
# Extract the last field and split class and title
last_field=$(echo "$selected" | sed 's/^[▶ ]*//' | awk -F'|' '{print $NF}' | xargs)
class=$(echo "$last_field" | sed 's/ - .*$//' | xargs)
title=$(echo "$last_field" | sed -n 's/.* - \(.*\)$/\1/p' | xargs)

# Find the window address from the original data by matching workspace_id, class, and title
if [[ "$class" != "(empty)" ]]; then
    if [[ -n "$title" ]]; then
        # Match by workspace_id, class, and title
        window_address=$(echo "$workspace_list" | awk -F'|' -v ws="$workspace_id" -v cls="$class" -v ttl="$title" '$1 == ws && $3 == cls && $4 == ttl {print $2; exit}')
    else
        # Match by workspace_id and class only (fallback if no title)
        window_address=$(echo "$workspace_list" | awk -F'|' -v ws="$workspace_id" -v cls="$class" '$1 == ws && $3 == cls {print $2; exit}')
    fi
else
    window_address=""
fi

# Switch to the workspace
hyprctl dispatch workspace "$workspace_id"

# If there's a window address, focus that specific window
if [[ -n "$window_address" && "$window_address" != "" ]]; then
    hyprctl dispatch focuswindow "address:$window_address"
fi

