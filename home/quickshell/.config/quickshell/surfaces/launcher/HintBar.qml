import QtQuick
import qs.services
import qs.components

// The key hints under a launcher view (12-Launcher-keys …): "↑↓ select · Enter open · Tab next mode",
// optionally a right-hand group ("Esc close"). Only there while Alt is held; it folds away otherwise and
// the sheet's height follows.
Item {
    id: root

    property var hints: []        // [[key, label], …]
    property var trailing: []     // right-aligned, same shape
    property real above: Theme.px(14)

    width: parent?.width ?? 0
    readonly property bool shown: KeyHints.held && (hints.length > 0 || trailing.length > 0)
    implicitHeight: shown ? row.implicitHeight + above + Theme.px(2) : 0
    clip: true
    Behavior on implicitHeight { enabled: !Motion.reduced; NumberAnimation { duration: Motion.micro; easing.type: Motion.easeMicro } }

    component Pairs: Row {
        property var items: []
        spacing: Theme.px(8)
        Repeater {
            model: parent.items
            Row {
                required property var modelData
                required property int index
                spacing: Theme.px(8)
                leftPadding: index > 0 ? Theme.px(8) : 0
                KeyHint { anchors.verticalCenter: parent.verticalCenter; key: modelData[0] }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData[1]
                    color: Theme.textFaint
                    font.family: Theme.font
                    font.pixelSize: Theme.px(12)
                }
            }
        }
    }

    Item {
        id: row
        y: root.above
        x: Theme.px(4)
        width: root.width - Theme.px(8)
        implicitHeight: Math.max(left.implicitHeight, right.implicitHeight)
        opacity: KeyHints.held ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Motion.micro; easing.type: Motion.easeMicro } }
        Pairs { id: left; items: root.hints }
        Pairs { id: right; items: root.trailing; anchors.right: parent.right }
    }
}
