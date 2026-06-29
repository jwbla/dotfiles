#!/usr/bin/env bash
# Waybar custom module: now playing.
# Event-driven via `playerctl --follow` (no polling while a player exists).
# Emits one JSON line per status/track change; prints empty text so the
# module hides when nothing is playing. Reconnects when a player appears.

emit() {
    local status title artist text icon
    status=$(playerctl status 2>/dev/null)
    if [[ -z "$status" ]]; then
        printf '{"text": "", "class": "stopped"}\n'
        return
    fi

    title=$(playerctl metadata xesam:title 2>/dev/null)
    artist=$(playerctl metadata xesam:artist 2>/dev/null)

    if [[ "$status" == "Playing" ]]; then
        icon=""
    else
        icon=""
    fi

    if [[ -n "$artist" && -n "$title" ]]; then
        text="$artist - $title"
    else
        text="${title:-$artist}"
    fi

    # Escape backslashes then double quotes for valid JSON.
    text=${text//\\/\\\\}
    text=${text//\"/\\\"}

    printf '{"text": "%s %s", "class": "%s", "tooltip": "%s"}\n' \
        "$icon" "$text" "${status,,}" "$text"
}

# Print the current state immediately, then react to every change. When the
# last player disappears, `playerctl --follow` exits; loop back, emit the
# empty state, and wait briefly for a new player to appear.
while true; do
    emit
    playerctl --follow --format '{{status}}' metadata 2>/dev/null | while read -r _; do
        emit
    done
    emit
    sleep 2
done
