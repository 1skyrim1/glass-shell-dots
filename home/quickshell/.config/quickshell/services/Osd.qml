pragma Singleton
import QtQuick
import Quickshell

// Which OSD drops out of the clock (DESIGN.md §2 "OSDs"): "volume" | "brightness" | "layout".
// Each press restarts the hold; 1.2 s after the last one it's pulled back. No workspace OSD, and none
// while Control Center is open (its sliders already move, §4), while capturing or while recording (they'd end up
// in the image).
Singleton {
    id: root

    property string kind: "volume"
    property bool shown: false

    function show(k: string) {
        if (Shell.panel === "control" || Capture.active || Recorder.recording) return
        kind = k
        shown = true
        hold.restart()
    }

    Timer {
        id: hold
        interval: Motion.osdHold
        onTriggered: root.shown = false
    }

    Connections {
        target: Shell
        function onPanelChanged() { if (Shell.panel === "control") root.shown = false }
    }
}
