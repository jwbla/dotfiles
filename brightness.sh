#!/bin/bash

# Read current brightness
CURRENT=$(cat /sys/class/backlight/intel_backlight/brightness)

# Add 250 to current brightness
NEW=$((CURRENT + 250))

# If new value exceeds 1250, set to 250 instead
if [ "$NEW" -gt 1250 ]; then
    NEW=250
fi

# Set the new brightness
echo "$NEW" | sudo tee /sys/class/backlight/intel_backlight/brightness
