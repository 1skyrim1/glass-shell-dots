import QtQuick
import qs.services

// An on/off switch (ControlPages.dc.html `.tg`, Control.dc.html header): 40 × 24 with an 18 px knob, or
// `small` 36 × 22 with 16 px. On = `onColor` with the knob right in `knobColor`; off = white 14 % with a
// white knob on the left.
Item {
    id: root

    property bool checked: false
    property bool small: false
    property color onColor: Theme.accent
    property color knobColor: Theme.textOnAccent

    signal toggled()

    implicitWidth: Theme.px(small ? 36 : 40)
    implicitHeight: Theme.px(small ? 22 : 24)

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? root.onColor : Theme.white(0.14)
        Behavior on color { ColorAnimation { duration: Motion.micro; easing.type: Motion.easeMicro } }

        Rectangle {
            readonly property real pad: Theme.px(3)
            width: parent.height - 2 * pad
            height: width
            radius: width / 2
            y: pad
            x: root.checked ? parent.width - width - pad : pad
            color: root.checked ? root.knobColor : Theme.text
            Behavior on x { NumberAnimation { duration: Motion.micro; easing.type: Motion.easeMicro } }
            Behavior on color { ColorAnimation { duration: Motion.micro; easing.type: Motion.easeMicro } }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.toggled()
    }
}
