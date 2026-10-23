import QtQuick
import Quickshell
import qs.services
import qs.surfaces

// Glass Shell entry point. Started by hyprland.lua; `qs ipc show` lists the IPC targets.
ShellRoot {
    GlassSync {}
    Ipc {}

    Variants {
        model: Quickshell.screens
        Background {
            required property var modelData
            screen: modelData
        }
    }

    Variants {
        model: Quickshell.screens
        Bar {
            required property var modelData
            screen: modelData
        }
    }

    LazyLoader {
        active: Shell.panel === "test"
        GlassTest {}
    }
}
