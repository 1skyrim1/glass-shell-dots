import QtQuick
import qs.services

// A value track (Control.dc.html `.track`, 6 px, white 14 %) with a coloured fill, optionally a knob and a
// gradient track instead of the fill (night light). Drag or click anywhere on it, or scroll; `moved`
// gives the new value (0…1) and the owner applies it. Keys (← →) are handled by the surface, which calls
// `nudge`.
Item {
    id: root

    property real value: 0
    property color fill: Theme.accent
    property bool showFill: true
    property bool knob: false
    // Gradient track (warm → cool); used instead of the plain one when both are set.
    property color trackFrom: "transparent"
    property color trackTo: "transparent"
    property real step: 0.05
    readonly property bool dragging: mouse.pressed

    signal moved(real value)

    function nudge(dir: int) { moved(Math.max(0, Math.min(1, value + dir * step))) }

    implicitHeight: Theme.px(knob ? 14 : 6)

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: Theme.px(6)
        radius: height / 2
        color: Theme.white(0.14)
        gradient: root.trackFrom.a > 0 ? grad : null
        Gradient {
            id: grad
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: root.trackFrom }
            GradientStop { position: 1; color: root.trackTo }
        }

        Rectangle {
            visible: root.showFill
            height: parent.height
            radius: parent.radius
            width: Math.max(height, parent.width * Math.max(0, Math.min(1, root.value)))
            color: root.fill
            Behavior on width { enabled: !root.dragging; NumberAnimation { duration: Motion.micro; easing.type: Motion.easeMicro } }
            Behavior on color { ColorAnimation { duration: Motion.micro; easing.type: Motion.easeMicro } }
        }
    }

    Rectangle {
        visible: root.knob
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.px(14)
        height: width
        radius: width / 2
        x: track.width * Math.max(0, Math.min(1, root.value)) - width / 2
        color: "white"
        Behavior on x { enabled: !root.dragging; NumberAnimation { duration: Motion.micro; easing.type: Motion.easeMicro } }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        anchors.topMargin: -Theme.px(10)
        anchors.bottomMargin: -Theme.px(10)
        preventStealing: true
        function at(x: real) { root.moved(Math.max(0, Math.min(1, x / width))) }
        onPressed: e => at(e.x)
        onPositionChanged: e => { if (pressed) at(e.x) }
        onWheel: e => root.nudge(e.angleDelta.y > 0 ? 1 : -1)
    }
}
