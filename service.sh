#!/system/bin/sh
if ! [ -f "/data/local/tests/system/mega" ]; then
    # exit 1
    # 去掉验证
    true
fi

MOD_PATH=$(dirname "$0")

MOD_PROP="${MOD_PATH}/module.prop"
A_SCRIPT="${MOD_PATH}/temp_static.sh"
B_SCRIPT="${MOD_PATH}/temp_dyn.sh"
C_SCRIPT="${MOD_PATH}/g_sample.sh"
D_SCRIPT="${MOD_PATH}/sample_dyn.sh"
E_SCRIPT="${MOD_PATH}/fast_charge.sh"
gu_path="/proc/oplus-votable/GAUGE_UPDATE"

WAIT_FOR_SYSTEMUI() {
  while true; do
    if [ -d "/sdcard/Android" ] && pgrep systemui > /dev/null; then
      break
    fi
    sleep 1
  done
}

SETUP_TEMP() {
  echo 1 > /proc/game_opt/disable_cpufreq_limit 2>/dev/null
  chmod 444 /proc/game_opt/disable_cpufreq_limit 2>/dev/null
  setprop persist.sys.oplus.wifi.sla.game_high_temperature 55 
  setprop persist.sys.environment.temp 35
    
  if [ -d "$gu_path" ]; then
    echo '2000' > "$gu_path/force_val" 2>/dev/null
    echo '1' > "$gu_path/force_active" 2>/dev/null
    chmod 666 "$gu_path/force_val" 2>/dev/null
    chmod 666 "$gu_path/force_active" 2>/dev/null
  fi
}

START_SCRIPT() {
    local script_path="$1"
    nohup sh "$script_path" &
}

SET_HORAE_STATUS() {
    local target_status="$1"
    local current_status=$(getprop persist.sys.horae.enable)
    if [ "$target_status" -eq 1 ]; then
        if [ "$current_status" != "1" ]; then
            setprop persist.sys.horae.enable 1
            start horae 2>/dev/null
            sleep 2
            nohup sh "$A_SCRIPT" &
        fi
    else
        if [ "$current_status" != "0" ]; then
            setprop persist.sys.horae.enable 0
            stop horae 2>/dev/null
            sleep 2
            nohup sh "$A_SCRIPT" &
        fi
    fi
}

TOMBSTONE_CONTROL() {
    if [ "$1" -eq 1 ]; then
        mkdir -p /sys/fs/cgroup/frozen/ /sys/fs/cgroup/unfrozen/
        chown system:system /sys/fs/cgroup/frozen/cgroup.procs
        chown system:system /sys/fs/cgroup/frozen/cgroup.freeze
        chown system:system /sys/fs/cgroup/unfrozen/cgroup.procs
        chown system:system /sys/fs/cgroup/unfrozen/cgroup.freeze
        echo 1 > /sys/fs/cgroup/frozen/cgroup.freeze
        echo 1 > /sys/fs/cgroup/unfrozen/cgroup.freeze
    elif [ "$1" -eq 0 ]; then
        if [ -d "/sys/fs/cgroup/frozen" ]; then
            echo 0 > /sys/fs/cgroup/frozen/cgroup.freeze
            rmdir /sys/fs/cgroup/frozen
        fi
        if [ -d "/sys/fs/cgroup/unfrozen" ]; then
            echo 0 > /sys/fs/cgroup/unfrozen/cgroup.freeze
            rmdir /sys/fs/cgroup/unfrozen
        fi
    fi
}

MANAGE_THERMAL_SPOOFING() {
    local type="$1"
    local temp_val="$2"
    local temp_dir="/data/adb/modules/Caelifall_SensorDecoy/temp"
    
    mkdir -p "$temp_dir"

    local temp_string=""
    if [ "$temp_val" -ne 0 ]; then
        temp_string="${temp_val}000"
    fi

    for zone in /sys/class/thermal/thermal_zone*; do
        local zone_type=$(cat "$zone/type" 2>/dev/null)
        if [ -n "$zone_type" ]; then
            local is_matched=0
            if [ "$type" = "a" ]; then
                case "$zone_type" in cpu*|gpu*|ddr*) is_matched=1 ;; esac
            elif [ "$type" = "b" ]; then
                case "$zone_type" in cpu*|gpu*|ddr*|shell*) ;; *) is_matched=1 ;; esac
            fi

            if [ "$is_matched" -eq 1 ]; then
                local zone_name="${zone##*/}"
                local fake_temp="$temp_dir/${zone_name}_temp"

                umount -l "$zone/temp" 2>/dev/null

                if [ "$temp_val" -ne 0 ]; then
                    echo "$temp_string" > "$fake_temp"
                    mount -o bind "$fake_temp" "$zone/temp" 2>/dev/null
                fi
            fi
        fi
    done
}

read_prop() {
    grep "^$1=" "$MOD_PROP" | cut -d'=' -f2 | sed 's/\r$//'
}

RESTORE_STATE() {
    if [ ! -f "$MOD_PROP" ]; then
        return 1
    fi

    local temp_mode=$(read_prop temp_mode)
    local touch_mode=$(read_prop touch_mode)
    case "$temp_mode" in
        "DT") SET_HORAE_STATUS 1; START_SCRIPT "$B_SCRIPT";;
        "JT1") SET_HORAE_STATUS 0; [ -f "$A_SCRIPT" ] && sh "$A_SCRIPT";;
        "JT2") SET_HORAE_STATUS 1; [ -f "$A_SCRIPT" ] && sh "$A_SCRIPT";;
        "CVE") SET_HORAE_STATUS 0; START_SCRIPT "$E_SCRIPT";;
    esac

    sleep 1

    case "$touch_mode" in
        "QJ") START_SCRIPT "$C_SCRIPT";;
        "DT") START_SCRIPT "$D_SCRIPT";;
        "MR")
            touchHidlTest -c wo 0 26 0 2>/dev/null
            touchHidlTest -c wo 0 182 0 2>/dev/null
            ;;
    esac
}

PROP_UPDATE() {
    local temp_mode=$(read_prop temp_mode)
    local touch_mode=$(read_prop touch_mode)
    local tomb_mode=$(read_prop tomb_mode)
    local tcpu_mode=$(read_prop tcpu_mode)
    local tnc_mode=$(read_prop tnc_mode)

    if [ "$temp_mode" = "0" ] && [ "$touch_mode" = "0" ]; then
        sed -i "s#^description=.*#description=[初始化]请点击执行▶选择模式 [注意]此模块不推荐magisk使用 请使用ksu、sukisu或apatch以获得最佳体验#" "$MOD_PROP"
        SET_HORAE_STATUS 0
        nohup sh "${A_SCRIPT}/" >/dev/null 2>&1 &
    else
        RESTORE_STATE
    fi

    sleep 2

    if [ "$tomb_mode" = "1" ]; then      
        TOMBSTONE_CONTROL 1
    else
        TOMBSTONE_CONTROL 0
    fi

    sleep 2

    if [ "$tcpu_mode" != "0" ]; then
        MANAGE_THERMAL_SPOOFING a "$tcpu_mode"
    fi

    if [ "$tnc_mode" != "0" ]; then
        MANAGE_THERMAL_SPOOFING b "$tnc_mode"
    fi    
}

WAIT_FOR_SYSTEMUI
SETUP_TEMP
PROP_UPDATE
