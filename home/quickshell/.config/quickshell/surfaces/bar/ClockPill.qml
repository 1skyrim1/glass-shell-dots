import QtQuick
import Quickshell
import qs.services
import qs.components

// Clock pill (DESIGN.md §2.3), centred: "Tue 20 Oct" muted + "06:47" 600. Click = notification center.
// The temporary pills and OSDs come out of it (SplitPill, Osd).
Pill {
    id: root

    lit: Shell.isOpen("notifications")
    implicitWidth: row.implicitWidth + Theme.px(28)
    onClicked: Shell.toggle("notifications")

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.px(10)
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
}
