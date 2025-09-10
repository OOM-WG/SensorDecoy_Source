#!/system/bin/sh
if ! [ -f "/data/local/tests/system/mega" ]; then
    # exit 1
    # 去掉验证
    true
fi
SCRIPT_DIR=$(dirname "$0")
APPS_FILE="${SCRIPT_DIR}/apps"
O_FILE="${SCRIPT_DIR}/wcsm"
A_SCRIPT="${SCRIPT_DIR}/temp_static.sh"
LOG_FILE="${SCRIPT_DIR}/dynt.log"
> "$LOG_FILE"

log() {
  echo "$(date +'%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

enhance_temp() {
    source "$O_FILE"
    for tz in /sys/class/thermal/*; do
        if [ -f "$tz/temp" ]; then
            case "$(cat "$tz/type")" in
                shell*)
                    echo "$TEMP_B" > "$tz/emul_temp"
                    ;;
            esac
        fi
    done
    for i in $(seq 0 9); do echo "$i $TEMP_B" > /proc/shell-temp; done
}

get_current_mode() {
  local battery_status is_charging=0
  local foreground_app is_game=0

  battery_status=$(cat /sys/class/power_supply/battery/status)
  [[ "$battery_status" == "Charging" || "$battery_status" == "Full" ]] && is_charging=1

  foreground_app=$(dumpsys window | awk '/mCurrentFocus/ {print $NF}' | cut -d'/' -f1)
  grep -Fq "$foreground_app" "$APPS_FILE" && is_game=1

  if (( is_charging && is_game )); then
    echo "充电&游戏"
  elif (( is_charging )); then
    echo "充电"
  elif (( is_game )); then
    echo "游戏"
  else
    echo "日用"
  fi
}

handle_mode_change() {
  local current_mode=$1
  local action_description=""

  case "$current_mode" in
    "日用")
      setprop init.svc.thermal-engine running
      setprop persist.sys.horae.enable 1 && setprop ctl.start horae
      action_description="热管理服务运行中"
      ;;
    *)
      setprop init.svc.thermal-engine stopped
      setprop persist.sys.horae.enable 0 && setprop ctl.stop horae       
      action_description="热管理服务已禁用"
      ;;
  esac
  echo "$action_description"
}

check_and_log_mode_change() {
  local -n last_mode_ref=$1
  local current_mode
  
  current_mode=$(get_current_mode)
  if [[ "$current_mode" != "$last_mode_ref" ]]; then
    action_description=$(handle_mode_change "$current_mode")
    if [[ -z "$last_mode_ref" ]]; then
      log "设备当前为[${current_mode}]状态 ${action_description}"
    else
      log "由[${last_mode_ref}]状态变为[${current_mode}]状态 ${action_description}"
    fi
    last_mode_ref="$current_mode"
  fi
}

monitor_and_switch_modes() {
  local last_mode=""
  while true; do
    for i in $(seq 1 4); do
      check_and_log_mode_change last_mode
      sleep 5
    done
    enhance_temp
  done
}

log "动态温控已启动…"
sed -i "s|^TEMP_SHELL=.*|TEMP_SHELL=38000|" "$O_FILE"
nohup sh "$A_SCRIPT" >/dev/null 2>&1 &
monitor_and_switch_modes
