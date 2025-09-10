#!/system/bin/sh

if ! [ -f "/data/local/tests/system/mega" ]; then
    echo "复制大法你觉得能偷渡吗"
    echo "泄露狗的命五块钱都不值"
    # sleep 5
    # exit 1
    # 去掉验证
fi

MOD_PATH=$(dirname "$0")
O_FILE="${MOD_PATH}/wcsm"
MOD_PROP="${MOD_PATH}/module.prop"
A_SCRIPT="${MOD_PATH}/temp_static.sh"
B_SCRIPT="${MOD_PATH}/temp_dyn.sh"
C_SCRIPT="${MOD_PATH}/g_sample.sh"
D_SCRIPT="${MOD_PATH}/sample_dyn.sh"
E_SCRIPT="${MOD_PATH}/fast_charge.sh"

GET_KEY_CLICK() {
    sleep 0.5
    local key_info=$(getevent -qlc 1 | grep KEY_VOLUME)
    if [ -n "$key_info" ]; then
        case "$key_info" in
            *KEY_VOLUMEUP*) echo 0; return ;;
            *KEY_VOLUMEDOWN*) echo 1; return ;;
        esac
    fi
    echo 2
}

START_SCRIPT() {
    ps -ef | grep -Fw "sh $1" | grep -v grep > /dev/null && pkill -KILL -f "sh $1"
    sleep 0.5
    nohup sh "$1" &>/dev/null &
    sleep 0.6
}

KILL_SCRIPT() {
    if ps -ef | grep -Fw "sh $1" | grep -v grep > /dev/null; then
        pkill -KILL -f "sh $1"
        local retries=10
        while ps -ef | grep -Fw "sh $1" | grep -v grep > /dev/null && [ "$retries" -gt 0 ]; do
            sleep 0.4
            pkill -KILL -f "sh $1"
            retries=$((retries - 1))
        done
        if [ "$retries" -eq 0 ]; then
            echo "警告：无法完全终止旧模式进程。请联系作者!"
            sleep 1.5
        fi
    fi
    sleep 0.6
}

GET_HORAE_STAT() {
    if ps -ef | grep -Fw "sh $B_SCRIPT" | grep -v grep > /dev/null; then
        echo "自动"
    elif [ "$(getprop persist.sys.horae.enable)" = "1" ]; then
        echo "已启用"
    else
        echo "已禁用"
    fi
}

GET_THERMO_STAT() {
    if ps -ef | grep -Fw "sh $B_SCRIPT" | grep -v grep > /dev/null; then
        echo "动态温控"
    elif ps -ef | grep -Fw "sh $E_SCRIPT" | grep -v grep > /dev/null; then
        echo "低电量速充"
    elif [ "$(getprop persist.sys.horae.enable)" = "1" ]; then
        echo "静态二 (Horae已启用)"
    else
        echo "静态一 (Horae已禁用)"
    fi
}

GET_SAMPLING_STAT() {
    if ps -ef | grep -Fw "sh $C_SCRIPT" | grep -v grep > /dev/null; then
        echo "全局"
    elif ps -ef | grep -Fw "sh $D_SCRIPT" | grep -v grep > /dev/null; then
        echo "动态"
    else
        echo "默认"
    fi
}

GET_MOD_PROP() {
    local prop_val=$(grep "^$1=" "$MOD_PROP" | cut -d'=' -f2)
    [ -z "$prop_val" ] || [ "$prop_val" = "0" ] && echo "未启用" || echo "$prop_val"
}

