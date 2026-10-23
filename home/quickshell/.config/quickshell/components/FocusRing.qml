import QtQuick
import qs.services

// Keyboard focus (10-Popovers, "Keyboard focus ring"): 2 px accent ring + 4 px accent halo at 20 % outside
// the shape. Put it inside the focused item; it fills it and follows its radius.
Rectangle {
    id: root

    property bool shown: false
    property real shapeRadius: 0

    anchors.fill: parent
    anchors.margins: -Theme.px(6)
    radius: shapeRadius + Theme.px(6)
    color: "transparent"
    border.width: Theme.px(4)
    border.color: Theme.alpha(Theme.accent, 0.2)
    visible: opacity > 0
    opacity: shown ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Motion.micro } }

    Rectangle {
        anchors.fill: parent
        anchors.margins: Theme.px(4)
        radius: root.shapeRadius + Theme.px(2)
        color: "transparent"
        border.width: Theme.px(2)
        border.color: Theme.accent
    }
}
