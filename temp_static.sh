if ! [ -f "/data/local/tests/system/mega" ]; then
    # exit 1
    # 去掉验证
    true
fi
SCRIPT_DIR=$(dirname "$0"); source "${SCRIPT_DIR}/wcsm"
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