SET_MOD_DESC() {
    local thermo_desc="$1"
    local touch_desc="$2"
    local static_shell="$3"
    local static_batt="$4"
    local desc_text="" temp_mode_val="" touch_mode_val=""

    case "$thermo_desc" in
        "静态一 (Horae已禁用)")
            desc_text="description=◎静态一 >> 外壳${static_shell} 电池墙${static_batt} ◎${touch_desc}采样率"
            temp_mode_val="JT1" ;;
        "静态二 (Horae已启用)")
            desc_text="description=◎静态二 >> 外壳${static_shell} 电池墙${static_batt} ◎${touch_desc}采样率"
            temp_mode_val="JT2" ;;
        "动态温控")
            desc_text="description=◎动态温控 >> In operation ◎${touch_desc}采样率"
            temp_mode_val="DT" ;;
        "低电量速充")
            desc_text="description=◎低电量速充 >> In operation ◎${touch_desc}采样率"
            temp_mode_val="CVE" ;;
        *)
            desc_text="description=◎${thermo_desc} >> In operation ◎${touch_desc}采样率"
            temp_mode_val="WZ" ;;
    esac

    case "$touch_desc" in
        "全局") touch_mode_val="QJ" ;;
        "动态") touch_mode_val="DT" ;;
        "默认") touch_mode_val="MR" ;;
        *) touch_mode_val="WZ" ;;
    esac

    sed -i "s|^description=.*|$desc_text|" "$MOD_PROP"
    grep -q "^temp_mode=" "$MOD_PROP" && sed -i "s|^temp_mode=.*|temp_mode=$temp_mode_val|" "$MOD_PROP" || echo "temp_mode=$temp_mode_val" >> "$MOD_PROP"
    grep -q "^touch_mode=" "$MOD_PROP" && sed -i "s|^touch_mode=.*|touch_mode=$touch_mode_val|" "$MOD_PROP" || echo "touch_mode=$touch_mode_val" >> "$MOD_PROP"
}

UPD_MOD_DESC() {
    local current_thermo=$(GET_THERMO_STAT)
    local current_touch=$(GET_SAMPLING_STAT)
    local temp_shell_val=$([ -r "$O_FILE" ] && grep "^TEMP_B=" "$O_FILE" | cut -d'=' -f2 || echo "0")
    local cur_shell_temp=$((temp_shell_val / 1000))
    local cur_batt_temp=$((cur_shell_temp + 15))
    SET_MOD_DESC "$current_thermo" "$current_touch" "$cur_shell_temp" "$cur_batt_temp"
}

SET_HORAE_STATUS() {
    if [ "$1" -eq 1 ]; then
        if [ "$(getprop persist.sys.horae.enable)" != "1" ]; then
            setprop persist.sys.horae.enable 1
            start horae
            echo "horae已启用。"
        else
            echo "horae已在运行，无需改动。"
        fi
    else
        if [ "$(getprop persist.sys.horae.enable)" != "0" ]; then
            setprop persist.sys.horae.enable 0
            stop horae
            echo "horae已禁用。"
        else
            echo "horae已禁用，无需改动。"
        fi
    fi
    sleep 1
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

TOMBSTONE_CONTROL() {
    if [ "$1" -eq 1 ]; then
        mkdir -p /sys/fs/cgroup/frozen/ /sys/fs/cgroup/unfrozen/
        for group in frozen unfrozen; do
            chown system:system "/sys/fs/cgroup/${group}/cgroup.procs"
            chown system:system "/sys/fs/cgroup/${group}/cgroup.freeze"
            echo 1 > "/sys/fs/cgroup/${group}/cgroup.freeze"
        done
    else
        for group in frozen unfrozen; do
            if [ -d "/sys/fs/cgroup/${group}" ]; then
                echo 0 > "/sys/fs/cgroup/${group}/cgroup.freeze"
                rmdir "/sys/fs/cgroup/${group}"
            fi
        done
    fi
}

CREATE_MENU() {
    local title="$1"
    shift
    local num_opts=$#
    local sel_idx=0

    while true; do
        echo -ne "\033[H\033[J"
        echo "$title"
        echo "-音量[+]切换选项  音量[-]确认选择"
        echo ""
        
        local i=0
        for opt in "$@"; do
            if [ "$sel_idx" -eq "$i" ]; then
                echo "   ➤ $opt"
            else
                echo "    $opt"
            fi
            i=$((i + 1))
        done
        
        case $(GET_KEY_CLICK) in
            0) sel_idx=$(((sel_idx + 1) % num_opts));;
            1) return $sel_idx;;
        esac
    done
}

