pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Wayland

// The idle chain (DESIGN.md §4, 30-SessionStates "About to lock"), no hypridle:
//   lock − 10 s  the screen dims to 45 % and the clock pill turns into "Locking in N s · move to stay"
//                (surfaces/IdleDim.qml, ClockPill); any input cancels it
//   lock         Session.lock()                          (Config.idle.lock, 5 min)
//   screen off   DPMS off, back on with input            (Config.idle.screenOff, 7 min)
//   suspend      only on battery                         (Config.idle.suspendOnBattery, 15 min)
// The monitors respect idle inhibitors, so it's all skipped while a video plays (Firefox, mpv inhibit idle)
// or Keep awake is on (Bar.qml's IdleInhibitor).
Singleton {
    id: root

    // `qs ipc call idle test 20` squeezes the chain so the lock comes after 20 s (0 = back to normal). While
    // testing, the lock is the preview (fake auth) and the screen-off / suspend steps are skipped.
    property real factor: 1
    readonly property bool testing: factor !== 1
    function sec(v: real): int { return Math.max(1, Math.round(v * factor)) }
    // A monitor keeps its old timeout until it's re-armed: switch them off for a moment when the times change.
    property bool armed: true
    onLockAfterChanged: { armed = false; Qt.callLater(() => armed = true) }

    readonly property int lockAfter: sec(Config.idle.lock)
    readonly property int warnAfter: Math.max(1, lockAfter - Config.idle.dimCountdown)
    property int countdown: 0            // seconds left before the lock, 0 = no countdown
    readonly property bool warning: countdown > 0

    IdleMonitor {
        id: warnMonitor
        enabled: root.armed && !Session.locked
        respectInhibitors: true
        timeout: root.warnAfter
        onIsIdleChanged: {
            if (isIdle) {
                root.countdown = Config.idle.dimCountdown
                tick.restart()
            } else {
                tick.stop()
                root.countdown = 0
            }
        }
    }
    Timer {
        id: tick
        interval: 1000
        repeat: true
        onTriggered: {
            if (--root.countdown > 0) return
            stop()
            root.testing ? Session.startPreview() : Session.lock(false)
        }
    }

    IdleMonitor {
        enabled: root.armed && !root.testing
        respectInhibitors: true
        timeout: root.sec(Config.idle.screenOff)
        onIsIdleChanged: Quickshell.execDetached(["hyprctl", "dispatch",
            `hl.dsp.dpms({ action = "${isIdle ? "off" : "on"}" })`])
    }

    IdleMonitor {
        enabled: root.armed && !Battery.pluggedIn && !root.testing
        respectInhibitors: true
        timeout: root.sec(Config.idle.suspendOnBattery)
        onIsIdleChanged: if (isIdle) Session.suspend()
    }
}
