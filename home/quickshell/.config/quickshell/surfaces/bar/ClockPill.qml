import QtQuick
import Quickshell
import qs.services
import qs.components

// Clock pill (DESIGN.md §2.3), centred: "Tue 20 Oct" muted + "06:47" 600. Click = notification center.
// The temporary pills and OSDs come out of it (SplitPill, Osd). 10 s before the idle lock it turns into
// "Locking in 8 s · move to stay" with a draining ring (30-SessionStates "About to lock").
Pill {
    id: root

    // Lit while its panels are open: the notification center (unless the bell opened it, then the bell
    // lights) and the launcher / cheatsheet that drip out of it.
    lit: (Shell.isOpen("notifications") && Shell.panelFrom !== "bell")
         || (Shell.launcherOpen && (Shell.panelScreen === "" || Shell.panelScreen === screenName))
    readonly property bool idle: Idle.warning
    implicitWidth: (idle ? idleRow.implicitWidth : row.implicitWidth) + Theme.px(28)
    onClicked: Shell.toggle("notifications")

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.px(10)
        opacity: root.idle ? 0 : 1
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Motion.small; easing.type: Motion.easeSmall } }
        BarText {
            anchors.baseline: time.baseline
            text: Qt.formatDateTime(clock.date, "ddd d MMM")
            color: root.tinted ? Theme.textOnContainer : Theme.textMuted
        }
        BarText {
            id: time
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(clock.date, "HH:mm")
            font.pixelSize: Theme.px(14)
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }
    }

    Row {
        id: idleRow
        anchors.centerIn: parent
        spacing: Theme.px(8)
        opacity: root.idle ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Motion.small; easing.type: Motion.easeSmall } }
        Ring {
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.px(16)
            track: Theme.white(0.25)
            // Drains smoothly between the whole seconds.
            property real remaining: Idle.countdown
            Behavior on remaining { NumberAnimation { duration: Motion.countdownTick } }
            progress: remaining / Config.idle.dimCountdown
        }
        BarText {
            anchors.verticalCenter: parent.verticalCenter
            text: `Locking in ${Math.max(1, Idle.countdown)} s · move to stay`
            font.features: { "tnum": 1 }
        }
    }
}
