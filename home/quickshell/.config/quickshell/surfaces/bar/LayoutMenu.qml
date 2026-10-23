import QtQuick
import qs.services
import qs.components

// Keyboard layout menu (DESIGN.md §3.1, 10-Popovers "Keyboard layout"): right-click the layout badge.
// One row per layout with its code and name, the active one checked. ↑/↓ (or J/K) + Enter, 1–9, Esc.
Popover {
    id: root

    name: "layout"
    contentWidth: Theme.px(250)

    // Widest code, so the names line up.
    readonly property real codeWidth: Math.max(Theme.px(24), ...Keyboard.entries.map(e => metrics.advanceWidth(e.code)))
    FontMetrics {
        id: metrics
        font.family: Theme.fontMono
        font.pixelSize: Theme.px(11)
    }

    property int cursor: -1   // row the keys are on; the focus ring only shows once a key moved it
    onShownChanged: cursor = -1
    function choose(i: int) {
        Keyboard.select(i)
        Shell.closePopover()
    }

    Keys.onPressed: e => {
        const n = Keyboard.entries.length
        if (e.key === Qt.Key_Down || e.key === Qt.Key_J) cursor = cursor < 0 ? Keyboard.index : (cursor + 1) % n
        else if (e.key === Qt.Key_Up || e.key === Qt.Key_K) cursor = cursor < 0 ? Keyboard.index : (cursor - 1 + n) % n
        else if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) && cursor >= 0) choose(cursor)
        else if (e.key >= Qt.Key_1 && e.key < Qt.Key_1 + n) choose(e.key - Qt.Key_1)
        else return
        e.accepted = true
    }

    Repeater {
        model: Keyboard.entries
        MenuRow {
            required property var modelData
            required property int index
            width: parent.width
            code: modelData.code
            codeWidth: root.codeWidth
            text: modelData.name
            checked: index === Keyboard.index
            lit: checked
            focused: index === root.cursor
            onClicked: root.choose(index)
        }
    }
    Separator {}
    Text {
        width: parent.width
        leftPadding: Theme.px(10)
        topPadding: Theme.px(4)
        bottomPadding: Theme.px(6)
        text: "Left-click the badge to cycle"
        color: Theme.textFaint
        font.family: Theme.font
        font.pixelSize: Theme.px(11.5)
    }
}
