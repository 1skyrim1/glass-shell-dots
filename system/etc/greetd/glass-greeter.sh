#!/bin/sh
# greetd's greeter (system/etc/greetd/config.toml): a minimal Hyprland (hyprland.lua next to this file) running
# the Quickshell greeter from /var/lib/glass-shell/greeter/shell (install.sh copies it there).
# The greeter user's home is /, so Hyprland's and Quickshell's caches go to the runtime dir.
# Safety net: if the graphical greeter exits without having started a session (crash, missing files,
# Ctrl+Alt+Backspace), this falls back to agreety, greetd's text login, on the same tty.

run="${XDG_RUNTIME_DIR:-/tmp/glass-greeter-$(id -u)}"
mkdir -p "$run"
export XDG_RUNTIME_DIR="$run" XDG_CACHE_HOME="$run/cache" XDG_STATE_HOME="$run/state" XDG_DATA_HOME="$run/data" XDG_CONFIG_HOME="$run/config"
export GLASS_SHELL_STATE=/var/lib/glass-shell/greeter
marker="$run/glass-greeter-launched"
rm -f "$marker"

if [ -f /var/lib/glass-shell/greeter/shell/greeter.qml ] && command -v start-hyprland >/dev/null; then
    start-hyprland -- -c /etc/greetd/hyprland.lua >"$run/greeter.log" 2>&1
fi

# The greeter writes the marker just before greetd starts the session: then we're done.
[ -f "$marker" ] && exit 0
exec agreety --cmd start-hyprland
