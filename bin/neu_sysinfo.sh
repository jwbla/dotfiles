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

esc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

# ---- battery ---------------------------------------------------------------
# Laptops in this set have either one battery (BAT1) or two (BAT0 + BAT1), so
# every pack sysfs exposes is reported in `bats` and the bar draws an icon per
# pack. `bat` stays alongside it as the one aggregate the control centre footer
# reads: charge is summed in energy (uWh) or charge (uAh) units wherever sysfs
# offers them, so a small empty pack beside a large full one reports the real
# remaining charge instead of the mean of two percentages.
bats="" bat_pct=null bat_status=unknown ac=false
sum_now=0 sum_full=0 pct_sum=0 n=0
any_charging=false any_discharging=false all_full=true first_status=unknown

for b in "$PS"/BAT*; do
    [[ -r "$b/capacity" ]] || continue
    pct=$(<"$b/capacity")
    [[ "$pct" =~ ^[0-9]+$ ]] || continue

    st=unknown
    [[ -r "$b/status" ]] && st=$(<"$b/status")

    # energy_* (uWh) on most Intel laptops, charge_* (uAh) on the rest.
    now="" full=""
    for unit in energy charge; do
        if [[ -r "$b/${unit}_now" && -r "$b/${unit}_full" ]]; then
            now=$(<"$b/${unit}_now"); full=$(<"$b/${unit}_full")
            break
        fi
    done
    if [[ "$now" =~ ^[0-9]+$ && "$full" =~ ^[0-9]+$ ]] && (( full > 0 )); then
        sum_now=$((sum_now + now)); sum_full=$((sum_full + full))
    fi

    (( n == 0 )) && first_status=$st
    pct_sum=$((pct_sum + pct)); n=$((n + 1))
    [[ "$st" == Charging ]] && any_charging=true
    [[ "$st" == Discharging ]] && any_discharging=true
    [[ "$st" == Full ]] || all_full=false

    bats+="${bats:+,}{\"name\":\"$(esc "${b##*/}")\",\"pct\":$pct,\"status\":\"$(esc "$st")\"}"
done

if (( n > 0 )); then
    # Weighted where sysfs allows it, plain mean where it does not. Every pack
    # contributed to sum_full or none did -- a partial sum would understate.
    if (( sum_full > 0 )); then
        bat_pct=$(( (sum_now * 100 + sum_full / 2) / sum_full ))
    else
        bat_pct=$(( (pct_sum + n / 2) / n ))
    fi
    (( bat_pct > 100 )) && bat_pct=100   # energy_now overshoots a degraded energy_full
    if [[ "$any_charging" == true ]]; then bat_status=Charging
    elif [[ "$all_full" == true ]]; then bat_status=Full
    elif [[ "$any_discharging" == true ]]; then bat_status=Discharging
    else bat_status=$first_status
    fi
fi

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

# Load average, normalised per core -- 1.0 means "every core has a runnable
# process waiting". Reported alongside cpu% because they answer different
# questions: cpu% saturates at 1.0 and cannot tell a busy box from a buried one,
# which is exactly the difference that matters while CI is running here.
read -r l1 _ _ _ _ </proc/loadavg
cores=$(nproc 2>/dev/null || echo 1)
load=$(awk -v l="$l1" -v c="$cores" 'BEGIN{printf "%.2f", (c > 0 ? l/c : l)}')

mem=$(awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{if(t)printf "%.3f",(t-a)/t; else print 0}' /proc/meminfo)
disk=$(df --output=pcent / 2>/dev/null | awk 'NR==2{gsub(/%/,"");printf "%.3f", $1/100}')

cat <<JSON
{"bat":{"pct":${bat_pct:-null},"status":"$(esc "$bat_status")","ac":$ac},
 "bats":[$bats],
 "net":{"kind":"$net_kind","name":"$(esc "$net_name")","signal":${net_signal:-null},"up":$net_up},
 "vol":{"pct":${vol_pct:-null},"muted":$vol_muted},
 "cpu":${cpu:-0},"mem":${mem:-0},"disk":${disk:-0},
 "load":{"norm":${load:-0},"avg1":${l1:-0},"cores":${cores:-1}}}
JSON
