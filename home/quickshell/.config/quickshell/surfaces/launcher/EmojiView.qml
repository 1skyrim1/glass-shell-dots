import QtQuick
import Quickshell
import qs.services
import qs.components

// Emoji mode (: prefix or Super+., 14-Modes "Emoji"): an 8-column grid of matches (everything when the
// field is empty), recently used ones below, Emoji · Kaomoji · Symbols tabs (Ctrl+Tab or click), and the
// selected one's name, shortcode and code point. Enter copies, Shift+Enter types it into the window you
// came from.
Column {
    id: root

    property var launcher
    property string query
    property string tab: "emoji"
    readonly property var tabs: [["emoji", "Emoji"], ["kaomoji", "Kaomoji"], ["symbols", "Symbols"]]
    readonly property int cols: tab === "kaomoji" ? 3 : 8
    readonly property var matches: Emoji.search(tab, query)
    readonly property var recent: tab === "emoji" ? LauncherState.emoji.slice(0, 8).map(g => Emoji.byGlyph(g)) : []
    // Everything selectable: the grid first, then the recent row.
    readonly property int count: matches.length + recent.length
    property int sel: 0
    readonly property var current: sel < matches.length ? matches[sel] : recent[sel - matches.length] ?? null
    readonly property bool showChips: false
    readonly property var hints: [["← → ↑ ↓", "move"], ["Enter", "copy"], ["Shift Enter", "type it"]]
    readonly property var trailingHints: []

    Component.onCompleted: Emoji.load()
    readonly property bool open: launcher?.shown ?? false
    onOpenChanged: if (open) tab = "emoji"
    onQueryChanged: sel = 0
    onTabChanged: sel = 0

    function act(i: int, type: bool) {
        const e = i < matches.length ? matches[i] : recent[i - matches.length]
        if (!e) return
        if (tab === "emoji") LauncherState.pushEmoji(e.glyph)
        if (type) Quickshell.execDetached(["sh", "-c", 'sleep 0.25; wtype -- "$1"', "sh", e.glyph])
        else Quickshell.execDetached(["wl-copy", "--", e.glyph])
        launcher.close()
    }
    function jump(n: int) { act(n, false) }

    function key(e: var): bool {
        if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { act(sel, e.modifiers & Qt.ShiftModifier); return true }
        if (e.key === Qt.Key_Tab && (e.modifiers & Qt.ControlModifier)) {
            const i = tabs.findIndex(t => t[0] === tab)
            tab = tabs[(i + 1) % tabs.length][0]
            return true
        }
        const step = { [Qt.Key_Left]: -1, [Qt.Key_Right]: 1, [Qt.Key_Up]: -cols, [Qt.Key_Down]: cols }[e.key]
        if (step === undefined) return false
        sel = Math.max(0, Math.min(count - 1, sel + step))
        if (sel < matches.length) grid.positionViewAtIndex(sel, GridView.Contain)
        return true
    }

    // One grid column; the highlight inside is square like the design's cells (kaomoji fill the column).
    component Cell: Item {
        id: cell
        required property var item
        required property int at
        readonly property bool selected: root.sel === at
        width: grid.cellWidth
        height: grid.cellHeight
        Rectangle {
            width: Math.min(parent.width - Theme.px(4), root.tab === "kaomoji" ? 1e9 : Theme.px(52))
            height: Theme.px(46)
            x: (parent.width - Theme.px(4) - width) / 2
            radius: Theme.px(12)
            color: cell.selected ? Theme.alpha(Theme.accent, 0.2) : mouse.containsMouse ? Theme.white(0.06) : "transparent"
            border.width: cell.selected ? Theme.px(1.5) : 0
            border.color: Theme.accent
            Text {
                anchors.centerIn: parent
                text: cell.item.glyph
                color: Theme.text
                font.family: root.tab === "emoji" ? "Noto Color Emoji" : Theme.font
                font.pixelSize: Theme.px(root.tab === "emoji" ? 26 : root.tab === "symbols" ? 20 : 14)
            }
            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.sel === cell.at ? root.act(cell.at, false) : (root.sel = cell.at)
            }
        }
    }

    SectionLabel { text: root.query.trim() === "" ? "All" : "Matches"; above: Theme.px(12); below: Theme.px(6) }
    Text {
        visible: root.matches.length === 0
        height: Theme.px(46)
        verticalAlignment: Text.AlignVCenter
        leftPadding: Theme.px(4)
        text: Emoji.emoji.length === 0 ? "Loading…" : "Nothing matches"
        color: Theme.textFaint
        font.family: Theme.font
        font.pixelSize: Theme.px(12.5)
    }
    GridView {
        id: grid
        visible: root.matches.length > 0
        width: parent.width + Theme.px(4)
        cellWidth: width / root.cols
        cellHeight: Theme.px(50)
        height: Math.min(Math.ceil(root.matches.length / root.cols), root.recent.length > 0 ? 2 : 3) * cellHeight - Theme.px(4)
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: root.matches
        delegate: Cell {
            required property var modelData
            required property int index
            item: modelData
            at: index
        }
    }

    SectionLabel { visible: root.recent.length > 0; text: "Recent"; above: Theme.px(12); below: Theme.px(6) }
    Row {
        visible: root.recent.length > 0
        Repeater {
            model: root.recent
            Cell {
                required property var modelData
                required property int index
                item: modelData
                at: root.matches.length + index
            }
        }
    }

    // --- Tabs.
    Row {
        topPadding: Theme.px(12)
        spacing: Theme.px(6)
        Repeater {
            model: root.tabs
            Button {
                required property var modelData
                implicitWidth: label.implicitWidth + Theme.px(20)
                implicitHeight: label.implicitHeight + Theme.px(10)
                width: implicitWidth
                height: implicitHeight
                radius: Theme.px(12)
                lit: root.tab === modelData[0]
                litColor: Theme.white(0.12)
                onClicked: root.tab = modelData[0]
                Text {
                    id: label
                    anchors.centerIn: parent
                    text: modelData[1]
                    color: root.tab === modelData[0] ? Theme.text : Theme.textMuted
                    font.family: Theme.font
                    font.pixelSize: Theme.px(12)
                }
            }
        }
    }

    // --- The selected one.
    Item { width: 1; height: Theme.px(12) }
    Rectangle {
        visible: root.current !== null
        width: parent.width
        height: Theme.px(62)
        radius: Theme.px(14)
        color: Theme.white(0.06)
        Row {
            x: Theme.px(14)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.px(12)
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.current?.glyph ?? ""
                color: Theme.text
                font.family: root.tab === "emoji" ? "Noto Color Emoji" : Theme.font
                font.pixelSize: Theme.px(root.tab === "kaomoji" ? 18 : 30)
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    text: root.current?.name ?? ""
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: Theme.px(13.5)
                    font.weight: Font.Medium
                }
                Text {
                    text: [root.current?.code ? `:${root.current.code}:` : "", root.tab === "kaomoji" ? "" : Emoji.codepoints(root.current?.glyph ?? "")]
                        .filter(s => s).join("  ·  ")
                    color: Theme.textFaint
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.px(11.5)
                }
            }
        }
    }
}
