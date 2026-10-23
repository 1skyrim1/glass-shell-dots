import QtQuick
import qs.services
import qs.components

// Bell pill (DESIGN.md §2.5), 38 × 38. Tertiary dot when there are unread notifications; do not disturb
// lights it with the crossed-out bell. Click = notification center, right-click = DND menu (Phase 3).
// The notification center belongs to the clock (it drips out of it), so only the clock lights while it's open.
Pill {
    id: root

    property bool unread: false   // TODO Phase 6: from the notification server

    implicitWidth: implicitHeight
    lit: Modes.dnd
    onClicked: Shell.toggle("notifications")
    onRightClicked: Shell.openPopover("bell")   // TODO Phase 3: bell menu

    Icon {
        anchors.centerIn: parent
        name: Modes.dnd ? "bell-off" : "bell"
        color: Modes.dnd ? Theme.accent : Theme.text
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
