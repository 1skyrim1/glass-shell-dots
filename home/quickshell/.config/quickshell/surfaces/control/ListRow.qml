import QtQuick
import qs.services
import qs.components

// A sub-page row (ControlPages.dc.html `.r`): 44 px, radius 12, icon · name · a short note on the right
// (or any trailing item put inside). `selected` = the accent-tinted row (`.sel`: accent 16 % + 1 px accent
// 35 % inset); `focused` = where the keys are.
Button {
    id: root

    property string icon
    property string text
    property string note
    property color noteColor: Theme.textFaint
    property bool selected: false
    property bool bold: false
    property real labelWidth: -1   // fixed name column (per-app volume rows)
    default property alias trailing: end.data

    implicitHeight: Theme.px(44)
    radius: Theme.px(12)
    hoverScale: 1
    squish: 0.98
    lit: selected
    litColor: Theme.alpha(Theme.accent, 0.16)

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        border.width: 1
        border.color: Theme.alpha(Theme.accent, root.selected ? 0.35 : 0)
        Behavior on border.color { ColorAnimation { duration: Motion.micro } }
    }

    Icon {
        id: icon
        visible: root.icon !== ""
        x: Theme.px(12)
        anchors.verticalCenter: parent.verticalCenter
        name: root.icon
        size: Theme.px(16)
    }
    Text {
        id: label
        x: root.icon !== "" ? icon.x + icon.width + Theme.px(12) : Theme.px(12)
        anchors.verticalCenter: parent.verticalCenter
        width: root.labelWidth >= 0 ? root.labelWidth : end.x - x - Theme.px(12)
        text: root.text
        color: Theme.text
        font.family: Theme.font
        font.pixelSize: Theme.px(13)
        font.weight: root.bold ? Font.Medium : Font.Normal
        elide: Text.ElideRight
        textFormat: Text.PlainText
    }
    Row {
        id: end
        anchors { right: parent.right; rightMargin: Theme.px(12); verticalCenter: parent.verticalCenter }
        spacing: Theme.px(8)
        Text {
            visible: root.note !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: root.note
            color: root.noteColor
            font.family: Theme.font
            font.pixelSize: Theme.px(11.5)
        }
    }
}
