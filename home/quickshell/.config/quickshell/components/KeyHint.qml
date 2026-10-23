import QtQuick
import qs.services

// Key cap (DESIGN.md §1.3). Hidden until Alt is held; set alwaysVisible for the cheatsheet.
Rectangle {
    id: root

    property string key
    property bool alwaysVisible: false

    implicitWidth: label.implicitWidth + Theme.px(12) + 2
    implicitHeight: label.implicitHeight + Theme.px(4) + 2
    radius: Theme.px(6)
    color: Theme.white(0.10)
    border.width: 1
    border.color: Theme.white(0.16)

    opacity: alwaysVisible || KeyHints.held ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: Motion.micro; easing.type: Motion.easeMicro } }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.key
        font.family: Theme.fontMono
        font.pixelSize: Theme.px(11)
        color: Theme.text
    }
}
