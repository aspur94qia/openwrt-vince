#!/bin/sh
LED_DIR="/sys/class/leds/white:status"
[ -f "$LED_DIR/brightness" ] || LED_DIR=$(ls -d /sys/class/leds/* 2>/dev/null | grep -viE 'flash|torch|backlight|lcd|button|kbd' | head -n 1)
LED="$LED_DIR/brightness"
[ -f "$LED" ] || exit 0
while true; do
    AP_ACTIVE=$(ubus call network.wireless status 2>/dev/null | grep -c '"up": true')
    SIM_UP=$(ifstatus wan_sim 2>/dev/null | jsonfilter -e '@.up' 2>/dev/null)
    if [ "$AP_ACTIVE" -gt 0 ]; then
        echo 255 > "$LED"; sleep 0.15; echo 0 > "$LED"; sleep 0.15
        echo 255 > "$LED"; sleep 0.15; echo 0 > "$LED"; sleep 1.5
    elif [ "$SIM_UP" = "true" ]; then
        echo 255 > "$LED"; sleep 0.2; echo 0 > "$LED"; sleep 1.5
    else
        echo 255 > "$LED"; sleep 0.1; echo 0 > "$LED"; sleep 1
    fi
done
