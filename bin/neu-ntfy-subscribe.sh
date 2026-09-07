#!/usr/bin/env bash
# Turn an ntfy topic into ordinary desktop notifications.
#
# The last hop of the fleet alert path: Proxmox -> ntfy (CT 911) -> here ->
# org.freedesktop.Notifications -> quickshell's toast -> the notification
# history center. Deliberately the SAME road every other notification takes,
# via notify-send, so there is exactly one ingestion point to reason about and
# fleet alerts are reviewable in the history like anything else.
#
# Run by systemd, not by hand: see systemd/neu-ntfy.service. Every setting comes
# from the environment, and the credentials come from a 0600 file the operator
# writes themselves (systemd/neu-ntfy.env.example is the template) -- nothing
# here or in the repo ever holds the topic or the token.
#
#   NTFY_URL          base url of the ntfy server, no topic     (required)
#   NTFY_TOPIC        topic to subscribe to                      (required)
#   NTFY_TOKEN        read token; empty for an open topic        (optional)
#   NTFY_CRITICAL_AT  ntfy priority that maps to urgency=critical (default 5)
#   NTFY_STALL_SECS   reconnect if the stream goes quiet this long (default 150)
#   NTFY_ALERT_AFTER  say so after N consecutive failed connects  (default 5)
#
# WHY NOT THE ntfy CLI: it is not in the Arch repos, only the AUR, and this box
# installs from the official repos alone. curl and jq are already here, and
# ntfy's /json endpoint is a documented line-delimited stream meant for exactly
# this. If ntfy ever lands in extra/, replacing the stream_once() body with
# `ntfy subscribe` is the whole migration.

set -uo pipefail

: "${NTFY_URL:?NTFY_URL is not set -- see systemd/neu-ntfy.env.example}"
: "${NTFY_TOPIC:?NTFY_TOPIC is not set -- see systemd/neu-ntfy.env.example}"
NTFY_TOKEN="${NTFY_TOKEN:-}"

CRITICAL_AT="${NTFY_CRITICAL_AT:-5}"
STALL_SECS="${NTFY_STALL_SECS:-150}"
ALERT_AFTER="${NTFY_ALERT_AFTER:-5}"

# systemd's StateDirectory= makes this; the fallback is for running by hand.
STATE_DIR="${STATE_DIRECTORY:-${XDG_STATE_HOME:-$HOME/.local/state}/neu-ntfy}"
mkdir -p "$STATE_DIR"
CURSOR_FILE="$STATE_DIR/last-id"
RC_FILE="$STATE_DIR/.last-curl-rc"

log() { printf '%s\n' "$*" >&2; }

# --- emitting -----------------------------------------------------------------

# notify() <urgency> <icon> <summary> <body>
notify() {
    notify-send --app-name="ntfy" --urgency="$1" --icon="$2" -- "$3" "$4" \
        || log "neu-ntfy: notify-send failed (no session bus?)"
}

# --- the stream ---------------------------------------------------------------

# Everything secret goes to curl over stdin rather than argv: the topic and the
# bearer token would otherwise be readable in `ps` by anything on the box.
curl_config() {
    local since="$1" url
    url="${NTFY_URL%/}/${NTFY_TOPIC}/json"
    [[ -n "$since" ]] && url="${url}?since=${since}"
    printf 'url = "%s"\n' "$url"
    [[ -n "$NTFY_TOKEN" ]] && printf 'header = "Authorization: Bearer %s"\n' "$NTFY_TOKEN"
    return 0
}

