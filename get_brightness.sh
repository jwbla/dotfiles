#!/bin/bash

CURRENT_BRIGHTNESS=$(cat /sys/class/backlight/intel_backlight/brightness)

MAX_BRIGHTNESS=$(cat /sys/class/backlight/intel_backlight/max_brightness)

echo "Brightness: $CURRENT_BRIGHTNESS/$MAX_BRIGHTNESS"
