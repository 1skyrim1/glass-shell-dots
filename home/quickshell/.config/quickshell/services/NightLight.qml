pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Night light (Control Center tile 3, 17-ControlPages "Night light, expanded"): hyprsunset runs while it's
// on, and the temperature changes live through its hyprctl IPC. It follows the fixed schedule in
// config.json (nightLight.from → to, local time); switching it by hand holds until the next scheduled
// change. On / temperature are remembered in ~/.local/state/glass-shell/control.json.
Singleton {
    id: root

    readonly property int minK: 2500   // warm end of the slider
    readonly property int maxK: 6500   // cool end
    property alias on: adapter.on
    property alias temperature: adapter.temperature
    readonly property string from: Config.nightLight.from
    readonly property string to: Config.nightLight.to
    readonly property string scheduleText: from + " – " + to

    function toggle() { setOn(!on) }
    function setOn(v: bool) {
        adapter.overrideUntil = nextChange(new Date()).getTime()
        on = v
    }
    function setTemperature(k: int) { temperature = Math.round(Math.max(minK, Math.min(maxK, k)) / 100) * 100 }

    // --- Schedule
    function minutes(hhmm: string): int {
        const [h, m] = hhmm.split(":").map(Number)
        return (h || 0) * 60 + (m || 0)
    }
    function scheduled(d: var): bool {
        const m = d.getHours() * 60 + d.getMinutes(), a = minutes(from), b = minutes(to)
        return a <= b ? m >= a && m < b : m >= a || m < b   // an overnight span wraps past midnight
    }
    // The next time the schedule switches (from or to), after d.
    function nextChange(d: var): var {
        const at = mins => {
            const t = new Date(d.getFullYear(), d.getMonth(), d.getDate(), Math.floor(mins / 60), mins % 60)
            if (t <= d) t.setDate(t.getDate() + 1)
            return t
        }
        const a = at(minutes(from)), b = at(minutes(to))
        return a < b ? a : b
    }
    function check() {
        const now = new Date()
        if (now.getTime() < adapter.overrideUntil) return
        on = scheduled(now)
    }
    // Checked every 30 s rather than with one long timer, which would drift across suspend.
    // Only once the state file is read, so the first check can't overwrite it.
    property bool loaded: false
    Timer {
        running: root.loaded
        repeat: true
        interval: 30000
        triggeredOnStart: true
        onTriggered: root.check()
    }
    onFromChanged: if (loaded) { adapter.overrideUntil = 0; check() }
    onToChanged: if (loaded) { adapter.overrideUntil = 0; check() }

    // --- hyprsunset
    // A hyprsunset left over from a shell that was killed would keep the screen warm and hold the IPC
    // socket, so the first thing after start-up is to end it; only then does this one take over.
    property bool ready: false
    onLoadedChanged: if (loaded) cleanup.running = true
    Process {
        id: cleanup
        command: ["pkill", "-x", "hyprsunset"]
        onExited: root.ready = true
    }
    Process {
        id: sunset
        running: root.ready && root.on
        command: ["hyprsunset", "-t", String(root.temperature)]
    }
    // Slider drags send at most one change every 60 ms.
    onTemperatureChanged: if (sunset.running) throttle.start()
    Timer {
        id: throttle
        interval: 60
        onTriggered: {
            ipc.command = ["hyprctl", "hyprsunset", "temperature", String(root.temperature)]
            ipc.running = true
        }
    }
    Process { id: ipc }

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/glass-shell/control.json"
        printErrors: false
        onAdapterUpdated: writeAdapter()
        onLoaded: root.loaded = true
        onLoadFailed: { writeAdapter(); root.loaded = true }   // first run: create the file
        JsonAdapter {
            id: adapter
            property bool on: false
            property int temperature: 4000
            property real overrideUntil: 0   // ms since epoch; the schedule takes over again after it
        }
    }
}
