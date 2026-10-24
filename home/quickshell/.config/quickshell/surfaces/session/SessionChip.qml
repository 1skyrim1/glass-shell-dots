import QtQuick
import qs.services
import qs.components

// A glass chip of the greeter and the lock screen (§1.4 "Session chips": 44 high, radius 22): the user
// chip, the battery and the power button. Lit while its popover is open. Children go in a centred Row.
GlassRect {
    id: root

    signal clicked()
    property real padLeft: Theme.px(16)
    property real padRight: Theme.px(16)
    property real square: 0   // > 0: a round button this wide (power)
    default property alias items: row.data

    variant: "chip"
    implicitHeight: Theme.px(44)
    implicitWidth: square > 0 ? square : row.implicitWidth + padLeft + padRight
    hovered: mouse.containsMouse
    pressed: mouse.pressed

    Row {
        id: row
        x: root.square > 0 ? (root.width - implicitWidth) / 2 : root.padLeft
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.px(10)
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }
}
