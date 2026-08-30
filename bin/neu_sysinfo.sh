#!/usr/bin/env bash
# One JSON blob of everything the neu bar polls, so the shell spawns one process
# per tick instead of five.
#
# Deliberately reads sysfs and plain CLI tools rather than Quickshell's built-in
# services: this machine runs PulseAudio (not PipeWire), iwd + systemd-networkd
# (not NetworkManager), and Quickshell's UPower binding reports no devices here.
# sysfs cannot go missing.
set -uo pipefail

PS=/sys/class/power_supply

# ---- battery ---------------------------------------------------------------
bat_pct=null bat_status=unknown ac=false
for b in "$PS"/BAT*; do
    [[ -d "$b" ]] || continue
    bat_pct=$(<"$b/capacity") 2>/dev/null || bat_pct=null
    bat_status=$(<"$b/status") 2>/dev/null || bat_status=unknown
    break
done
for a in "$PS"/A{C,DP}* "$PS"/ACAD; do
    [[ -r "$a/online" ]] || continue
    [[ "$(<"$a/online")" == 1 ]] && ac=true
    break
done

# ---- network ---------------------------------------------------------------
net_kind=none net_name="" net_signal=null net_up=false
wif=$(iw dev 2>/dev/null | awk '/Interface/{print $2; exit}')
if [[ -n "$wif" ]]; then
    link=$(iw dev "$wif" link 2>/dev/null)
    if [[ "$link" != *"Not connected"* && -n "$link" ]]; then
        net_kind=wifi
        net_name=$(awk '/SSID:/{ $1=""; sub(/^ /,""); print; exit }' <<<"$link")
        net_signal=$(awk '/signal:/{print $2; exit}' <<<"$link")
        net_up=true
    fi
fi
if [[ "$net_up" == false ]]; then
    eth=$(ip -br link 2>/dev/null | awk '$1!~/^(lo|wlan|docker|veth|br-)/ && $2=="UP"{print $1; exit}')
    if [[ -n "$eth" ]]; then
        net_kind=ethernet net_name="$eth" net_up=true
    fi
fi

# ---- volume (PulseAudio) ---------------------------------------------------
vol_pct=null vol_muted=false
if command -v pactl >/dev/null 2>&1; then
    v=$(pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | grep -oP '\d+(?=%)' | head -1)
    [[ -n "$v" ]] && vol_pct=$v
    [[ "$(pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null)" == *yes* ]] && vol_muted=true
fi

# ---- cpu / memory / disk ---------------------------------------------------
read -r _ u n s i rest </proc/stat
busy=$((u + n + s)); total=$((busy + i))
cache="${XDG_RUNTIME_DIR:-/tmp}/neu-cpu"
cpu=0
if [[ -r "$cache" ]]; then
    read -r pb pt <"$cache"
    db=$((busy - pb)); dt=$((total - pt))
    (( dt > 0 )) && cpu=$(awk -v b="$db" -v t="$dt" 'BEGIN{printf "%.3f", b/t}')
fi
printf '%s %s\n' "$busy" "$total" >"$cache"

mem=$(awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{if(t)printf "%.3f",(t-a)/t; else print 0}' /proc/meminfo)
disk=$(df --output=pcent / 2>/dev/null | awk 'NR==2{gsub(/%/,"");printf "%.3f", $1/100}')

esc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

cat <<JSON
{"bat":{"pct":${bat_pct:-null},"status":"$(esc "$bat_status")","ac":$ac},
 "net":{"kind":"$net_kind","name":"$(esc "$net_name")","signal":${net_signal:-null},"up":$net_up},
 "vol":{"pct":${vol_pct:-null},"muted":$vol_muted},
 "cpu":${cpu:-0},"mem":${mem:-0},"disk":${disk:-0}}
JSON
