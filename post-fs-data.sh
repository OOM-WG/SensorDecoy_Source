MODDIR=$(dirname "$0")
LOG_FILE="$MODDIR/mount.log"

> "$LOG_FILE"

MY_MOUNT(){
    s="${2:-$MODDIR/$1}"
    chmod --reference "$1" "$s"
    chown --reference "$1" "$s"
    chcon --reference "$1" "$s"
    if mount --bind "$s" "$1"; then
        echo "$1" >> "$LOG_FILE"
    fi
}

MY_MOUNT_RECURSIVE() {
    local target_base="$1"
    local s_dir="$2"
    for item in "$s_dir"/*; do
        local item_name=$(basename "$item")
        local target_path="$target_base/$item_name"
        if [ -f "$item" ]; then
            MY_MOUNT "$target_path" "$item"
        elif [ -d "$item" ]; then
            MY_MOUNT_RECURSIVE "$target_path" "$item"
        fi
    done
}

AUTO_MOUNT_MODDIR() {
    for item in "$MODDIR"/*; do
        if [ -d "$item" ]; then
            local dir_name=$(basename "$item")
            local target_base="/$dir_name"
            MY_MOUNT_RECURSIVE "$target_base" "$item"
        fi
    done
}

AUTO_MOUNT_MODDIR
