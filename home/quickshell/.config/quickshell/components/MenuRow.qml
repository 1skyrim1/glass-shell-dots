import QtQuick
import qs.services

// A popover menu row (Popovers.dc.html `.mi`): 36 px, radius 11, padding 0 10, gap 10, 13 px text.
// Optional: a leading mono code (layout menu) or icon, a muted note after the text, a check or a key cap
// at the end. Fills the width it's given.
Button {
    id: root

    property string text
    property string code
    property real codeWidth: Theme.px(24)   // so names line up when codes differ in length
    property string icon
    property color iconColor: Theme.accent
    property string note
    property bool checked: false
    property string key
    property alias label: label

    implicitHeight: Theme.px(36)
    radius: Theme.px(11)
    hoverScale: 1
    squish: 0.97

    Row {
        id: row
        anchors { left: parent.left; right: parent.right; leftMargin: Theme.px(10); rightMargin: Theme.px(10) }
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.px(10)

        readonly property real trailing: (end.visible ? end.width + spacing : 0)

        Text {
            id: code
            visible: root.code !== ""
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(root.codeWidth, implicitWidth)
            text: root.code
            color: root.checked ? Theme.textOnContainer : Theme.textMuted
            font.family: Theme.fontMono
            font.pixelSize: Theme.px(11)
        }
        Icon {
            visible: root.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            name: root.icon
            size: Theme.px(15)
            color: root.iconColor
        }
        Text {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            width: row.width - x - row.trailing
            text: root.text
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: Theme.px(13)
            elide: Text.ElideRight
            textFormat: Text.PlainText
        }
    }

    // Trailing: muted note, check, key cap (shown while Alt is held).
    Row {
        id: end
        anchors { right: parent.right; rightMargin: Theme.px(10); verticalCenter: parent.verticalCenter }
        spacing: Theme.px(8)
        visible: root.note !== "" || root.checked || root.key !== ""
        Text {
            visible: root.note !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: root.note
            color: Theme.textFaint
            font.family: Theme.font
            font.pixelSize: Theme.px(11.5)
        }
        Icon {
            visible: root.checked
            anchors.verticalCenter: parent.verticalCenter
            name: "check"
            size: Theme.px(15)
            color: Theme.accent
        }
        KeyHint {
            visible: root.key !== "" && opacity > 0
            anchors.verticalCenter: parent.verticalCenter
            key: root.key
        }
    }
}
