pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

// Modes the bar shows (DESIGN.md §2): do not disturb, game mode, keep awake, the active Hyprland submap
// and the screen recording. For now these are only state + indicators; what they do comes with their own
// phases (the real recorder in 8, the idle inhibitor in 9). Notifs holds toasts back during DND / game mode.
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

    // Screen recording placeholder (Phase 8 starts a real recorder): just the red pill and its timer.
    property bool recording: false
    property real recordingSince: 0
    property int recordingSeconds: 0
    readonly property string recordingTime: {
        const s = recordingSeconds
        const mm = Math.floor(s / 60) % 60, ss = s % 60, hh = Math.floor(s / 3600)
        return (hh > 0 ? hh + ":" : "") + String(mm).padStart(2, "0") + ":" + String(ss).padStart(2, "0")
    }

    function toggleRecording() {
        recording = !recording
        if (recording) {
            recordingSince = Date.now()
            recordingSeconds = 0
        }
    }

    Timer {
        running: root.recording
        repeat: true
        interval: 1000
        onTriggered: root.recordingSeconds = Math.round((Date.now() - root.recordingSince) / 1000)
    }
}
