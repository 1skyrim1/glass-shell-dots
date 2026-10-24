import QtQuick
import qs.services
import qs.components

// Bell menu (DESIGN.md §3.1, 10-Popovers "Bell menu"): right-click the bell. Do not disturb for an hour /
// until tomorrow morning / until turned off (the active one is checked; picking it again turns DND off),
// and clear all notifications. Keys 1 2 3, Shift+D, ↑/↓ + Enter, Esc.
Popover {
    id: root

    name: "bell"
    contentWidth: Theme.px(276)

    readonly property bool canClear: Notifs.list.length > 0
    function clearAll() {
        if (!canClear) return
        Notifs.clearAll()
        Shell.closePopover()
    }

    readonly property var options: [
        { kind: "hour", text: "For 1 hour", key: "1" },
        { kind: "morning", text: "Until tomorrow morning", key: "2" },
        { kind: "manual", text: "Until I turn it off", key: "3" }
    ]
    function choose(i: int) {
        Modes.setDnd(options[i].kind)
        Shell.closePopover()
    }

    property int cursor: -1   // 0–2 = options, 3 = clear all
    onShownChanged: cursor = -1
    Keys.onPressed: e => {
        const last = canClear ? 3 : 2
        if (e.key === Qt.Key_Down || e.key === Qt.Key_J) cursor = cursor < 0 ? 0 : Math.min(last, cursor + 1)
        else if (e.key === Qt.Key_Up || e.key === Qt.Key_K) cursor = cursor < 0 ? 0 : Math.max(0, cursor - 1)
        else if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) && cursor >= 0) cursor < 3 ? choose(cursor) : clearAll()
        else if (e.key >= Qt.Key_1 && e.key <= Qt.Key_3) choose(e.key - Qt.Key_1)
        else if (e.key === Qt.Key_D && (e.modifiers & Qt.ShiftModifier)) clearAll()
        else return
        e.accepted = true
    }

    Text {
        width: parent.width
        leftPadding: Theme.px(10)
        topPadding: Theme.px(6)
        bottomPadding: Theme.px(4)
        text: "Do not disturb"
        font.capitalization: Font.AllUppercase
        font.letterSpacing: Theme.px(0.6)
        color: Theme.textFaint
        font.family: Theme.font
        font.pixelSize: Theme.px(11.5)
    }
    Repeater {
        model: root.options
        MenuRow {
            required property var modelData
            required property int index
            readonly property bool active: Modes.dnd && Modes.dndKind === modelData.kind
            width: parent.width
            text: modelData.text
            note: active && Modes.dndUntil > 0 ? "until " + Qt.formatTime(new Date(Modes.dndUntil), "HH:mm") : ""
            checked: active
            lit: active
            key: modelData.key
            focused: index === root.cursor
            onClicked: root.choose(index)
        }
    }
    Separator {}
    MenuRow {
        width: parent.width
        text: "Clear all notifications"
        key: "Shift D"
        enabled: root.canClear
        focused: root.cursor === 3
        onClicked: root.clearAll()
    }
}
