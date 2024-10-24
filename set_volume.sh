#!/bin/bash

# check for brightness value
if [ -z "$1" ]; then
    echo "Usage: $0 <volume_value>%"
    exit 1
fi

pactl set-sink-volume @DEFAULT_SINK@ $1%

echo "Volume to set to $1%"
