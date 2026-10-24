import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Keeps Hyprland in step with the shell:
// - its global blur with Config.glass (DESIGN.md §1.2); the blur numbers and layer rules live in
//   hyprland.lua's glass_apply().
// - the active window border with the accent the colours are heading to, so it follows the wallpaper
//   switcher's live preview and Esc too (hyprland.lua's border_apply(); matugen's hypr-colors.lua only
//   covers the time before Quickshell starts).
Item {
    readonly property string accent: Theme.target.primary ?? ""

    function apply() {
        sync.command = ["hyprctl", "eval", `glass_apply("${Config.glass}")`]
        sync.running = true
    }
    function applyBorder() {
        if (!/^#[0-9a-fA-F]{6}$/.test(accent)) return
        border.command = ["hyprctl", "eval", `border_apply("${accent.slice(1)}")`]
        border.running = true
    }
    onAccentChanged: applyBorder()

    Process { id: sync }
    Process { id: border }

    Connections {
        target: Config
        function onGlassChanged() { apply() }
    }

    // A config reload resets blur and border to the hyprland.lua defaults; re-apply ours.
    Connections {
        target: Hyprland
        function onRawEvent(event: HyprlandEvent) {
            if (event.name !== "configreloaded") return
            apply()
            applyBorder()
        }
    }

    Component.onCompleted: { apply(); applyBorder() }
}
