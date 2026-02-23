#!/bin/bash

bat1_cap=$(cat /sys/class/power_supply/BAT1/capacity)
bat0_cap=$(cat /sys/class/power_supply/BAT0/capacity)
bat1_status=$(cat /sys/class/power_supply/BAT1/status)

# Icon based on BAT1 (external)
discharge_icons=(󰂎 󰁺 󰁻 󰁼 󰁽 󰁾 󰁿 󰁿 󰂁 󰂂 󰁹)
charge_icons=(󰢜 󰂆 󰂇 󰂈 󰢝 󰂉 󰢞 󰂊 󰂋)

idx=$(( bat1_cap / 10 ))

if [[ "$bat1_status" == "Full" ]]; then
    icon="󱟢"
elif [[ "$bat1_status" == "Charging" ]]; then
    (( idx > 8 )) && idx=8
    icon="${charge_icons[$idx]}"
else
    (( idx > 10 )) && idx=10
    icon="${discharge_icons[$idx]}"
fi

# CSS class based on BAT1
class=""
if [[ "$bat1_status" == "Full" ]]; then
    class="full"
elif (( bat1_cap <= 15 )); then
    class="critical"
elif (( bat1_cap <= 30 )); then
    class="warning"
fi

tooltip="bat1: ${bat1_cap}%  bat0: ${bat0_cap}%"

printf '{"text": "%s", "tooltip": "%s", "class": "%s"}\n' "$icon" "$tooltip" "$class"
