pragma Singleton
import QtQuick
import Quickshell

// Which surface is open (DESIGN.md §4 "one thing at a time").
//
// Layers, top to bottom, and their WlrLayer:
//   lock screen          WlSessionLock
//   password prompts     Overlay
//   capture tool         Overlay
//   power menu           Overlay
//   panels & popovers    Top
//   toasts & OSDs        Top
//   pills                Top
//   windows              (Hyprland)
Singleton {
    id: root

    // Only one panel at a time.
    readonly property var panels: ["launcher", "cheatsheet", "control", "notifications", "wallpaper", "overview", "power"]

    property string panel: ""    // open panel, "" = none
    property string popover: ""  // open popover, "" = none
    property bool locked: false

    function isOpen(name: string): bool { return panel === name }

    function open(name: string) {
        if (locked) return
        popover = ""  // popovers close when a panel opens
        panel = name
    }
    function close(name: string) { if (panel === name) panel = "" }
    function toggle(name: string) { panel === name ? close(name) : open(name) }

    function openPopover(name: string) { if (!locked) popover = name }
    function closePopover() { popover = "" }

    // Esc / click outside: close the topmost thing.
    function closeTop() { popover !== "" ? closePopover() : (panel = "") }
    function closeAll() { popover = ""; panel = "" }

    // Locking closes every panel (prompts are cancelled by their own surface in Phase 9).
    function lock() { closeAll(); locked = true }
}
