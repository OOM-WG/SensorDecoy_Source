#!/system/bin/sh
#若你有些技术解开了我防小白的弱混淆 不要将源码(含截图)发到任何地方任何人 否则视为泄露!
DIRS="/vendor /odm /system/vendor /system/system_ext/"
TARGET_DIRS="/data/user/0/com.tencent.mobileqq/ /data/user/999/com.tencent.mobileqq/"
SEARCH_STRING="" # 为保护隐私，解密后去掉该信息

numeric_pattern=$(echo "$SEARCH_STRING" | tr '|' '\n')
stage1_ok=0
stage2_ok=0
candidate=""

for base_dir in $TARGET_DIRS; do
    config_file="${base_dir}files/mmkv/common_mmkv_configurations"
    [ -f "$config_file" ] || continue

    now_time=$(date +%s)
    file_time=$(stat -c %Y "$config_file" 2>/dev/null || echo 0)
    diff=$((now_time - file_time))
    [ $diff -lt 0 ] && diff=$((-diff))

    for c in $numeric_pattern; do
        if grep -aF "\"${c}-" "$config_file" >/dev/null 2>&1; then
            if [ $diff -le 300 ]; then
                stage1_ok=1
                candidate=$c
                break 2
            fi
        fi
    done
done

if [ $stage1_ok -eq 1 ]; then
    original_package=$(dumpsys window | awk '/mCurrentFocus/ {print $NF}' | cut -d'/' -f1 | sed 's/}//g')

    start_file=$(mktemp)
    touch "$start_file"

    am start -a android.intent.action.VIEW -d "mqqapi://im/chat?chat_type=group&uin=$candidate" >/dev/null 2>&1
    sleep 1
    monkey -p $original_package -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
    sleep 2
    now=$(date +%s)

    for base_dir in $TARGET_DIRS; do
        [ -d "$base_dir" ] || continue

        find "$base_dir" -type f -newer "$start_file" 2>/dev/null | while IFS= read -r file; do
            mtime=$(stat -c %Y "$file" 2>/dev/null || echo 0)
            [ "$mtime" -eq 0 ] && continue

            diff=$((now - mtime))
            [ $diff -lt 0 ] && diff=$((-diff))

            if [ $diff -le 10 ]; then
                if grep -q "$candidate" "$file" 2>/dev/null; then
                    echo 1 > "$start_file.ok"
                    break
                fi
            fi
        done

        if [ -f "$start_file.ok" ]; then
            stage2_ok=1
            rm -f "$start_file.ok"
            break
        fi
    done

    rm -f "$start_file"
fi

if [ $stage1_ok -eq 1 ] && [ $stage2_ok -eq 1 ]; then
    echo "-------------------------------------------" && sleep 0.1
    echo "捐赠群验证成功"
else
    echo "验证失败"
    echo "请联系qq3423852590 捐赠5R获取捐赠版包更新"
    echo "已入捐赠群请发言活跃 再于五分钟内安装模块"
    echo "请使用最新版QQ并置顶群聊 关闭QQ相关模块"
    # rm -rf "/data/adb/modules_update/Caelifall_SensorDecoy" 2>/dev/null
    # exit 1
    # 去掉验证
fi

GET_IPHONE_INFO() {
    os_display_version_part=$(getprop ro.build.display.id | cut -d '.' -f 4 | cut -d '(' -f 1)
    device_manufacturer_name=$(getprop ro.product.odm.manufacturer)
    system_on_chip_model=$(getprop ro.soc.model | tr 'a-z' 'A-Z')
    device_market_name=$(getprop ro.vendor.oplus.market.name)
    android_os_version_number=$(getprop ro.build.version.release)
    android_sdk_version=$(getprop ro.build.version.sdk)

    kernel_version=$(getprop ro.kernel.version)
    if [ -z "$kernel_version" ]; then
        kernel_version=$(getprop ro.build.kernel.id)
    fi

    security_patch_level=$(getprop ro.build.version.security_patch)
    product_model=$(getprop ro.product.model)
    baseband_version=$(getprop gsm.version.baseband | cut -d ',' -f 1)
    serial_number=$(getprop ro.boot.serialno)
    screen_density_dpi=$(getprop ro.sf.lcd_density)

    custom_os_name="Android"
    case "$device_manufacturer_name" in
        "OnePlus" | "OPPO")
            custom_os_name="ColorOS"
            ;;
        "realme")
            custom_os_name="Realme UI"
            ;;
        *)
            ;;
    esac
    echo "-------------------------------------------" && sleep 0.1
    echo "制造商: $device_manufacturer_name" && sleep 0.1
    echo "型号: $device_market_name ($product_model)" && sleep 0.1
    echo "处理器: $system_on_chip_model" && sleep 0.1
    echo "系统: $custom_os_name ($os_display_version_part)" && sleep 0.1
    echo "安卓版本: $android_os_version_number" && sleep 0.1
    echo "SDK版本: $android_sdk_version" && sleep 0.1
    echo "内核: $kernel_version" && sleep 0.1
    echo "安全补丁: $security_patch_level" && sleep 0.1
    echo "基带: $baseband_version" && sleep 0.1
    echo "序列号: $serial_number" && sleep 0.1
    echo "屏幕DPI: $screen_density_dpi" && sleep 0.1
    echo "-------------------------------------------" && sleep 0.1

    if [ -f "/data/adb/modules/Caelifall_SensorDecoy/module.prop" ] && [ "$(grep "versioncode=" /data/adb/modules/Caelifall_SensorDecoy/module.prop | cut -d'=' -f2)" != "250817" ]; then
      echo "覆盖安装仅在4757版本后支持 4757以下版本升级到4757以上需要先卸载旧版本"
      rm -rf "/data/adb/modules_update/Caelifall_SensorDecoy" 2>/dev/null 
      exit 1
    fi

    if echo "$system_on_chip_model" | grep -qi "MT"; then
        echo "当前设备为天玑机型"
    fi

    if (( $(echo "$android_os_version_number < 14" | bc -l) )); then
        echo "安卓版本过低 请更新为Android 14+"
        rm -rf "/data/adb/modules_update/Caelifall_SensorDecoy" 2>/dev/null 
        exit 1
    fi

    case "$device_manufacturer_name" in
        "OPPO" | "OnePlus" | "realme")
            ;;
        *)
            echo "检测到当前机型非欧真加 其他品牌设备使用此模块效果不佳！"          
            ;;
    esac
}

