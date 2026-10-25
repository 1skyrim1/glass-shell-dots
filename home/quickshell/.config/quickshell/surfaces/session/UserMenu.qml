import QtQuick
import qs.services
import qs.components

// The greeter's user switcher (27-LoginUsers): grows up out of the user chip. "USERS", a row per user (avatar 40,
// name, last login; a check on the last one used), the highlighted row in accent, and the key line
// "↑↓ choose · Enter pick · Esc close" (with key hints). The centre of the greeter follows the highlight.
SessionPopover {
    id: root

    property var users: []        // [{ name, display, face, sub, guest }]
    property int current: 0       // highlighted row
    property int lastUsed: 0      // gets the check
    signal picked(int index)

    width: Theme.px(300)

    Text {
        leftPadding: Theme.px(10)
        topPadding: Theme.px(8)
        bottomPadding: Theme.px(6)
        text: "USERS"
        color: Theme.textFaint
        font.family: Theme.font
        font.pixelSize: Theme.px(11.5)
        font.letterSpacing: Theme.px(0.6)
    }

    Repeater {
        model: root.users
        Button {
            id: row
            required property var modelData
            required property int index
            readonly property bool current: root.current === index
            width: root.width - Theme.px(16)
            height: Theme.px(56)
            radius: Theme.px(16)
            hoverScale: 1
            squish: 0.97
            base: current ? Theme.alpha(Theme.accent, 0.16) : "transparent"
            onClicked: root.picked(index)

            Rectangle {
                anchors.fill: parent
                radius: row.radius
                color: "transparent"
                border.width: 1
                border.color: Theme.alpha(Theme.accent, 0.35)
                visible: row.current
            }
            Avatar {
                id: pic
                x: Theme.px(8)
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.px(40)
                height: width
                source: row.modelData.face ?? ""
                fallback: row.modelData.guest ? "" : Theme.wallpaper
                letter: row.modelData.display.charAt(0)
            }
            Column {
                anchors.left: pic.right
                anchors.leftMargin: Theme.px(12)
                anchors.right: check.left
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    width: parent.width
                    text: row.modelData.display
                    elide: Text.ElideRight
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: Theme.px(14)
                    font.weight: Font.Medium
                }
                Text {
                    width: parent.width
                    text: row.modelData.sub ?? ""
                    elide: Text.ElideRight
                    color: Theme.textFaint
                    font.family: Theme.font
                    font.pixelSize: Theme.px(11.5)
                }
            }
            Icon {
                id: check
                anchors.right: parent.right
                anchors.rightMargin: Theme.px(12)
                anchors.verticalCenter: parent.verticalCenter
                name: "check"
                size: Theme.px(16)
                strokeWidth: 2.4
                color: Theme.accent
                opacity: root.lastUsed === row.index ? 1 : 0
            }
        }
    }

    // ↑↓ choose · Enter pick · Esc close — only with key hints, like every hint.
    Row {
        height: KeyHints.held ? implicitHeight : 0
        clip: true
        leftPadding: Theme.px(10)
        topPadding: Theme.px(10)
        bottomPadding: Theme.px(6)
        spacing: Theme.px(7)
        opacity: KeyHints.held ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Motion.micro; easing.type: Motion.easeMicro } }
        Repeater {
            model: [["↑↓", "choose"], ["Enter", "pick"], ["Esc", "close"]]
            Row {
                required property var modelData
                spacing: Theme.px(7)
                KeyHint { key: parent.modelData[0]; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    rightPadding: Theme.px(4)
                    text: parent.modelData[1]
                    color: Theme.textFaint
                    font.family: Theme.font
                    font.pixelSize: Theme.px(11.5)
                }
            }
        }
    }
}
