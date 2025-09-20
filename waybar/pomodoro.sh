#!/bin/bash

# Pomodoro timer script for waybar
# Usage: ./pomodoro.sh [start|stop|reset|status]

POMODORO_DIR="$HOME/.config/waybar/pomodoro"
TIMER_FILE="$POMODORO_DIR/timer"
STATE_FILE="$POMODORO_DIR/state"

# Create directory if it doesn't exist
mkdir -p "$POMODORO_DIR"

# Default times (in minutes)
WORK_TIME=25

# Colors for different states
WORK_COLOR="#f38ba8"      # Pink
PAUSED_COLOR="#f9e2af"    # Yellow

# Initialize files if they don't exist
if [[ ! -f "$TIMER_FILE" ]]; then
    echo "0" > "$TIMER_FILE"
fi

if [[ ! -f "$STATE_FILE" ]]; then
    echo "idle" > "$STATE_FILE"
fi

get_state() {
    cat "$STATE_FILE"
}

set_state() {
    echo "$1" > "$STATE_FILE"
}

get_timer() {
    cat "$TIMER_FILE"
}

set_timer() {
    echo "$1" > "$TIMER_FILE"
}

get_remaining() {
    local start_time=$(get_timer)
    local current_time=$(date +%s)
    local elapsed=$((current_time - start_time))
    local remaining=$((($1 * 60) - elapsed))
    echo $remaining
}

format_time() {
    local seconds=$1
    local minutes=$((seconds / 60))
    local secs=$((seconds % 60))
    printf "%02d:%02d" $minutes $secs
}

get_pomodoro_count() {
    local count_file="$POMODORO_DIR/count"
    if [[ -f "$count_file" ]]; then
        cat "$count_file"
    else
        echo "0"
    fi
}

set_pomodoro_count() {
    local count_file="$POMODORO_DIR/count"
    echo "$1" > "$count_file"
}

case "$1" in
    "start")
        current_state=$(get_state)
        if [[ "$current_state" == "idle" ]]; then
            set_state "work"
            set_timer $(date +%s)
        elif [[ "$current_state" == "paused" ]]; then
            set_state "work"
            set_timer $(date +%s)
        fi
        ;;
    "stop")
        set_state "idle"
        set_timer 0
        ;;
    "toggle")
        current_state=$(get_state)
        if [[ "$current_state" == "idle" ]]; then
            set_state "work"
            set_timer $(date +%s)
        elif [[ "$current_state" == "work" ]]; then
            set_state "idle"
            set_timer 0
        elif [[ "$current_state" == "paused" ]]; then
            set_state "work"
            set_timer $(date +%s)
        fi
        ;;
    "pause")
        current_state=$(get_state)
        if [[ "$current_state" == "work" ]]; then
            set_state "paused"
        fi
        ;;
    "resume")
        current_state=$(get_state)
        if [[ "$current_state" == "paused" ]]; then
            set_state "work"
            set_timer $(date +%s)
        fi
        ;;
    "reset")
        set_state "idle"
        set_timer 0
        ;;
    "status")
        current_state=$(get_state)
        case "$current_state" in
            "idle")
                echo '{"text":"🍅","tooltip":"Pomodoro Timer - Click to start","class":"idle"}'
                ;;
            "work")
                remaining=$(get_remaining $WORK_TIME)
                if [[ $remaining -le 0 ]]; then
                    # Timer finished, reset to idle
                    set_state "idle"
                    set_timer 0
                    echo '{"text":"🍅","tooltip":"Pomodoro Timer - Click to start","class":"idle"}'
                else
                    echo "{\"text\":\"🍅 $(format_time $remaining)\",\"tooltip\":\"Work Session - $(format_time $remaining) remaining\",\"class\":\"work\"}"
                fi
                ;;
            "paused")
                remaining=$(get_remaining $WORK_TIME)
                echo "{\"text\":\"🍅 ⏸️ $(format_time $remaining)\",\"tooltip\":\"Paused - $(format_time $remaining) remaining\",\"class\":\"paused\"}"
                ;;
        esac
        ;;
    *)
        echo "Usage: $0 [start|stop|toggle|pause|resume|reset|status]"
        exit 1
        ;;
esac