DISPLAY_STATIC_TEMP_MENU() {
    local horae_state="$1"
    local thermo_mode_display
    [ "$horae_state" = "enabled" ] && thermo_mode_display="静态二 (Horae已启用)" || thermo_mode_display="静态一 (Horae已禁用)"

    local title="请选择电池温度墙&${thermo_mode_display}
调节温度墙可限制或释放充电速度
此温度墙也是游戏时的锁帧温度墙"
    
    CREATE_MENU "$title" "53" "51" "49" "47" "45" "返回上级" "退出脚本"
    local choice=$?
    local sel_temp_val
    
    case "$choice" in
        0) sel_temp_val="53";;
        1) sel_temp_val="51";;
        2) sel_temp_val="49";;
        3) sel_temp_val="47";;
        4) sel_temp_val="45";;
        5) return;;
        6) echo -ne "\033[H\033[J"; exit 0;;
    esac

    echo "您已选择 ${sel_temp_val}"
    local temp_shell_val=$(((sel_temp_val - 15) * 1000))
    sed -i "s|^TEMP_B=.*|TEMP_B=$temp_shell_val|" "$O_FILE"
    START_SCRIPT "$A_SCRIPT"
    UPD_MOD_DESC
    echo "静态温控已应用"
    sleep 1
    exit 0
}

DISPLAY_THERMO_MENU() {
    while true; do
        local current_thermo=$(GET_THERMO_STAT | sed 's/ (Horae.*)//')
        local horae_status=$(GET_HORAE_STAT)
        local title="当前温控: ${current_thermo} | horae: ${horae_status}

◨动态温控: 游戏&充电自动优化 日常恢复
◨静态温控: 手动设定温度墙和horae状态
◨低电量速充: 20%电量以下使用 可提升充电速度

请选择模式"
        
        CREATE_MENU "$title" "动态温控(自动horae)" "静态一(禁用horae)" "静态二(启用horae)" "低电量速充(测试功能)" "返回上级" "退出脚本"
        local choice=$?
        
        case "$choice" in
            0) 
                echo "切换至 动态温控..."
                KILL_SCRIPT "$E_SCRIPT"; KILL_SCRIPT "$A_SCRIPT"
                START_SCRIPT "$B_SCRIPT"
                UPD_MOD_DESC
                echo "温控模式设置成功" && sleep 1 && exit 0
                ;;
            1) 
                echo "切换至 静态一..."
                KILL_SCRIPT "$E_SCRIPT"; KILL_SCRIPT "$B_SCRIPT"
                SET_HORAE_STATUS 0
                DISPLAY_STATIC_TEMP_MENU "disabled"
                ;;
            2) 
                echo "切换至 静态二..."
                KILL_SCRIPT "$E_SCRIPT"; KILL_SCRIPT "$B_SCRIPT"
                SET_HORAE_STATUS 1
                DISPLAY_STATIC_TEMP_MENU "enabled"
                ;;
            3) 
                local batt_level=$([ -f "/sys/class/power_supply/battery/capacity" ] && cat "/sys/class/power_supply/battery/capacity" || echo "100")
                if [ "$batt_level" -gt 19 ]; then
                    echo "电量高于20%，无法启用低电量速充模式。"
                    sleep 2
                    continue
                fi
                echo "切换至 低电量速充..."
                KILL_SCRIPT "$A_SCRIPT"; KILL_SCRIPT "$B_SCRIPT"
                SET_HORAE_STATUS 0
                START_SCRIPT "$E_SCRIPT"
                UPD_MOD_DESC
                echo "温控模式设置成功" && sleep 1 && exit 0
                ;;
            4) return;;
            5) echo -ne "\033[H\033[J"; exit 0;;
        esac
    done
}

