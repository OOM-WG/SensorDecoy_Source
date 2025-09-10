if ! [ -f "/data/local/tests/system/mega" ]; then
    # exit 1
    # 去掉验证
    true
fi
while true; do
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
sleep 10
done
