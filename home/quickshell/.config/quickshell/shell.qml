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

    // Overview (Super+Tab), above the pills and panels' layer.
    Variants {
        model: Quickshell.screens
        Overview {
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

    // Power menu (Super+Esc) and the polkit password prompt, above the capture tool.
    Variants {
        model: Quickshell.screens
        PowerMenu {
            required property var modelData
            screen: modelData
        }
    }
    Variants {
        model: Quickshell.screens
        AuthDialog {
            required property var modelData
            screen: modelData
        }
    }

    // Shutting-down screen (log out / reboot / power off) and the session lock, on top of everything.
    Variants {
        model: Quickshell.screens
        Ending {
            required property var modelData
            screen: modelData
        }
    }
    Lock {}

    LazyLoader {
        active: Shell.panel === "test"
        GlassTest {}
    }
}
