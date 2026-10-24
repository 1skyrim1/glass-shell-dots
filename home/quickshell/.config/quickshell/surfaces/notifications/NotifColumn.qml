import QtQuick
import Quickshell
import qs.services
import qs.components

// Right column of the notification center (18-Notifications, 19-NotifStates "Center: empty + do not
// disturb"): "Notifications" with the do-not-disturb switch, the cards (scrolling once they reach the
// bottom of the screen), and while Alt is held the keys. Empty: "All caught up".
Column {
    id: root

    property Item nc   // the NotificationCenter
    property real maxListHeight: 600
    function cardAt(i: int): Item { return cards.itemAt(i) }

    spacing: Theme.px(8)

    // --- Header
    Row {
        width: parent.width
        topPadding: Theme.px(6)
        bottomPadding: Theme.px(4)
        leftPadding: Theme.px(2)
        rightPadding: Theme.px(2)
        spacing: Theme.px(8)
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - dndLabel.width - dndSwitch.width - 2 * parent.spacing - parent.rightPadding
            text: "Notifications"
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: Theme.px(15)
            font.weight: Font.DemiBold
        }
        Text {
            id: dndLabel
            anchors.verticalCenter: parent.verticalCenter
            // "Do not disturb · 1 h" (time left) while on.
            text: {
                if (!Modes.dnd) return "Do not disturb"
                if (Modes.dndUntil <= 0) return "Do not disturb"
                const m = Math.max(1, Math.round((Modes.dndUntil - Notifs.now) / 60000))
                return "Do not disturb · " + (m >= 60 ? Math.round(m / 60) + " h" : m + " min")
            }
            color: Modes.dnd ? Theme.accent : Theme.textMuted
            font.family: Theme.font
            font.pixelSize: Theme.px(12)
        }
        Switch {
            id: dndSwitch
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: Theme.px(34)
            implicitHeight: Theme.px(20)
            checked: Modes.dnd
            onToggled: Modes.dnd ? (Modes.dnd = false) : Modes.setDnd("manual")
        }
    }

    // --- Cards
    Flickable {
        id: flick
        width: parent.width
        height: Math.min(contentHeight, root.maxListHeight)
        visible: Notifs.groupKeys.length > 0
        contentHeight: cardColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: cardColumn
            width: flick.width
            spacing: Theme.px(8)
            Repeater {
                id: cards
                // Group keys: a card keeps its delegate (and reply field) while notifications come and go.
                model: ScriptModel { values: Notifs.groupKeys }
                NotifCard {
                    required property string modelData
                    required property int index
                    width: cardColumn.width
                    nc: root.nc
                    group: Notifs.groupOf(modelData)
                    selected: root.nc.focusCol === "list" && root.nc.sel === index
                    expanded: root.nc.expanded === modelData
                    replying: root.nc.replyKey === modelData
                    onClicked: {
                        root.nc.sel = index
                        root.nc.openSelected()
                    }
                }
            }
        }
    }
    // Keeps the selected card in view.
    function reveal(i: int) {
        const c = cards.itemAt(i)
        if (!c) return
        if (c.y < flick.contentY) flick.contentY = c.y
        else if (c.y + c.height > flick.contentY + flick.height) flick.contentY = c.y + c.height - flick.height
    }

    // --- Empty
    Column {
        visible: Notifs.groupKeys.length === 0
        width: parent.width
        topPadding: Theme.px(50)
        bottomPadding: Theme.px(46)
        spacing: Theme.px(10)
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Theme.px(56)
            height: width
            radius: width / 2
            color: Theme.alpha(Theme.accent, 0.14)
            Icon {
                anchors.centerIn: parent
                name: Modes.dnd ? "bell-off" : "bell"
                size: Theme.px(24)
                color: Theme.accent
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "All caught up"
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: Theme.px(14.5)
            font.weight: Font.Medium
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: !Modes.dnd ? "Nothing new."
                : Modes.dndUntil > 0 ? `Quiet until ${Qt.formatTime(new Date(Modes.dndUntil), "HH:mm")}. Critical alerts still come through.`
                : "Quiet until you turn it off. Critical alerts still come through."
            color: Theme.textFaint
            font.family: Theme.font
            font.pixelSize: Theme.px(12)
        }
    }

    // --- Keys (Alt)
    Flow {
        visible: KeyHints.held && Notifs.groupKeys.length > 0
        width: parent.width
        topPadding: Theme.px(6)
        leftPadding: Theme.px(2)
        spacing: Theme.px(7)
        Repeater {
            model: [["J K", "move"], ["Enter", "open"], ["R", "reply"], ["D", "dismiss"], ["Shift D", "clear all"]]
            Row {
                required property var modelData
                spacing: Theme.px(7)
                rightPadding: Theme.px(4)
                KeyHint { key: parent.modelData[0]; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: parent.modelData[1]
                    color: Theme.textFaint
                    font.family: Theme.font
                    font.pixelSize: Theme.px(11.5)
                }
            }
        }
    }
}
