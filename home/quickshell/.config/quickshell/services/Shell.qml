pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

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
    property string panelFrom: "" // the pill that opened it ("" = keyboard / IPC); only that pill lights
    property string popover: ""  // open popover, "" = none
    property string popoverScreen: ""  // the screen it's open on (its pill's)
    // Popovers that take the keyboard and close on a click outside (the workspace peek is hover-only).
    readonly property bool popoverModal: ["media", "layout", "bell"].includes(popover)
    property Item tip: null      // the TipArea whose tooltip shows
    property int peekId: 1       // the workspace the peek popover shows
    property bool locked: false

    function isOpen(name: string): bool { return panel === name }

    function open(name: string, from: string) {
        if (locked) return
        popover = ""  // popovers close when a panel opens
        tip = null
        panelFrom = from || ""
        panel = name
    }
    function close(name: string) { if (panel === name) panel = "" }
    function toggle(name: string, from: string) { panel === name ? close(name) : open(name, from) }

    // `screen` = the screen name; IPC opens on the focused monitor.
    function openPopover(name: string, screen: string) {
        if (locked) return
        popoverScreen = screen || (Hyprland.focusedMonitor?.name ?? "")
        popover = name
        tip = null
    }
    function togglePopover(name: string, screen: string) { popover === name ? closePopover() : openPopover(name, screen) }
    function closePopover() { popover = "" }
    function closePopoverIf(name: string) { if (popover === name) popover = "" }

    function showTip(t: Item) { if (popover === "" && panel === "") tip = t }
    function hideTip(t: Item) { if (tip === t) tip = null }

    // Esc / click outside: close the topmost thing.
    function closeTop() { popover !== "" ? closePopover() : (panel = "") }
    function closeAll() { popover = ""; panel = "" }

    // Locking closes every panel (prompts are cancelled by their own surface in Phase 9).
    function lock() { closeAll(); locked = true }
}
