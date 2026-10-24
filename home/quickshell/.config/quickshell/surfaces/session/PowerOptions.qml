import QtQuick
import qs.services
import qs.components

// Power options of the greeter and the lock screen (29-LockPower): Suspend S, Reboot R, Power off P.
// Reboot and Power off arm first: the row turns red, says "click or press P again" and a ring drains for 3 s;
// the same key or a click confirms, anything else disarms (30 "Power menu: confirm"). No Log out here.
SessionPopover {
    id: root

    signal act(string kind)   // "suspend" | "reboot" | "poweroff"

    fromRight: true
    width: Theme.px(280)

    readonly property var items: [
        { kind: "suspend", label: "Suspend", icon: "moon", key: "S" },
        { kind: "reboot", label: "Reboot", icon: "refresh", key: "R" },
        { kind: "poweroff", label: "Power off", icon: "power", key: "P" }
    ]
    property string armed: ""
    property int current: -1   // keyboard row (↑↓)
    onShownChanged: { armed = ""; current = -1 }

    function press(kind: string) {
        if (kind === "suspend" || armed === kind) {
            armed = ""
            act(kind)
        } else {
            armed = kind
            armTimer.restart()
        }
    }
    function disarm() { armed = "" }
    // Keys while open. Returns true when used.
    function key(event: var): bool {
        const k = event.key
        const hit = items.find(i => Qt.Key_A + i.key.charCodeAt(0) - 65 === k)
        if (hit) { press(hit.kind); return true }
        if (k === Qt.Key_Down || k === Qt.Key_J) { disarm(); current = (current + 1) % items.length; return true }
        if (k === Qt.Key_Up || k === Qt.Key_K) { disarm(); current = (current + items.length - 1) % items.length; return true }
        if ((k === Qt.Key_Return || k === Qt.Key_Enter) && current >= 0) { press(items[current].kind); return true }
        disarm()
        return false
    }

    // The ring's 3 s
    property real armLeft: 1
    Timer {
        id: armTimer
        interval: Motion.arm
        onTriggered: root.armed = ""
    }
    NumberAnimation on armLeft {
        id: drain
        running: root.armed !== ""
        from: 1
        to: 0
        duration: Motion.arm
    }
    onArmedChanged: if (armed !== "") { drain.restart() }

    Repeater {
        model: root.items
        Button {
            id: row
            required property var modelData
            required property int index
            readonly property bool isArmed: root.armed === modelData.kind
            width: root.width - Theme.px(16)
            height: Theme.px(isArmed ? 58 : 48)
            radius: Theme.px(14)
            hoverScale: 1
            squish: 0.97
            focused: root.current === index
            base: isArmed ? Theme.alpha(Theme.error, 0.2) : "transparent"
            onClicked: root.press(modelData.kind)
            Behavior on height { NumberAnimation { duration: Motion.micro; easing.type: Motion.easeMicro } }

            Rectangle {
                anchors.fill: parent
                radius: row.radius
                color: "transparent"
                border.width: 1
                border.color: Theme.alpha(Theme.error, 0.5)
                visible: row.isArmed
            }
            Rectangle {
                id: tile
                x: Theme.px(12)
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.px(30)
                height: width
                radius: Theme.px(10)
                color: row.isArmed ? Theme.error : Theme.white(0.08)
                Icon {
                    anchors.centerIn: parent
                    name: row.modelData.icon
                    size: Theme.px(16)
                    strokeWidth: row.isArmed ? 2.2 : 2
                    color: row.isArmed ? Theme.textOnErrorStrong : Theme.text
                }
            }
            Column {
                anchors.left: tile.right
                anchors.leftMargin: Theme.px(12)
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    text: row.modelData.label
                    color: row.isArmed ? Theme.textOnError : Theme.text
                    font.family: Theme.font
                    font.pixelSize: Theme.px(14)
                    font.weight: row.isArmed ? Font.Medium : Font.Normal
                }
                Text {
                    visible: row.isArmed
                    text: "click or press " + row.modelData.key + " again"
                    color: Theme.alpha(Theme.textOnError, 0.85)
                    font.family: Theme.font
                    font.pixelSize: Theme.px(11.5)
                }
            }
            KeyHint {
                anchors.right: parent.right
                anchors.rightMargin: Theme.px(12)
                anchors.verticalCenter: parent.verticalCenter
                visible: !row.isArmed && opacity > 0
                key: row.modelData.key
            }
            Ring {
                anchors.right: parent.right
                anchors.rightMargin: Theme.px(12)
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.px(22)
                visible: row.isArmed
                progress: root.armLeft
                stroke: 2.5
                color: Theme.textOnError
            }
        }
    }
}
