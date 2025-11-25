#!/bin/bash

# Weather fetcher script
# Fetches weather data from OpenWeatherMap (preferred) or wttr.in (fallback)
# Saves data to ~/.config/weather.json
# Run this script manually or set up a cron job to run it every 30 minutes:
# */30 * * * * /home/$USER/.config/waybar/fetch_weather.sh

WEATHER_JSON="$HOME/.config/weather.json"
DEFAULT_LOCATION="Acworth,GA,US"

# Ensure .config directory exists
mkdir -p "$HOME/.config"

# Read location from existing weather.json or use default
if [ -f "$WEATHER_JSON" ]; then
    EXISTING_LOCATION=$(jq -r '.location // empty' "$WEATHER_JSON" 2>/dev/null)
    if [ -n "$EXISTING_LOCATION" ] && [ "$EXISTING_LOCATION" != "null" ]; then
        LOCATION="$EXISTING_LOCATION"
    else
        LOCATION="$DEFAULT_LOCATION"
    fi
else
    LOCATION="$DEFAULT_LOCATION"
fi

# Try OpenWeatherMap API first if API key is set
if [ -n "$OPEN_WEATHER_API_KEY" ]; then
    WEATHER_DATA=$(curl -s "https://api.openweathermap.org/data/2.5/weather?q=${LOCATION}&appid=${OPEN_WEATHER_API_KEY}&units=imperial" 2>/dev/null)
    
    # Check if curl was successful and data is valid
    if [ $? -eq 0 ] && [ -n "$WEATHER_DATA" ]; then
        # Validate JSON by checking if jq can parse it
        if echo "$WEATHER_DATA" | jq . >/dev/null 2>&1; then
            # Check for API errors
            if ! echo "$WEATHER_DATA" | jq -e '.cod' >/dev/null 2>&1 || [ "$(echo "$WEATHER_DATA" | jq -r '.cod')" = "200" ]; then
                # Add location and source fields to the JSON
                ENRICHED_DATA=$(echo "$WEATHER_DATA" | jq --arg loc "$LOCATION" '. + {location: $loc, source: "openweathermap"}')
                echo "$ENRICHED_DATA" > "$WEATHER_JSON"
                exit 0
            fi
        fi
    fi
fi

# Fallback to wttr.in
# Extract city name from location (first part before comma)
CITY_NAME=$(echo "$LOCATION" | cut -d',' -f1)
WEATHER_DATA=$(curl -s "wttr.in/${CITY_NAME}?format=j1" 2>/dev/null)

# Check if curl was successful and data is valid
if [ $? -eq 0 ] && [ -n "$WEATHER_DATA" ]; then
    # Validate JSON by checking if jq can parse it
    if echo "$WEATHER_DATA" | jq . >/dev/null 2>&1; then
        # Add location and source fields to the JSON
        ENRICHED_DATA=$(echo "$WEATHER_DATA" | jq --arg loc "$LOCATION" '. + {location: $loc, source: "wttr"}')
        echo "$ENRICHED_DATA" > "$WEATHER_JSON"
        exit 0
    fi
fi

# If we get here, both fetches failed
# If the file doesn't exist, create a placeholder with location
if [ ! -f "$WEATHER_JSON" ]; then
    echo "{\"error\": \"Weather data unavailable\", \"location\": \"$LOCATION\"}" | jq . > "$WEATHER_JSON"
fi

exit 1

