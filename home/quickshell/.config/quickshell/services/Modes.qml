pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

// Modes the bar shows (DESIGN.md §2): do not disturb, game mode, keep awake and the active Hyprland submap
// (the screen recording lives in Recorder). Keep awake is an idle inhibitor on the bar (Bar.qml), which the idle
// chain respects (Idle.qml). Notifs holds toasts back during DND / game mode.
Singleton {
    id: root

    property bool dnd: false
    // Do not disturb from the bell menu: "hour", "morning" (until 07:00) or "manual" (until turned off).
    property string dndKind: ""
    property real dndUntil: 0   // ms since epoch, 0 = until turned off
    onDndChanged: if (!dnd) { dndKind = ""; dndUntil = 0 }

    function setDnd(kind: string) {
        if (dnd && dndKind === kind) { dnd = false; return }   // picking the active one again turns it off
        const until = new Date()
        if (kind === "hour") {
            until.setHours(until.getHours() + 1)
        } else if (kind === "morning") {
            if (until.getHours() >= 7) until.setDate(until.getDate() + 1)
            until.setHours(7, 0, 0, 0)
        }
        dndKind = kind
        dndUntil = kind === "manual" ? 0 : until.getTime()
        dnd = true
    }
    // Checked every 15 s: a timer would drift across suspend.
    Timer {
        running: root.dndUntil > 0
        interval: 15000
        repeat: true
        onTriggered: if (Date.now() >= root.dndUntil) root.dnd = false
    }
    property bool gameMode: false
    property bool keepAwake: false

    // Active Hyprland submap ("" = none), from the `submap` event.
    property string submap: ""
    // Keys each submap's pill lists (they match the binds in hyprland.lua).
    readonly property var submapKeys: ({ resize: ["H", "J", "K", "L", "Esc"] })

    Connections {
        target: Hyprland
        function onRawEvent(event: HyprlandEvent) {
            if (event.name === "submap") root.submap = event.data === "reset" ? "" : event.data
        }
    }
}
