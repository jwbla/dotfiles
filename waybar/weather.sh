#!/bin/bash

# Weather script for Waybar
# Calls fetch script to update weather data, then reads from ~/.config/weather.json and formats it for display

WEATHER_JSON="$HOME/.config/weather.json"
FETCH_SCRIPT="$HOME/.config/waybar/fetch_weather.sh"

# Try to fetch fresh weather data
# Whether it succeeds or fails, we'll use what's in the JSON file
if [ -f "$FETCH_SCRIPT" ]; then
    "$FETCH_SCRIPT" >/dev/null 2>&1
fi

# Read weather data from JSON file
if [ ! -f "$WEATHER_JSON" ]; then
    echo '{"text": "🌤️ --", "tooltip": "Weather data not available"}'
    exit 0
fi

WEATHER_DATA=$(cat "$WEATHER_JSON" 2>/dev/null)

# Check if file is readable and contains valid data
if [ -z "$WEATHER_DATA" ] || ! echo "$WEATHER_DATA" | jq . >/dev/null 2>&1; then
    echo '{"text": "🌤️ --", "tooltip": "Weather data invalid"}'
    exit 0
fi

# Check if there's an error in the JSON
if echo "$WEATHER_DATA" | jq -e '.error' >/dev/null 2>&1; then
    echo '{"text": "🌤️ --", "tooltip": "Weather unavailable"}'
    exit 0
fi

# Detect data source
SOURCE=$(echo "$WEATHER_DATA" | jq -r '.source // empty' 2>/dev/null)

# Extract temperature, condition, and location based on source
if [ "$SOURCE" = "openweathermap" ] || echo "$WEATHER_DATA" | jq -e '.main.temp' >/dev/null 2>&1; then
    # OpenWeatherMap format
    TEMP=$(echo "$WEATHER_DATA" | jq -r '.main.temp // "N/A"' 2>/dev/null | awk '{printf "%.0f", $1}')
    CONDITION=$(echo "$WEATHER_DATA" | jq -r '.weather[0].description // "Unknown"' 2>/dev/null)
    # Use location field if present, otherwise use name field
    LOCATION=$(echo "$WEATHER_DATA" | jq -r '.location // .name // "Unknown"' 2>/dev/null)
    HAS_FORECAST=false
else
    # wttr.in format
    TEMP=$(echo "$WEATHER_DATA" | jq -r '.current_condition[0].temp_F // "N/A"' 2>/dev/null)
    CONDITION=$(echo "$WEATHER_DATA" | jq -r '.current_condition[0].weatherDesc[0].value // "Unknown"' 2>/dev/null)
    # Use location field if present, otherwise use nearest_area
    LOCATION=$(echo "$WEATHER_DATA" | jq -r '.location // .nearest_area[0].areaName[0].value // "Unknown"' 2>/dev/null)
    HAS_FORECAST=true
fi

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

# Build forecast only if available (wttr.in format)
FORECAST=""
if [ "$HAS_FORECAST" = "true" ]; then
    FORECAST_COUNT=$(echo "$WEATHER_DATA" | jq '.weather | length' 2>/dev/null)
    if [ -n "$FORECAST_COUNT" ] && [ "$FORECAST_COUNT" != "null" ] && [ "$FORECAST_COUNT" -gt 0 ]; then
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
            FORECAST="${FORECAST}<span color='#b4befe'>${FORMATTED_DATE}</span>: ${MIN_TEMP}°F / ${MAX_TEMP}°F - ${DAY_CONDITION}"
        done
    fi
fi

# Format source for display
if [ "$SOURCE" = "openweathermap" ]; then
    SOURCE_DISPLAY="OpenWeatherAPI"
elif [ "$SOURCE" = "wttr" ]; then
    SOURCE_DISPLAY="wttr.in"
else
    SOURCE_DISPLAY="Unknown"
fi

# Format output for Waybar
TEXT="$ICON ${TEMP}°F"
TOOLTIP="📍 <span color='#b4befe'>$LOCATION</span>: $CONDITION\n"
TOOLTIP="${TOOLTIP}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"

# Only add forecast section if forecast data exists
if [ -n "$FORECAST" ]; then
    TOOLTIP="${TOOLTIP}📅 3-Day Forecast:\n"
    TOOLTIP="${TOOLTIP}${FORECAST}"
fi

# Add source at the end
TOOLTIP="${TOOLTIP}\n<span color='#6c7086'>(source: $SOURCE_DISPLAY)</span>"

# Escape newlines and quotes for JSON
TOOLTIP_ESCAPED=$(echo -e "$TOOLTIP" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')

echo "{\"text\": \"$TEXT\", \"tooltip\": \"$TOOLTIP_ESCAPED\"}"