DISPLAY_SAMPLING_MENU() {
    while true; do
        local current_sampling=$(GET_SAMPLING_STAT)
        local title="当前采样率模式[360]: ${current_sampling}"

        CREATE_MENU "$title" "全局采样率" "动态采样率" "恢复默认" "返回上级" "退出脚本"
        local choice=$?

        case "$choice" in
            0)
                echo "切换至 全局采样率..."
                KILL_SCRIPT "$D_SCRIPT"
                START_SCRIPT "$C_SCRIPT"
                UPD_MOD_DESC
                echo "采样率设置成功" && sleep 1 && exit 0
                ;;
            1)
                echo "切换至 动态采样率..."
                KILL_SCRIPT "$C_SCRIPT"
                START_SCRIPT "$D_SCRIPT"
                UPD_MOD_DESC
                echo "采样率设置成功" && sleep 1 && exit 0
                ;;
            2)
                echo "恢复 系统默认采样率..."
                KILL_SCRIPT "$C_SCRIPT"
                KILL_SCRIPT "$D_SCRIPT"
                touchHidlTest -c wo 0 26 0 2>/dev/null
                touchHidlTest -c wo 0 182 0 2>/dev/null
                UPD_MOD_DESC
                echo "采样率设置成功" && sleep 1 && exit 0
                ;;
            3) return;;
            4) echo -ne "\033[H\033[J"; exit 0;;
        esac
    done
}

DISPLAY_CORE_TEMP_MENU() {
    while true; do
        local current_tcpu=$(GET_MOD_PROP "tcpu_mode")
        local title="核心温度伪装 (CPU/GPU/DDR)
当前: ${current_tcpu}"

        CREATE_MENU "$title" "启用伪装" "恢复官方" "返回上级" "退出脚本"
        case $? in
            0)
                local temp_title="请选择要伪装的核心温度"
                CREATE_MENU "$temp_title" "30" "40" "45" "50" "55" "60" "70" "80" "返回上级" "退出脚本"
                local temp_choice=$?
                local sel_temp_val=""
                case "$temp_choice" in
                    0) sel_temp_val="30";; 1) sel_temp_val="40";;
                    2) sel_temp_val="45";; 3) sel_temp_val="50";;
                    4) sel_temp_val="55";; 5) sel_temp_val="60";;
                    6) sel_temp_val="70";; 7) sel_temp_val="80";;
                    8) continue;; 9) echo -ne "\033[H\033[J"; exit 0;;
                esac
                
                MANAGE_THERMAL_SPOOFING a "$sel_temp_val"
                grep -q "^tcpu_mode=" "$MOD_PROP" && sed -i "s|^tcpu_mode=.*|tcpu_mode=${sel_temp_val}|" "$MOD_PROP" || echo "tcpu_mode=${sel_temp_val}" >> "$MOD_PROP"
                echo "核心温度已伪装为 ${sel_temp_val}"
                sleep 1.5
                exit 0
                ;;
            1)
                MANAGE_THERMAL_SPOOFING a 0
                grep -q "^tcpu_mode=" "$MOD_PROP" && sed -i "s|^tcpu_mode=.*|tcpu_mode=0|" "$MOD_PROP" || echo "tcpu_mode=0" >> "$MOD_PROP"
                echo "核心温度已恢复官方实时状态"
                sleep 1.5
                exit 0
                ;;
            2) return;;
            3) echo -ne "\033[H\033[J"; exit 0;;
        esac
    done
}

DISPLAY_NON_CORE_TEMP_MENU() {
    while true; do
        local current_tnc=$(GET_MOD_PROP "tnc_mode")
        local title="非核心温度伪装
当前: ${current_tnc}"
        
        CREATE_MENU "$title" "39" "37" "35" "33" "31" "29" "恢复官方" "返回上级" "退出脚本"
        local choice=$?
        local sel_temp_val=""
        case "$choice" in
            0) sel_temp_val="39";;
            1) sel_temp_val="37";;
            2) sel_temp_val="35";;
            3) sel_temp_val="33";;
            4) sel_temp_val="31";;
            5) sel_temp_val="29";;
            6)
                MANAGE_THERMAL_SPOOFING b 0
                grep -q "^tnc_mode=" "$MOD_PROP" && sed -i "s|^tnc_mode=.*|tnc_mode=0|" "$MOD_PROP" || echo "tnc_mode=0" >> "$MOD_PROP"
                echo "非核心温度已恢复官方实时状态"
                sleep 1.5
                exit 0
                ;;
            7) return;;
            8) echo -ne "\033[H\033[J"; exit 0;;
        esac
        
        MANAGE_THERMAL_SPOOFING b "$sel_temp_val"
        grep -q "^tnc_mode=" "$MOD_PROP" && sed -i "s|^tnc_mode=.*|tnc_mode=${sel_temp_val}|" "$MOD_PROP" || echo "tnc_mode=${sel_temp_val}" >> "$MOD_PROP"
        echo "非核心温度已伪装为 ${sel_temp_val}"
        sleep 1.5
        exit 0
    done
}

