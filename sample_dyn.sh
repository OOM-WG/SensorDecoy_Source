#!/bin/bash
if ! [ -f "/data/local/tests/system/mega" ]; then
    # exit 1
    # 去掉验证
    true
fi
SCRIPT_DIR=$(dirname "$0")
APPS_FILE="${SCRIPT_DIR}/apps"
LOG_FILE="${SCRIPT_DIR}/dyns.log"

current_state=""
previous_app=""

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

set_rate_360() {
    local Device_market_name
    local cleaned_name
    Device_market_name=$(getprop ro.vendor.oplus.market.name)
    cleaned_name=$(echo "$Device_market_name" | tr -d ' ' | tr '[:upper:]' '[:lower:]')
    case "$cleaned_name" in
        *一加ace2*|*一加ace2v*|*一加ace2pro*|*一加ace3*|*一加ace3pro*|*一加ace3v*|*一加11*|*一加12*)
            touchHidlTest -c wo 0 26 12c
            ;;
        *一加ace5*|*一加ace5pro*|*一加ace5至尊版*|*一加ace5竞速版*|*一加13*|*一加13t*)
            touchHidlTest -c wo 0 182 360
            ;;
        *真我*)
            touchHidlTest -c wo 0 26 c
            ;;
        *)
            touchHidlTest -c wo 0 26 12c
            ;;
    esac
}

set_rate_120() {
    touchHidlTest -c wo 0 26 0
    touchHidlTest -c wo 0 182 0
}

while true; do
    foreground_app=$(dumpsys window | awk '/mCurrentFocus/ {print $NF}' | cut -d'/' -f1)

    if [ -z "$foreground_app" ]; then
        sleep 5
        continue
    fi
    
    if grep -q -x -F "$foreground_app" "$APPS_FILE"; then
        target_state="游戏"
    else
        target_state="日用"
    fi

    if [ "$foreground_app" = "com.x1y9.probe" ] && [ "$current_state" = "游戏" ]; then
        target_state="游戏"
    fi

    if [ "$target_state" != "$current_state" ]; then
        if [ -n "$current_state" ]; then
            log_message "状态切换: $current_state($previous_app) >> $target_state($foreground_app)"
        fi
        
        if [ "$target_state" = "游戏" ]; then
            set_rate_360
        else
            set_rate_120
        fi
        current_state="$target_state"
    elif [ "$current_state" = "游戏" ]; then
        set_rate_360
    fi
    
    previous_app="$foreground_app"
    sleep 5
done
