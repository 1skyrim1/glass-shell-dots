import QtQuick
import qs.services

// A button inside a popover or panel. It reacts like the pills (10-Popovers bottom row, "every pill,
// button and tile reacts the same way"): hover lighter + grow, press squish then spring back past 100 %,
// lit = its thing is on / selected, keyboard focus ring, 45 % when disabled.
// Keys are handled by the surface that owns the button; it sets `focused` for the one the keys are on.
Item {
    id: root

    signal clicked()

    property real radius: height / 2
    property color base: "transparent"                       // resting fill
    property color litColor: Theme.alpha(Theme.accent, 0.16)  // fill while lit
    property bool lit: false
    property bool focused: false
    property real hoverScale: 1.04   // rows don't grow: 1
    property real squish: 0.95       // wide rows squish less: 0.97
    readonly property alias hovered: mouse.containsMouse
    readonly property alias pressed: mouse.pressed
    default property alias content: inner.data

    opacity: enabled ? 1 : 0.45
    scale: pressed ? squish : hovered ? hoverScale : 1
    Behavior on scale {
        NumberAnimation {
            duration: Motion.micro * (root.pressed ? 1 : 2)
            easing.type: root.pressed || Motion.reduced ? Motion.easeMicro : Easing.OutBack
            easing.overshoot: 2.2
        }
    }
    Behavior on opacity { NumberAnimation { duration: Motion.micro; easing.type: Motion.easeMicro } }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.lit ? root.litColor : root.base
        Behavior on color { ColorAnimation { duration: Motion.micro; easing.type: Motion.easeMicro } }
        // Hover lightens, press darkens, on top of whatever the resting fill is.
        Rectangle {
            anchors.fill: parent
            radius: root.radius
            color: root.pressed ? Qt.rgba(0, 0, 0, 0.12) : Theme.white(root.hovered ? 0.07 : 0)
            Behavior on color { ColorAnimation { duration: Motion.micro; easing.type: Motion.easeMicro } }
        }
    }

    FocusRing {
        shown: root.focused
        shapeRadius: root.radius
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }

    Item {
        id: inner
        anchors.fill: parent
    }
}
