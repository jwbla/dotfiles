#!/bin/bash

# check for brightness value
if [ -z "$1" ]; then
    echo "Usage: $0 <brightness_value>"
    exit 1
fi

BRIGHTNESS_PATH="/sys/class/backlight/intel_backlight/brightness"

if [ ! -f "$BRIGHTNESS_PATH" ]; then
    echo "Brightness control not found at $BRIGHTNESS_PATH"
    exit 1
fi

echo "$1" | sudo tee "$BRIGHTNESS_PATH" > /dev/null

echo "Brightness set to $1"