DISPLAY_GLOBAL_TEMP_MENU() {
    while true; do
        local current_tcpu=$(GET_MOD_PROP "tcpu_mode")
        local current_tnc=$(GET_MOD_PROP "tnc_mode")
        local title="全域伪装(锁死传感器节点温度)
核心: ${current_tcpu} | 非核心: ${current_tnc}"

        CREATE_MENU "$title" "核心伪装" "非核心伪装" "返回上级" "退出脚本"
        case $? in
            0) DISPLAY_CORE_TEMP_MENU;;
            1) DISPLAY_NON_CORE_TEMP_MENU;;
            2) return;;
            3) echo -ne "\033[H\033[J"; exit 0;;
        esac
    done
}

DISPLAY_TOMBSTONE_MENU() {
    while true; do
        local current_tombstone=$([ -d "/sys/fs/cgroup/frozen" ] && [ -d "/sys/fs/cgroup/unfrozen" ] && echo "已开启" || echo "未启用")
        local title="ColorOS墓碑完全体
当前状态: ${current_tombstone}"
        
        CREATE_MENU "$title" "开启" "关闭" "返回上级" "退出脚本"
        case $? in
            0)
                TOMBSTONE_CONTROL 1
                grep -q "^tomb_mode=" "$MOD_PROP" && sed -i "s|^tomb_mode=.*|tomb_mode=1|" "$MOD_PROP" || echo "tomb_mode=1" >> "$MOD_PROP"
                echo "ColorOS墓碑完全体已开启"
                sleep 1.5
                exit 0
                ;;
            1)
                TOMBSTONE_CONTROL 0
                grep -q "^tomb_mode=" "$MOD_PROP" && sed -i "s|^tomb_mode=.*|tomb_mode=0|" "$MOD_PROP" || echo "tomb_mode=0" >> "$MOD_PROP"
                echo "ColorOS墓碑完全体已关闭"
                sleep 1.5
                exit 0
                ;;
            2) return;;
            3) echo -ne "\033[H\033[J"; exit 0;;
        esac
    done
}

MAIN_LOOP() {
    while true; do
        UPD_MOD_DESC
        local s_stat=$(GET_SAMPLING_STAT)
        local t_stat=$(GET_THERMO_STAT | sed 's/ (Horae.*)//')
        local c_stat=$(GET_MOD_PROP "tcpu_mode")
        local nc_stat=$(GET_MOD_PROP "tnc_mode")
        local m_stat=$([ -d "/sys/fs/cgroup/frozen" ] && [ -d "/sys/fs/cgroup/unfrozen" ] && echo "已开启" || echo "未启用")
        local h_stat=$(GET_HORAE_STAT)
        
        local title="当前状态:
❏采样率: ${s_stat} | ❏温控: ${t_stat} | ❏horae: ${h_stat}
❏核心伪装: ${c_stat} | ❏非核心伪装: ${nc_stat}
❏完全墓碑: ${m_stat}


请选择要调整的选项"
        
        CREATE_MENU "$title" "超采样率" "温控模式" "全域伪装" "完全墓碑" "退出"
        case $? in
            0) DISPLAY_SAMPLING_MENU;;
            1) DISPLAY_THERMO_MENU;;
            2) DISPLAY_GLOBAL_TEMP_MENU;;
            3) DISPLAY_TOMBSTONE_MENU;;
            4) echo -ne "\033[H\033[J"; exit 0;;
        esac
    done
}

MAIN_LOOP
