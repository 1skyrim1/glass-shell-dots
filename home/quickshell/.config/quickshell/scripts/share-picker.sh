#!/bin/sh
# Screen-share picker for xdg-desktop-portal-hyprland (custom_picker_binary in ~/.config/hypr/xdph.conf).
# xdph runs this when an app asks to share the screen and reads one line from stdout:
#   [SELECTION]<flags>/screen:<output> | window:<id> | region:<output>@<x>,<y>,<w>,<h>   (flag r = may restore)
# Exiting without output cancels. The shell shows its picker (surfaces/SharePicker.qml) and writes the answer
# into a FIFO this script waits on. $XDPH_WINDOW_SHARING_LIST lists the windows; --allow-token = the app may
# ask to be remembered. The requesting app's id comes from xdph's log (empty for apps outside a flatpak/scope).
fifo="${XDG_RUNTIME_DIR:-/tmp}/glass-shell/share-$$"
mkdir -p "${fifo%/*}" && rm -f "$fifo" && mkfifo "$fifo" || exit 1
trap 'rm -f "$fifo"' EXIT

token=0
[ "$1" = "--allow-token" ] && token=1
app=$(journalctl --user -u xdg-desktop-portal-hyprland -n 60 -o cat 2>/dev/null | sed -n 's/.*| appid: //p' | tail -n 1)

qs ipc call share pick "$fifo" "$XDPH_WINDOW_SHARING_LIST" "$token" "$app" >/dev/null 2>&1 || exit 1
answer=$(timeout 300 cat "$fifo")
[ -n "$answer" ] || exit 1
printf '%s\n' "$answer"
