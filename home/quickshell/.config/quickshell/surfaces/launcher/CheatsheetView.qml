import QtQuick
import qs.services
import qs.components
import "../../components/fuzzy.js" as Fuzzy

// Shortcut cheatsheet (Super+Shift+Space or ?, 15-Cheatsheet): every described bind from hyprland.lua
// (read live, Binds.qml) in three columns of groups, category tabs (Tab = next), filter as you type.
// Here the key caps are the content, so they always show; only the footer hints wait for Alt.
// Enter runs the selected bind's action after the sheet closes.
Column {
    id: root

    property var launcher
    property string query
    property string tab: "All"
    readonly property var tabs: ["All"].concat(Binds.categories)
    readonly property bool showChips: false
    readonly property var hints: []
    readonly property var trailingHints: []

    Component.onCompleted: Binds.reload()
    readonly property bool open: launcher?.shown ?? false
    // Fresh on every open: binds re-read, back to All.
    onOpenChanged: if (open) { Binds.reload(); tab = "All" }

    readonly property string q: query.trim().toLowerCase()
    readonly property var rows: Binds.rows.filter(r => (tab === "All" || r.category === tab)
        && (q === "" || (Fuzzy.match(q, r.label)?.score ?? 0) >= 60 || r.category.toLowerCase().includes(q)
            || r.mods.concat(r.keys).join(" ").toLowerCase().split(" ").includes(q)))
    // Groups packed into three columns in order, each column filled to about a third of the rows.
    readonly property var columns: {
        const groups = []
        for (const r of rows) {
            if (groups.length === 0 || groups[groups.length - 1].name !== r.category) groups.push({ name: r.category, rows: [] })
            groups[groups.length - 1].rows.push(r)
        }
        const size = g => g.rows.length + 1.5
        const target = groups.reduce((s, g) => s + size(g), 0) / 3
        const cols = [[]]
        let filled = 0
        for (const g of groups) {
            if (filled > 0 && filled + size(g) > target * 1.15 && cols.length < 3) { cols.push([]); filled = 0 }
            cols[cols.length - 1].push(g)
            filled += size(g)
        }
        while (cols.length < 3) cols.push([])
        return cols
    }
    // Rows in reading order (column by column), for the keyboard.
    readonly property var flat: columns.reduce((all, c) => c.reduce((a, g) => a.concat(g.rows), all), [])
    property int sel: 0
    onQChanged: sel = 0
    onTabChanged: sel = 0

    function activate(i: int) {
        const r = flat[i]
        if (!r?.runnable) return
        launcher.close()
        Binds.run(r)
    }
    function jump(n: int) { activate(n) }

    function key(e: var): bool {
        const ctrl = e.modifiers & Qt.ControlModifier
        if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { activate(sel); return true }
        if (e.key === Qt.Key_Tab || e.key === Qt.Key_Backtab) {
            const i = tabs.indexOf(tab)
            tab = tabs[(i + (e.key === Qt.Key_Tab ? 1 : tabs.length - 1)) % tabs.length]
            return true
        }
        const down = e.key === Qt.Key_Down || (ctrl && e.key === Qt.Key_J)
        const up = e.key === Qt.Key_Up || (ctrl && e.key === Qt.Key_K)
        if (down || up) { sel = Math.max(0, Math.min(flat.length - 1, sel + (down ? 1 : -1))); return true }
        return false
    }

    // --- Category tabs.
    Row {
        topPadding: Theme.px(12)
        bottomPadding: Theme.px(2)
        leftPadding: Theme.px(6)
        spacing: Theme.px(4)
        Repeater {
            model: root.tabs
            Button {
                required property string modelData
                implicitWidth: tabText.implicitWidth + Theme.px(24)
                implicitHeight: Theme.px(28)
                width: implicitWidth
                height: implicitHeight
                lit: root.tab === modelData
                litColor: Theme.white(0.12)
                onClicked: root.tab = modelData
                Text {
                    id: tabText
                    anchors.centerIn: parent
                    text: modelData
                    color: root.tab === modelData ? Theme.text : Theme.textMuted
                    font.family: Theme.font
                    font.pixelSize: Theme.px(12.5)
                }
            }
        }
    }

    // --- Three columns, 1 px dividers between them.
    Row {
        id: cols
        x: Theme.px(2)
        width: parent.width - Theme.px(4)
        spacing: Theme.px(18)
        readonly property real colWidth: (width - 4 * spacing - 2) / 3

        Repeater {
            model: 3
            Row {
                id: col
                required property int index
                readonly property var groups: root.columns[index]
                // Rows in the columns before this one, so selection indices run on.
                readonly property int offset: root.columns.slice(0, index).reduce((s, c) => s + c.reduce((t, g) => t + g.rows.length, 0), 0)
                spacing: cols.spacing
                Rectangle {
                    visible: col.index > 0
                    y: Theme.px(16)
                    width: 1
                    height: cols.height - y
                    color: Theme.white(0.08)
                }
                Column {
                    width: cols.colWidth
                    Repeater {
                        model: col.groups
                        Column {
                            id: group
                            required property var modelData
                            required property int index
                            readonly property int first: col.offset + col.groups.slice(0, index).reduce((s, g) => s + g.rows.length, 0)
                            width: cols.colWidth
                            Text {
                                topPadding: Theme.px(14)
                                bottomPadding: Theme.px(6)
                                leftPadding: Theme.px(10)
                                text: group.modelData.name === "Inside surfaces" ? "Inside any surface" : group.modelData.name
                                color: Theme.secondary
                                font.family: Theme.font
                                font.pixelSize: Theme.px(11.5)
                                font.letterSpacing: Theme.px(0.6)
                                font.capitalization: Font.AllUppercase
                            }
                            Repeater {
                                model: group.modelData.rows
                                Item {
                                    id: row
                                    required property var modelData
                                    required property int index
                                    readonly property int at: group.first + index
                                    readonly property bool selected: root.sel === at
                                    width: cols.colWidth
                                    height: Theme.px(31)
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: Theme.px(9)
                                        color: row.selected ? Theme.alpha(Theme.accent, 0.16) : mouse.containsMouse ? Theme.white(0.05) : "transparent"
                                        border.width: row.selected ? 1 : 0
                                        border.color: Theme.alpha(Theme.accent, 0.35)
                                    }
                                    MouseArea {
                                        id: mouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: root.sel === row.at ? root.activate(row.at) : (root.sel = row.at)
                                    }
                                    Text {
                                        anchors { left: parent.left; leftMargin: Theme.px(10); right: caps.left; rightMargin: Theme.px(8); verticalCenter: parent.verticalCenter }
                                        text: row.modelData.label
                                        color: Theme.text
                                        font.family: Theme.font
                                        font.pixelSize: Theme.px(13)
                                        elide: Text.ElideRight
                                    }
                                    Row {
                                        id: caps
                                        anchors { right: parent.right; rightMargin: Theme.px(10); verticalCenter: parent.verticalCenter }
                                        spacing: Theme.px(4)
                                        Repeater {
                                            model: row.modelData.mods.concat(row.modelData.keys)
                                            KeyHint {
                                                required property string modelData
                                                key: modelData
                                                alwaysVisible: true
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Text {
        visible: root.rows.length === 0 && Binds.count > 0   // not while the binds are still loading
        width: parent.width
        topPadding: Theme.px(18)
        bottomPadding: Theme.px(6)
        horizontalAlignment: Text.AlignHCenter
        text: `No shortcut for “${root.query.trim()}”`
        color: Theme.textFaint
        font.family: Theme.font
        font.pixelSize: Theme.px(12.5)
    }

    // --- Footer: where the binds come from; the keys while Alt is held.
    Item { width: 1; height: Theme.px(14) }
    Rectangle {
        x: Theme.px(6)
        width: parent.width - Theme.px(12)
        height: 1
        color: Theme.white(0.10)
    }
    Item {
        width: parent.width
        height: Theme.px(12 + 2) + source.implicitHeight + (KeyHints.held ? Theme.px(2) : 0)
        Text {
            id: source
            x: Theme.px(8)
            y: Theme.px(12)
            text: Binds.count > 0 ? `Read live from hyprland.lua · ${Binds.count} binds` : "Reading hyprland.lua…"
            color: Theme.textFaint
            font.family: Theme.font
            font.pixelSize: Theme.px(12)
        }
        HintBar {
            anchors { right: parent.right; rightMargin: Theme.px(4); verticalCenter: source.verticalCenter }
            width: implicitWidth
            implicitWidth: Theme.px(400)
            above: 0
            trailing: [["↑↓", "select"], ["Enter", "run action"], ["Tab", "next group"], ["Esc", "close"]]
        }
    }
}
