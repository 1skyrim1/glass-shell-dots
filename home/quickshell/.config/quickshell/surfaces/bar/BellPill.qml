import QtQuick
import qs.services
import qs.components

// Bell pill (DESIGN.md §2.5), 38 × 38. Tertiary dot when there are unread notifications; do not disturb
// lights it with the crossed-out bell. Click = notification center, right-click = DND menu (BellMenu,
// lit while open). Hover = when DND ends.
// Only the pill that opened the notification center lights (the clock for Super+N), never both.
Pill {
    id: root

    property bool unread: false   // TODO Phase 6: from the notification server

    implicitWidth: implicitHeight
    lit: Modes.dnd || Shell.popover === "bell" || (Shell.isOpen("notifications") && Shell.panelFrom === "bell")
    onClicked: Shell.toggle("notifications", "bell")
    onRightClicked: Shell.togglePopover("bell", screenName)

    Icon {
        anchors.centerIn: parent
        name: Modes.dnd ? "bell-off" : "bell"
        color: Modes.dnd ? Theme.accent : Theme.text
        TipArea {
            visible: Modes.dnd
            text: Modes.dndUntil > 0 ? "Do not disturb until " + Qt.formatTime(new Date(Modes.dndUntil), "HH:mm")
                                     : "Do not disturb until you turn it off"
        }
    }
    Rectangle {
        anchors { top: parent.top; right: parent.right; topMargin: Theme.px(8); rightMargin: Theme.px(9) }
        width: Theme.px(7)
        height: width
        radius: width / 2
        color: Theme.secondary
        visible: root.unread && !Modes.dnd
    }
}