# One connection. Returns when the stream ends for any reason; curl's exit
# status is left in RC_FILE because the caller has to tell "the server said no"
# apart from "the server was not there", and a pipeline into a process
# substitution has nowhere else to put it.
stream_once() {
    local since="$1"

    # --speed-limit/--speed-time is the stall detector, and the reason this does
    # not need a read timeout of its own: ntfy sends a keepalive every ~45s, so a
    # connection carrying less than a byte a second for STALL_SECS is a dead TCP
    # session that nobody has told us about. That -- not a clean disconnect -- is
    # the 3am failure this is designed against.
    #
    # --fail is what makes an HTTP rejection legible: without it curl prints the
    # error body and exits 0, and a 400 from a stale cursor is indistinguishable
    # from a healthy stream that ended.
    { curl_config "$since" \
        | curl --config - \
               --silent --show-error --no-buffer --location --fail \
               --speed-limit 1 --speed-time "$STALL_SECS"
      printf '%s' "$?" > "$RC_FILE"
    } | jq --unbuffered -rc '
            [ (.event // "unknown"),
              (.id // ""),
              ((.priority // 3) | tostring),
              ((.title // "") | @base64),
              ((.message // "") | @base64),
              (((.tags // []) | join(", ")) | @base64)
            ] | @tsv'
}

# Decode one message row and put it on the bus.
emit() {
    local id="$1" prio="$2" title_b64="$3" msg_b64="$4" tags_b64="$5"
    local title msg tags urgency icon summary body

    title=$(printf '%s' "$title_b64" | base64 -d 2>/dev/null)
    msg=$(printf '%s' "$msg_b64" | base64 -d 2>/dev/null)
    tags=$(printf '%s' "$tags_b64" | base64 -d 2>/dev/null)

    # ntfy priorities are 1 min / 2 low / 3 default / 4 high / 5 max. Only max
    # is critical by default, because critical toasts never time out (see
    # Toast.qml) and a wall of sticky popups is how an alert channel gets muted.
    # Set NTFY_CRITICAL_AT=4 to make "high" sticky too.
    if (( prio >= CRITICAL_AT )); then
        urgency=critical; icon=dialog-error
    elif (( prio >= 4 )); then
        urgency=normal;   icon=dialog-warning
    elif (( prio <= 2 )); then
        urgency=low;      icon=dialog-information
    else
        urgency=normal;   icon=dialog-information
    fi

    # An untitled ntfy message is all body. Promoting it to the summary is what
    # makes it readable in a toast, which has no room for an empty headline.
    if [[ -n "$title" ]]; then
        summary="$title"; body="$msg"
    else
        summary="$msg";   body=""
    fi

    # Tags ride along on their own line rather than being rendered as emoji:
    # reproducing ntfy's shortcode table here would rot the moment they add one.
    [[ -n "$tags" ]] && body="${body:+$body$'\n'}tags: $tags"

    notify "$urgency" "$icon" "$summary" "$body"
    [[ -n "$id" ]] && printf '%s' "$id" > "$CURSOR_FILE"
}

# --- reconnect loop -----------------------------------------------------------

backoff=5
failures=0
alerted=0

# Resume from the last message seen, so a reconnect does not silently swallow
# whatever arrived while the link was down. Absent on a first run, which is
# correct: a fresh subscriber wants new messages, not the backlog.
since=""
[[ -r "$CURSOR_FILE" ]] && since=$(<"$CURSOR_FILE")

log "neu-ntfy: subscribing to ${NTFY_URL%/} (topic hidden), stall=${STALL_SECS}s"

while :; do
    : > "$RC_FILE"

    while IFS=$'\t' read -r event id prio title_b64 msg_b64 tags_b64; do
        case "$event" in
            open)
                failures=0
                backoff=5
                if (( alerted )); then
                    notify low dialog-information "ntfy reconnected" \
                        "Fleet notifications are flowing again."
                    alerted=0
                fi
                ;;
            message)
                emit "$id" "$prio" "$title_b64" "$msg_b64" "$tags_b64"
                ;;
            *)
                # keepalive / poll_request: nothing to show, but the bytes are
                # what prove the connection is still alive to curl.
                ;;
        esac
    done < <(stream_once "$since")

    rc=$(<"$RC_FILE") || rc=""
    [[ -z "$rc" ]] && rc=0

    # curl exit 22 is the only one that means the SERVER refused the request --
    # a cursor it has aged out being the likely cause. Every other failure (7
    # cannot connect, 6 cannot resolve, 28 timed out, 56 recv error) is the link,
    # and throwing the cursor away for one of those is how a five-minute outage
    # turns into five minutes of silently dropped alerts.
    if (( rc == 22 )) && [[ -n "$since" ]]; then
        log "neu-ntfy: server rejected since=$since, resubscribing from now"
        since=""
        rm -f "$CURSOR_FILE"
    else
        [[ -r "$CURSOR_FILE" ]] && since=$(<"$CURSOR_FILE")
    fi

    failures=$(( failures + 1 ))

    # The whole point: a subscriber that quietly stops looks exactly like a quiet
    # night. After enough consecutive failures, say so on the desktop -- once,
    # until it comes back -- so silence is never ambiguous.
    if (( failures >= ALERT_AFTER && alerted == 0 )); then
        notify critical dialog-error "ntfy subscriber offline" \
            "Cannot reach the fleet ntfy server after $failures attempts. Fleet alerts are NOT arriving."
        alerted=1
    fi

    log "neu-ntfy: stream ended (curl=$rc, failures=$failures), retrying in ${backoff}s"
    sleep "$backoff"
    backoff=$(( backoff * 2 ))
    (( backoff > 60 )) && backoff=60
done
