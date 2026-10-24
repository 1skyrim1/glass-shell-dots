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

    // Capture tool (above the power menu and panels, §4): Super+Shift+S, Super+Shift+C.
    Variants {
        model: Quickshell.screens
        Capture {
            required property var modelData
            screen: modelData
        }
    }

    // Shot thumbnail card and recording card + trim (what capture leaves behind).
    Variants {
        model: Quickshell.screens
        CaptureCards {
            required property var modelData
            screen: modelData
        }
    }

    // Annotate editor (E on the shot card).
    Variants {
        model: Quickshell.screens
        Annotate {
            required property var modelData
            screen: modelData
        }
    }

    // Screen-share picker (xdg-desktop-portal-hyprland's custom picker).
    Variants {
        model: Quickshell.screens
        SharePicker {
            required property var modelData
            screen: modelData
        }
    }

    LazyLoader {
        active: Shell.panel === "test"
        GlassTest {}
    }
}
