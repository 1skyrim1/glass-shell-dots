import QtQuick
import Quickshell
import qs.surfaces

// Glass Shell greeter: the login screen greetd runs in its own Hyprland (system/etc/greetd/hyprland.lua):
//   qs -p /var/lib/glass-shell/greeter/shell/greeter.qml
// install.sh copies this whole Quickshell config there (the greeter user can't read $HOME), and matugen's hook
// keeps colors.json + the wallpaper next to it (GLASS_SHELL_STATE). Try it inside a running session with
//   GLASS_GREETER_TEST=1 qs -p ~/.config/quickshell/greeter.qml
ShellRoot {
    Variants {
        model: Quickshell.screens
        Greeter {
            required property var modelData
            screen: modelData
        }
    }
}
