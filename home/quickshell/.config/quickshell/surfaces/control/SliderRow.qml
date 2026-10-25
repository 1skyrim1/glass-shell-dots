import QtQuick
import qs.services
import qs.components

// A slider pill (Control.dc.html `.sl`): 40 px, white 8 %, icon · track · a short note on the right.
// The icon toggles (mute), the note can be a link (volume: the device name opens the Sound page).
Item {
    id: root

    property string icon
    property real value: 0
    property color fill: Theme.accent
    property string note
    property bool mono: false
    property bool focused: false
    readonly property alias slider: slider

    signal moved(real value)
    signal iconClicked()
    signal noteClicked()

    implicitHeight: Theme.px(40)

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.white(0.08)
        FocusRing { shown: root.focused; shapeRadius: parent.radius }
    }

    Icon {
        id: icon
        x: Theme.px(14)
        anchors.verticalCenter: parent.verticalCenter
        name: root.icon
        size: Theme.px(16)
        MouseArea {
            anchors.fill: parent
            anchors.margins: -Theme.px(8)
            onClicked: root.iconClicked()
        }
    }

    Slider {
        id: slider
        anchors { left: icon.right; leftMargin: Theme.px(12); right: note.left; rightMargin: Theme.px(12); verticalCenter: parent.verticalCenter }
        value: root.value
        fill: root.fill
        onMoved: v => root.moved(v)
    }

    Text {
        id: note
        anchors { right: parent.right; rightMargin: Theme.px(14); verticalCenter: parent.verticalCenter }
        width: Math.min(implicitWidth, Theme.px(110))
        text: root.note
        color: noteMouse.containsMouse ? Theme.text : Theme.textMuted
        font.family: root.mono ? Theme.fontMono : Theme.font
        font.pixelSize: Theme.px(11.5)
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignRight
        Behavior on color { ColorAnimation { duration: Motion.micro; easing.type: Motion.easeMicro } }
        MouseArea {
            id: noteMouse
            anchors.fill: parent
            anchors.margins: -Theme.px(6)
            hoverEnabled: true
            onClicked: root.noteClicked()
        }
    }
}
