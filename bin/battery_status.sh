#!/bin/bash
# battery_status.sh - Show current, max, and % for each battery

POWER_SUPPLY="/sys/class/power_supply"

for bat_path in "$POWER_SUPPLY"/BAT*; do
    [[ -d "$bat_path" ]] || continue
    bat=$(basename "$bat_path")

    status=$(cat "$bat_path/status" 2>/dev/null)
    capacity=$(cat "$bat_path/capacity" 2>/dev/null)

    # Prefer energy_now/energy_full (µWh), fall back to charge_now/charge_full (µAh)
    energy_now=$(cat "$bat_path/energy_now" 2>/dev/null)
    energy_full=$(cat "$bat_path/energy_full" 2>/dev/null)
    charge_now=$(cat "$bat_path/charge_now" 2>/dev/null)
    charge_full=$(cat "$bat_path/charge_full" 2>/dev/null)

    echo "$bat ($status)"
    if [[ -n "$energy_now" && -n "$energy_full" && "$energy_full" -gt 0 ]] 2>/dev/null; then
        now_wh=$(awk "BEGIN {printf \"%.2f\", $energy_now / 1000000}")
        full_wh=$(awk "BEGIN {printf \"%.2f\", $energy_full / 1000000}")
        echo "  current: ${now_wh} Wh"
        echo "  max:     ${full_wh} Wh"
        echo "  pct:     ${capacity}%"
    elif [[ -n "$charge_now" && -n "$charge_full" && "$charge_full" -gt 0 ]] 2>/dev/null; then
        now_mah=$(awk "BEGIN {printf \"%.0f\", $charge_now / 1000}")
        full_mah=$(awk "BEGIN {printf \"%.0f\", $charge_full / 1000}")
        echo "  current: ${now_mah} mAh"
        echo "  max:     ${full_mah} mAh"
        echo "  pct:     ${capacity}%"
    else
        echo "  pct:     ${capacity:--}%"
    fi
done
