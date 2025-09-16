#!/bin/bash

# Weather script for Waybar
# Fetches weather data from wttr.in and formats it for display

# Get weather data in JSON format
WEATHER_DATA=$(curl -s 'wttr.in/Acworth?format=j1' 2>/dev/null)

# Check if curl was successful
if [ $? -ne 0 ] || [ -z "$WEATHER_DATA" ]; then
    echo '{"text": "🌤️ --", "tooltip": "Weather unavailable"}'
    exit 0
fi

# Extract temperature and condition using jq
TEMP=$(echo "$WEATHER_DATA" | jq -r '.current_condition[0].temp_F // "N/A"' 2>/dev/null)
CONDITION=$(echo "$WEATHER_DATA" | jq -r '.current_condition[0].weatherDesc[0].value // "Unknown"' 2>/dev/null)
LOCATION=$(echo "$WEATHER_DATA" | jq -r '.nearest_area[0].areaName[0].value // "Unknown"' 2>/dev/null)

# Weather icons based on condition
case "$CONDITION" in
    *"Sunny"*|*"Clear"*) ICON="☀️" ;;
    *"Cloud"*) ICON="☁️" ;;
    *"Rain"*|*"Drizzle"*) ICON="🌧️" ;;
    *"Snow"*) ICON="❄️" ;;
    *"Thunder"*|*"Storm"*) ICON="⛈️" ;;
    *"Fog"*|*"Mist"*) ICON="🌫️" ;;
    *) ICON="🌤️" ;;
esac

# Format output for Waybar
TEXT="$ICON ${TEMP}°F"
TOOLTIP="Weather in $LOCATION: $CONDITION"

echo "{\"text\": \"$TEXT\", \"tooltip\": \"$TOOLTIP\"}"
