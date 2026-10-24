import QtQuick
import Quickshell
import qs.services
import qs.components

// A background app's menu (17-ControlPages "Background app menu"): a small glass menu (r18, padding 6)
// that grows from the app's icon, upwards so it stays inside the panel. Header with the app, then its
// tray menu (dbusmenu) as rows; a submenu opens in place with a back row. Quit / Exit is red.
// Keys: J K / ↑ ↓ move, Enter picks, ← or Esc goes back / closes.
Item {
    id: root

    property Item anchorItem   // the tray icon it grows from
    readonly property var item: Shell.controlTray
    readonly property bool shown: item !== null && anchorItem !== null
    readonly property real radius: Theme.px(18)

    width: Theme.px(230)
    height: column.implicitHeight + 2 * Theme.px(6)

    // Grows from the icon: scale 0.9 → 1 and fade, from its bottom-left corner.
    property real p: shown ? 1 : 0
    Behavior on p { NumberAnimation { duration: root.shown ? Motion.open(Motion.small) : Motion.close(Motion.small); easing.type: root.shown ? Motion.easeSmall : Motion.easeClose } }
    visible: p > 0
    opacity: p
    scale: Motion.reduced ? 1 : 0.9 + 0.1 * p
    transformOrigin: Item.BottomLeft

    // Its bottom sits 8 px above the icon, so it grows upwards as its entries arrive. The icon's spot is
    // taken when it opens (the panel doesn't move while open).
    property point at: Qt.point(0, 0)
    x: Math.max(0, Math.min(parent.width - width, at.x - Theme.px(4)))
    y: Math.max(0, at.y - height - Theme.px(8))
    onShownChanged: if (shown) {
        at = anchorItem.mapToItem(parent, 0, 0)
        levels = []
        sel = firstUsable(0, 1)
    }
    onEntriesChanged: if (sel < 0 || !usable(sel)) sel = firstUsable(0, 1)

    // Submenus, deepest last.
    property var levels: []
    QsMenuOpener {
        id: opener
        menu: root.levels.length > 0 ? root.levels[root.levels.length - 1] : root.item?.menu ?? null
    }
    readonly property var entries: opener.children?.values ?? []
    property int sel: 0

    function usable(i: int): bool { const e = entries[i]; return !!e && !e.isSeparator && e.enabled }
    function firstUsable(from: int, dir: int): int {
        for (let n = 0, i = from; n < entries.length; n++, i = (i + dir + entries.length) % entries.length)
            if (usable(i)) return i
        return -1
    }
    function pick(i: int) {
        const e = entries[i]
        if (!e || !usable(i)) return
        if (e.hasChildren) {
            levels = levels.concat([e])
            sel = 0
            Qt.callLater(() => sel = firstUsable(0, 1))
        } else {
            e.triggered()
            Shell.closeAll()
        }
    }
    function back() {
        if (levels.length > 0) levels = levels.slice(0, -1)
        else Shell.controlTray = null
    }
    function key(e: var): bool {
        const k = e.key
        if (k === Qt.Key_J || k === Qt.Key_Down || k === Qt.Key_Tab) sel = firstUsable((sel + 1) % Math.max(1, entries.length), 1)
        else if (k === Qt.Key_K || k === Qt.Key_Up || k === Qt.Key_Backtab) sel = firstUsable((sel - 1 + entries.length) % Math.max(1, entries.length), -1)
        else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space || k === Qt.Key_Right || k === Qt.Key_L) pick(sel)
        else if (k === Qt.Key_Escape || k === Qt.Key_Left || k === Qt.Key_H) back()
        else return false
        return true
    }

    // Hyprland's blur only reaches what's behind the whole layer, not the panel under this menu, so a
    // near-opaque backing keeps the rows underneath from showing through.
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: Theme.alpha(Theme.glassTint, 0.9)
    }
    GlassRect {
        anchors.fill: parent
        variant: "popover"
        radius: root.radius
    }

    // Presses on the menu itself don't fall through to the panel.
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

    Column {
        id: column
        x: Theme.px(6)
        y: Theme.px(6)
        width: parent.width - Theme.px(12)

        // Header: the app (or ‹ back inside a submenu)
        Item {
            width: parent.width
            height: Theme.px(6 + 20 + 8)
            Row {
                x: Theme.px(10)
                y: Theme.px(6)
                spacing: Theme.px(8)
                Item {
                    width: Theme.px(20)
                    height: width
                    Icon {
                        visible: root.levels.length > 0
                        anchors.centerIn: parent
                        name: "chevron-left"
                        size: Theme.px(15)
                        strokeWidth: 2.2
                    }
                    Rectangle {
                        visible: root.levels.length === 0
                        anchors.fill: parent
                        radius: Theme.px(6)
                        color: headerIcon.fill
                        TrayIcon { id: headerIcon; anchors.fill: parent; item: root.item; iconSize: Theme.px(12) }
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.levels.length > 0 ? root.levels[root.levels.length - 1].text.replace(/_/g, "")
                        : root.item?.tooltipTitle || root.item?.title || root.item?.id || ""
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: Theme.px(12.5)
                    font.weight: Font.DemiBold
                }
            }
            MouseArea { anchors.fill: parent; enabled: root.levels.length > 0; onClicked: root.back() }
        }

        Repeater {
            model: root.entries
            Item {
                id: entry
                required property var modelData
                required property int index
                width: column.width
                height: modelData.isSeparator ? sep.height : menuRow.height
                Separator { id: sep; visible: entry.modelData.isSeparator; above: Theme.px(4); below: Theme.px(4) }
                MenuRow {
                    id: menuRow
                    visible: !entry.modelData.isSeparator
                    width: parent.width
                    // dbusmenu marks mnemonics with "_"
                    text: (entry.modelData.text ?? "").replace(/_(?=\S)/g, "")
                    enabled: entry.modelData.enabled
                    checked: entry.modelData.buttonType !== QsMenuButtonType.None && entry.modelData.checkState === Qt.Checked
                    note: entry.modelData.hasChildren ? "›" : ""
                    lit: root.sel === entry.index
                    label.color: /^(quit|exit)\b/i.test(text) ? Theme.error : Theme.text
                    onClicked: root.pick(entry.index)
                }
            }
        }
    }
}
