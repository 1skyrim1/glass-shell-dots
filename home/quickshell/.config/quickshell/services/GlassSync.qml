import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Keeps Hyprland's global blur in step with Config.glass (DESIGN.md §1.2).
// The blur numbers and layer rules live in hyprland.lua's glass_apply().
Item {
    function apply() {
        sync.command = ["hyprctl", "eval", `glass_apply("${Config.glass}")`]
        sync.running = true
    }

    Process { id: sync }

    Connections {
        target: Config
        function onGlassChanged() { apply() }
    }

    // A config reload resets blur to the hyprland.lua default; re-apply ours.
    Connections {
        target: Hyprland
        function onRawEvent(event: HyprlandEvent) { if (event.name === "configreloaded") apply() }
    }

    Component.onCompleted: apply()
}
