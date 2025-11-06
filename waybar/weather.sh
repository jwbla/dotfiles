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

# Extract sunrise and sunset times
SUNRISE_RAW=$(echo "$WEATHER_DATA" | jq -r '.current_condition[0].sunrise // "N/A"' 2>/dev/null)
SUNSET_RAW=$(echo "$WEATHER_DATA" | jq -r '.current_condition[0].sunset // "N/A"' 2>/dev/null)

# Format sunrise/sunset times (convert from HHmm to HH:MM)
format_time() {
    local time_str=$1
    if [ "$time_str" != "N/A" ] && [ -n "$time_str" ]; then
        # Extract hours and minutes (format is HHmm)
        local hours="${time_str:0:2}"
        local minutes="${time_str:2:2}"
        echo "${hours}:${minutes}"
    else
        echo "N/A"
    fi
}

SUNRISE=$(format_time "$SUNRISE_RAW")
SUNSET=$(format_time "$SUNSET_RAW")

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

# Build 5-day forecast
FORECAST=""
FORECAST_COUNT=$(echo "$WEATHER_DATA" | jq '.weather | length' 2>/dev/null)
MAX_DAYS=$((FORECAST_COUNT < 5 ? FORECAST_COUNT : 5))

for i in $(seq 0 $((MAX_DAYS - 1))); do
    # Get forecast data for each day
    DATE=$(echo "$WEATHER_DATA" | jq -r ".weather[$i].date" 2>/dev/null)
    MAX_TEMP=$(echo "$WEATHER_DATA" | jq -r ".weather[$i].maxtempF // \"N/A\"" 2>/dev/null)
    MIN_TEMP=$(echo "$WEATHER_DATA" | jq -r ".weather[$i].mintempF // \"N/A\"" 2>/dev/null)
    DAY_CONDITION=$(echo "$WEATHER_DATA" | jq -r ".weather[$i].hourly[0].weatherDesc[0].value // \"Unknown\"" 2>/dev/null)
    
    # Format date (convert YYYY-MM-DD to Day, Mon DD)
    if [ "$DATE" != "null" ] && [ -n "$DATE" ]; then
        FORMATTED_DATE=$(date -d "$DATE" +"%a, %b %d" 2>/dev/null || echo "$DATE")
    else
        FORMATTED_DATE="N/A"
    fi
    
    # Build forecast line
    if [ -n "$FORECAST" ]; then
        FORECAST="${FORECAST}\n"
    fi
    FORECAST="${FORECAST}${FORMATTED_DATE}: ${MIN_TEMP}°F / ${MAX_TEMP}°F - ${DAY_CONDITION}"
done

# Format output for Waybar
TEXT="$ICON ${TEMP}°F"
TOOLTIP="📍 $LOCATION: $CONDITION\n"
TOOLTIP="${TOOLTIP}🌅 Sunrise: $SUNRISE  |  🌇 Sunset: $SUNSET\n"
TOOLTIP="${TOOLTIP}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
TOOLTIP="${TOOLTIP}📅 5-Day Forecast:\n"
TOOLTIP="${TOOLTIP}${FORECAST}"

# Escape newlines and quotes for JSON
TOOLTIP_ESCAPED=$(echo -e "$TOOLTIP" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')

echo "{\"text\": \"$TEXT\", \"tooltip\": \"$TOOLTIP_ESCAPED\"}"
