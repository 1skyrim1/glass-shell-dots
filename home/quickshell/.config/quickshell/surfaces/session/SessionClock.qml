import QtQuick
import QtQuick.Effects
import Quickshell
import qs.services
import qs.components

// The big clock of the greeter and the lock screen (26-Login, 28-Lock): Outfit 600 at 156 px, −4 px
// tracking, tabular figures, the date 12 px below (20 px 500). The lock screen puts a small lock before
// the date. `clock` is the text the log-in / lock motion shrinks into the clock pill and grows back out of.
Item {
    id: root

    property bool lockIcon: false
    // Log in / lock motion: fly 1 = the big clock, 0 = shrunk to the clock pill's time (14 / 156 ≈ 0.09)
    // and moved by flyDy (from its centre to the pill's).
    property real fly: 1
    property real flyDy: 0
    property real timeOpacity: 1
    property real dateOpacity: 1
    readonly property alias clock: time
    readonly property alias date: dateRow

    implicitWidth: Math.max(time.implicitWidth, dateRow.implicitWidth)
    implicitHeight: dateRow.y + dateRow.height

    SystemClock {
        id: sys
        precision: SystemClock.Minutes
    }

    Text {
        id: time
        anchors.horizontalCenter: parent.horizontalCenter
        // CSS line-height 1: the box is exactly the font size, glyphs centred in it.
        height: Theme.px(156)
        verticalAlignment: Text.AlignVCenter
        opacity: root.timeOpacity
        text: Qt.formatDateTime(sys.date, "HH:mm")
        color: Theme.text
        font.family: Theme.fontClock
        font.weight: Font.DemiBold
        font.pixelSize: Theme.px(156)
        font.letterSpacing: -Theme.px(4)
        font.features: { "tnum": 1 }
        transform: [
            Scale {
                origin.x: time.width / 2
                origin.y: time.height / 2
                xScale: 0.09 + 0.91 * root.fly
                yScale: xScale
            },
            Translate { y: root.flyDy * (1 - root.fly) }
        ]
        // text-shadow 0 6 40 black 25 %
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.25)
            shadowVerticalOffset: Theme.px(6)
            shadowBlur: 1
            blurMax: Theme.px(40)
        }
    }

    Row {
        id: dateRow
        anchors.horizontalCenter: parent.horizontalCenter
        y: time.height + Theme.px(12)
        opacity: root.dateOpacity
        spacing: Theme.px(8)
        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.lockIcon
            name: "lock"
            size: Theme.px(15)
            strokeWidth: 2.2
            color: dateText.color
        }
        Text {
            id: dateText
            text: Qt.formatDateTime(sys.date, "dddd, d MMMM")
            color: Theme.textOnContainer
            font.family: Theme.font
            font.weight: Font.Medium
            font.pixelSize: Theme.px(20)
        }
    }
}
