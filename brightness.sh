#!/bin/bash

BRIGHTNESS_PATH="/sys/class/backlight/intel_backlight"
CURRENT=$(cat "$BRIGHTNESS_PATH/brightness")
MAX=$(cat "$BRIGHTNESS_PATH/max_brightness")
MIN=1

case "$1" in
    --inc)
        NEW=$((CURRENT + $2))
        [ "$NEW" -gt "$MAX" ] && NEW=$MAX
        ;;
    --dec)
        NEW=$((CURRENT - $2))
        [ "$NEW" -lt "$MIN" ] && NEW=$MIN
        ;;
    --max)
        NEW=$MAX
        ;;
    --min)
        NEW=$MIN
        ;;
    *)
        # Default: cycle brightness
        NEW=$((CURRENT + 250))
        [ "$NEW" -gt "$MAX" ] && NEW=250
        ;;
esac

echo "$NEW" | sudo tee "$BRIGHTNESS_PATH/brightness"