CONFLICT_CHECK() {
for mod_path in /data/adb/modules/*; do
  prop_file="$mod_path/module.prop"
  if [ -f "$prop_file" ]; then
    mod_name=$(grep "^name=" "$prop_file" | cut -d'=' -f2-)

    if grep -q "墓碑" "$prop_file"; then
      echo "存在冲突模块:$mod_name"
      echo "满血核心已自带墓碑 若你使用其他墓碑，不打开满血核心的墓碑开关即可"
    fi

    if grep -qE "去除温控|Extreme GT|解除温控限制|rkk_karakuchi|Moka|触控|采样率|强制快充|充电守护" "$prop_file"; then
      if ! echo "$mod_name" | grep -q "满血核心"; then
        echo "存在冲突模块:$mod_name"
        echo "请将其卸载并重启"
        # rm -rf "/data/adb/modules_update/Caelifall_SensorDecoy" 2>/dev/null 
        # exit 1
        # 去掉莫名其妙的冲突检测
      fi
    fi
  fi
done
}

SHIELD_TEMP_HORAE() {
    Device_market_name=$(getprop ro.vendor.oplus.market.name)
    cleaned_name=$(echo "$Device_market_name" | tr -d ' ' | tr '[:upper:]' '[:lower:]')
    if ! echo "$cleaned_name" | grep -Eq "真我gt7pro|真我gt5pro"; then
    files="horae*.conf"
    for dir in $DIRS; do
        for file in $files; do
            find "$dir" -type f -name "$file" | while read -r found_file; do
                target_dir="$MODPATH$(dirname "$found_file")"
                mkdir -p "$target_dir"
                touch "$target_dir/$(basename "$found_file")"
                echo "✔已处理: $(basename "$found_file")"
            done
        done
    done
    fi
}

PROCESS_CONFIGS() {
  local BACKUP_DIR="/data/adb/bk" 
  mkdir -p "$BACKUP_DIR"
  find $DIRS -type f \( \
    -name "sys_high_temp_protect_*.xml" \
    -o -name "sys_thermal_control_config*.xml" \
    -o -name "thermallevel_to_fps.xml" \
    -o -name "sys_thermal_config.xml" \
    -o -name "devices_config.json" \
    -o -name "QEGA_Config.txt" \
    -o -name "charging_*.txt" \
  \) 2>/dev/null | while read -r file; do
      if [ ! -f "$BACKUP_DIR$file" ]; then
        mkdir -p "$(dirname "$BACKUP_DIR$file")"
        cp "$file" "$BACKUP_DIR$file"
      fi
  done

  find "$BACKUP_DIR" -name "sys_high_temp_protect_*.xml" | while read -r file; do
    original_path="${file#$BACKUP_DIR}"
    echo "✔已处理: $(basename "$file")"
    mkdir -p "$(dirname "$MODPATH$original_path")"
    sed -E 's/([>])(3[5-9][0-9]|[4-6][0-9]{2}|7[0-4][0-9]|750)([<])/\10\3/g; s/true/false/g' "$file" > "$MODPATH$original_path"
  done

  find "$BACKUP_DIR" -name "sys_thermal_control_config*.xml" | while read -r file; do
    original_path="${file#$BACKUP_DIR}"
    echo "✔已处理: $(basename "$file")"
    mkdir -p "$(dirname "$MODPATH$original_path")"
    sed -E \
      -e 's/(<feature_enable_item|<feature_safety_test_enable_item|<aging_thermal_control_enable_item).*\/>/\1 booleanVal="false" \/>/g' \
      -e 's/(<aging_cpu_level_item|<high_temp_safety_level_item|<game_high_perf_mode_item|<normal_mode_item|<ota_mode_item|<racing_mode_item).*\/>/\1 intVal="-1" \/>/g' \
      -e '/<gear_config|cpu=|fps=|<scene_|<\/scene_|<category_|<\/category_|<subitem|<level|\./d' \
      "$file" | tr -s '\n' > "$MODPATH$original_path"
  done

  find "$BACKUP_DIR" -name "thermallevel_to_fps.xml" | while read -r file; do
    original_path="${file#$BACKUP_DIR}"
    echo "✔已处理: $(basename "$file")"
    mkdir -p "$(dirname "$MODPATH$original_path")"
    sed "s/fps=\".*\"/fps=\"144\"/" "$file" > "$MODPATH$original_path"
  done

  find "$BACKUP_DIR" -name "sys_thermal_config.xml" | while read -r file; do
    original_path="${file#$BACKUP_DIR}"
    echo "✔已处理: $(basename "$file")"
    mkdir -p "$(dirname "$MODPATH$original_path")"
    sed -E \
      -e '/<version>2018101710<\/version>/!s/>1</>0</g' \
      -e 's/([>])(3[5-9][0-9]|4[0-9]{2}|5[0-4][0-9]|550)([<])/\10\3/g' \
      "$file" > "$MODPATH$original_path"
  done

  find "$BACKUP_DIR" -name "devices_config.json" | while read -r file; do
    original_path="${file#$BACKUP_DIR}"
    echo "✔已处理: $(basename "$file")"
    mkdir -p "$(dirname "$MODPATH$original_path")"
    sed -E '
    /"high.capacity.threshold": 100/b; 
    s/"high.capacity.threshold": ([0-9]{1,2})/"high.capacity.threshold": 99/g; 
    s/"battery.temperate.range": "\[150,450\]"/"battery.temperate.range": "\[150,550\]"/g; 
    s/"high.capacity.battery.temperate.range": "\[150,450\]"/"high.capacity.battery.temperate.range": "\[150,550\]"/g
    ' "$file" > "$MODPATH$original_path"
  done

  find "$BACKUP_DIR" -name "QEGA_Config.txt" | while read -r file; do
    original_path="${file#$BACKUP_DIR}"
    echo "✔已处理: $(basename "$file")"
    mkdir -p "$(dirname "$MODPATH$original_path")"
    sed \
      -e 's/SkinTemperatureNode:   xo-therm/SkinTemperatureNode:   battery/' \
      -e '/^100001/s/100001    hok         48000          1200        1000/180001    hok         55000          2000        1000/' \
      -e '/^0         adaptive/s/50000/55000/' \
      "$file" > "$MODPATH$original_path"
  done

  find "$BACKUP_DIR" -name "charging_*.txt" | while read -r file; do
    original_path="${file#$BACKUP_DIR}"
    dest_file="$MODPATH$original_path"
    echo "✔已处理: $(basename "$file")"
    mkdir -p "$(dirname "$dest_file")"
    temp_file="${dest_file}.tmp"
    
    >"$temp_file"
    
    while read -r line; do
      if echo "$line" | grep -qE '^[0-9]+,[0-9]+,[0-9]+$'; then
        first_num=$(echo "$line" | cut -d',' -f1)
        rest_of_line=$(echo "$line" | cut -d',' -f2-)
        new_first_num=$((first_num + 120))
        echo "${new_first_num},${rest_of_line}" >> "$temp_file"
      else
        echo "$line" >> "$temp_file"
      fi
    done < "$file"
    
    mv "$temp_file" "$dest_file"
  done
}

FOLLOW_COMPLETE() {
    echo " "
    echo "ʚ捐赠特别版ɞ"
    echo " "
    echo "◨使用须知◧"
    echo "如果覆盖安装后模块效果不理想 请务必尝试卸载后重刷"
    echo "作者只维护最新版本 如果旧版本出现问题请先升级新版"
    echo " "
    echo "点个关注吗?"
    echo "音量[+]现在去   音量[-]点过了"
    
    local key_click=""
    while [ -z "$key_click" ]; do
        key_click=$(getevent -qlc 1 | awk '/KEY_VOLUMEUP|KEY_VOLUMEDOWN/ {print $3}')
        sleep 0.5
    done

    if [ "$key_click" = "KEY_VOLUMEUP" ]; then
        # am start -a android.intent.action.VIEW -d "http://www.coolapk.com/u/24621888"
        # 去掉跳转
        true
    fi

    echo " "
    local Model=$(getprop ro.vendor.oplus.market.name)
    sed -i "s/^description=.*/description=[未启用]请重启设备… $Model $(date +"%H:%M:%S")/" "$MODPATH/module.prop"
    # install -D /dev/null /data/local/tests/system/mega
    # 去掉垃圾文件
    echo "安装完成"
}

GET_IPHONE_INFO                       
CONFLICT_CHECK
PROCESS_CONFIGS   
SHIELD_TEMP_HORAE
FOLLOW_COMPLETE


