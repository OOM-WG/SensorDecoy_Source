#!/system/bin/sh
if ! [ -f "/data/local/tests/system/mega" ]; then
    # exit 1
    # 去掉验证
    true
fi
SCRIPT_DIR=$(dirname "$0")
O_FILE="${SCRIPT_DIR}/wcsm"
A_SCRIPT="${SCRIPT_DIR}/temp_static.sh"
BATTERY_LEVEL=$(cat /sys/class/power_supply/battery/capacity)
if [ "$BATTERY_LEVEL" -ge 20 ]; then
  exit 0
fi

GET_AND_CALC_POWER() {
    BATT_VOLT=$(cat /sys/class/power_supply/battery/voltage_now)
    BATT_CURR=$(cat /sys/class/power_supply/battery/current_now)
    if [ "$BATT_VOLT" -ne 0 ] && [ "$BATT_CURR" -ne 0 ]; then
        PWR_RAW=$(echo "scale=2; $BATT_VOLT*$BATT_CURR/1000000000" | bc)
        CHARGE_PWR=$(echo "scale=2; sqrt($PWR_RAW*$PWR_RAW) * 2" | bc)
    else
        CHARGE_PWR="0"
    fi
}

while true; do
  STATUS=$(cat /sys/class/power_supply/battery/status)
  if [ "$STATUS" = "Charging" ]; then
    break
  fi
  sleep 1
done

while true; do
  for I in $(seq 1 9); do
    nohup sh "$A_SCRIPT" >/dev/null 2>&1 &
    sleep 19
  done
  
  BATTERY_LEVEL=$(cat /sys/class/power_supply/battery/capacity)
  if [ "$BATTERY_LEVEL" -lt 55 ]; then
   
    echo 0 > /sys/devices/virtual/oplus_chg/battery/mmi_charging_enable 2>/dev/null
    
    while true; do
      sleep 0.01
      GET_AND_CALC_POWER
      if (( $(echo "$CHARGE_PWR < 10" | bc -l) )); then
        echo 1 > /sys/devices/virtual/oplus_chg/battery/mmi_charging_enable 2>/dev/null
        sleep 9
        GET_AND_CALC_POWER
        if (( $(echo "$CHARGE_PWR >= 20" | bc -l) )); then
          break
        else
          echo 0 > /sys/devices/virtual/oplus_chg/battery/mmi_charging_enable 2>/dev/null
        fi
      fi
    done
  fi
done

