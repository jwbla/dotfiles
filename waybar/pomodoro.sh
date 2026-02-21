#!/bin/bash

POMODORO_DIR="$HOME/.config/waybar/pomodoro"
PID_FILE="$POMODORO_DIR/pid"
END_FILE="$POMODORO_DIR/end"
mkdir -p "$POMODORO_DIR"

WORK_TIME=$((25 * 60))

is_running() {
    [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null
}

start_timer() {
    echo $(( $(date +%s) + WORK_TIME )) > "$END_FILE"
    nohup bash -c "
        sleep $WORK_TIME
        notify-send -u critical '🍅 Pomodoro' 'Time is up!'
        rm -f '$PID_FILE' '$END_FILE'
        pkill -RTMIN+8 waybar
    " >/dev/null 2>&1 &
    echo $! > "$PID_FILE"
}

stop_timer() {
    kill "$(cat "$PID_FILE")" 2>/dev/null
    rm -f "$PID_FILE" "$END_FILE"
}

case "$1" in
    "toggle")
        if is_running; then
            stop_timer
        else
            start_timer
        fi
        ;;
    "start")
        if is_running; then
            echo "Pomodoro already running"
        else
            start_timer
            echo "Pomodoro started"
        fi
        ;;
    "stop")
        if is_running; then
            stop_timer
            echo "Pomodoro stopped"
        else
            echo "No pomodoro running"
        fi
        ;;
    "status")
        if is_running; then
            remaining=$(( $(cat "$END_FILE") - $(date +%s) ))
            mins=$(( remaining / 60 ))
            secs=$(( remaining % 60 ))
            printf '{"text":"🍅","tooltip":"%02d:%02d remaining","class":"active"}\n' "$mins" "$secs"
        else
            rm -f "$PID_FILE" "$END_FILE"
            echo '{"text":"🍅","tooltip":"Click to start pomodoro","class":"idle"}'
        fi
        ;;
esac
