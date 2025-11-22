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
# Format: workspace_id|window_address|class|workspace_name|monitor|is_current
workspace_list=$(hyprctl workspaces -j | jq -r --argjson clients "$(hyprctl clients -j)" --argjson current "$current_workspace_id" '
  .[] as $ws |
  ($clients | map(select(.workspace.id == $ws.id))) as $ws_clients |
  if ($ws_clients | length) > 0 then
    $ws_clients[] | "\($ws.id)|\(.address)|\(.class)|\($ws.name)|\($ws.monitor)|\(if $ws.id == $current then "1" else "0" end)"
  else
    "\($ws.id)||empty|\($ws.name)|\($ws.monitor)|\(if $ws.id == $current then "1" else "0" end)"
  end
')

# Format for display with current workspace indicator (without window address)
display_list=$(echo "$workspace_list" | awk -F'|' '{
  current_indicator = ($6 == "1") ? "▶ " : "  ";
  if ($3 == "empty") {
    printf "%sWorkspace %s: %s | %s | (empty)\n", current_indicator, $1, $4, $5
  } else {
    printf "%sWorkspace %s: %s | %s | %s\n", current_indicator, $1, $4, $5, $3
  }
}')

# Use wofi to select workspace (with case insensitive search)
selected=$(echo "$display_list" | wofi --dmenu --insensitive --prompt="Select workspace: ")

# Exit if no workspace selected (user pressed Esc or Ctrl+C)
if [[ -z "$selected" ]]; then
    exit 0
fi

# Extract workspace ID and class from the selected line
# Format: "▶ Workspace ID: Name | Monitor | Program" or "  Workspace ID: Name | Monitor | (empty)"
workspace_id=$(echo "$selected" | sed -n 's/.*Workspace \([0-9]*\):.*/\1/p')
# Extract the last field after the last pipe (removing leading indicator)
class=$(echo "$selected" | sed 's/^[▶ ]*//' | awk -F'|' '{print $NF}' | xargs)

# Find the window address from the original data by matching workspace_id and class
if [[ "$class" != "(empty)" ]]; then
    window_address=$(echo "$workspace_list" | awk -F'|' -v ws="$workspace_id" -v cls="$class" '$1 == ws && $3 == cls {print $2; exit}')
else
    window_address=""
fi

# Switch to the workspace
hyprctl dispatch workspace "$workspace_id"

# If there's a window address, focus that specific window
if [[ -n "$window_address" && "$window_address" != "" ]]; then
    hyprctl dispatch focuswindow "address:$window_address"
fi

