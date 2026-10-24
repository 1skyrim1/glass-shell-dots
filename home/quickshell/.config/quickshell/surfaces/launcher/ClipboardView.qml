import QtQuick
import qs.services
import qs.components
import "../../components/fuzzy.js" as Fuzzy

// Clipboard history (; prefix or Super+V, 14-Modes "Clipboard history"): the list on the left (pins first,
// starred), a preview of the selected entry on the right (code lightly coloured, images shown).
// Enter copies, Shift+Enter pastes into the window you came from, P pins, Del removes; while filtering
// those two are Ctrl+P and Shift+Del, so typing still works.
Column {
    id: root

    property var launcher
    property string query
    readonly property string q: query.trim()
    readonly property var entries: q === "" ? Clipboard.entries
        : Clipboard.entries.filter(e => Fuzzy.match(q, e.title) || Fuzzy.match(q, e.preview))
    property int sel: 0
    readonly property var current: entries[Math.min(sel, entries.length - 1)] ?? null
    readonly property bool showChips: false
    readonly property var hints: [["Enter", "copy"], ["Shift Enter", "paste"], ["P", "pin"], ["Del", "remove"]]
    readonly property var trailingHints: []

    onQChanged: sel = 0
    onCurrentChanged: previewDelay.restart()
    Timer { id: previewDelay; interval: 40; onTriggered: Clipboard.load(root.current) }
    Component.onCompleted: Clipboard.refresh()

    function act(i: int, paste: bool) {
        const e = entries[i]
        if (!e) return
        paste ? Clipboard.paste(e) : Clipboard.copy(e)
        launcher.close()
    }
    function jump(n: int) { act(n, false) }

    function key(e: var): bool {
        const ctrl = e.modifiers & Qt.ControlModifier, shift = e.modifiers & Qt.ShiftModifier
        if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { act(sel, shift); return true }
        if (e.key === Qt.Key_P && (ctrl || q === "") && !shift && current) { Clipboard.togglePin(current); return true }
        if (e.key === Qt.Key_Delete && (shift || q === "") && current) { Clipboard.remove(current); return true }
        const down = e.key === Qt.Key_Down || (ctrl && e.key === Qt.Key_J)
        const up = e.key === Qt.Key_Up || (ctrl && e.key === Qt.Key_K)
        if (down || up) {
            sel = Math.max(0, Math.min(entries.length - 1, sel + (down ? 1 : -1)))
            list.positionViewAtIndex(sel, ListView.Contain)
            return true
        }
        return false
    }

    readonly property var icons: ({ image: "image", link: "link", code: "code", text: "text", file: "file", colour: "" })

    // A light highlighter for the preview: strings in the "good" green, names called like f(…) in accent.
    function colour(text: string): string {
        const re = /("[^"\n]*"?|'[^'\n]*'?)|([A-Za-z_][\w.]*)(?=\()/g
        let out = "", last = 0, m
        const esc = s => Fuzzy.escape(s).replace(/ /g, "&nbsp;").replace(/\n/g, "<br>")
        while ((m = re.exec(text)) !== null) {
            out += esc(text.slice(last, m.index))
            out += `<font color="${m[1] ? Theme.good : Theme.accent}">${esc(m[0])}</font>`
            last = m.index + m[0].length
        }
        return out + esc(text.slice(last))
    }
    function language(text: string): string {
        if (/^\s*(local |function\b|hl\.|bind\()|\bend\s*$/m.test(text)) return "lua"
        if (/^\s*(import Qt|import qs|[A-Z]\w* \{)/m.test(text)) return "qml"
        if (/^\s*(def |from \w+ import|import \w+$)/m.test(text)) return "python"
        if (/^\s*(const |let |function |export |import .* from)/m.test(text)) return "js"
        if (/^#!\/|^\s*(sudo |cd |export |if \[)/m.test(text)) return "shell"
        if (/^\s*[{\[]\s*"/.test(text)) return "json"
        if (/^\s*#include/m.test(text)) return "c"
        return ""
    }

    Item { width: 1; height: Theme.px(12) }

    Text {
        visible: Clipboard.entries.length === 0
        width: parent.width
        topPadding: Theme.px(10)
        bottomPadding: Theme.px(14)
        horizontalAlignment: Text.AlignHCenter
        text: "Nothing copied yet"
        color: Theme.textFaint
        font.family: Theme.font
        font.pixelSize: Theme.px(12.5)
    }

    Row {
        visible: Clipboard.entries.length > 0
        width: parent.width
        spacing: Theme.px(12)

        ListView {
            id: list
            width: Math.round(parent.width * 0.5)
            height: Theme.px(5 * 52 - 2)
            clip: true
            spacing: Theme.px(2)
            model: root.entries
            boundsBehavior: Flickable.StopAtBounds
            currentIndex: root.sel

            delegate: Item {
                id: row
                required property var modelData
                required property int index
                readonly property bool selected: root.sel === index
                width: list.width
                height: Theme.px(50)

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.px(12)
                    color: row.selected ? Theme.alpha(Theme.accent, 0.16) : mouse.containsMouse ? Theme.white(0.05) : "transparent"
                    border.width: row.selected ? 1 : 0
                    border.color: Theme.alpha(Theme.accent, 0.35)
                }
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.sel === row.index ? root.act(row.index, false) : (root.sel = row.index)
                }
                Rectangle {
                    id: type
                    x: Theme.px(12)
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.px(30)
                    height: width
                    radius: Theme.px(9)
                    // A colour entry shows the colour itself.
                    color: row.modelData.kind === "colour" ? row.modelData.title : Theme.white(0.07)
                    Icon {
                        anchors.centerIn: parent
                        visible: row.modelData.kind !== "colour"
                        name: root.icons[row.modelData.kind] ?? "text"
                        size: Theme.px(15)
                        color: Theme.textMuted
                    }
                }
                Column {
                    anchors { left: type.right; leftMargin: Theme.px(12); right: star.left; rightMargin: Theme.px(8); verticalCenter: parent.verticalCenter }
                    Text {
                        width: parent.width
                        text: row.modelData.title
                        color: Theme.text
                        font.family: ["code", "colour"].includes(row.modelData.kind) ? Theme.fontMono : Theme.font
                        font.pixelSize: Theme.px(row.modelData.kind === "code" ? 12 : 12.5)
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        textFormat: Text.PlainText
                    }
                    Text {
                        width: parent.width
                        text: [row.modelData.sub, LauncherState.ago(row.modelData.time, false)].filter(s => s).join(" · ")
                        color: Theme.textFaint
                        font.family: Theme.font
                        font.pixelSize: Theme.px(11)
                        elide: Text.ElideRight
                    }
                }
                Item {
                    id: star
                    anchors { right: parent.right; rightMargin: Theme.px(12); verticalCenter: parent.verticalCenter }
                    width: row.modelData.pinned ? pin.width : 0
                    height: Theme.px(15)
                    Icon {
                        id: pin
                        anchors.centerIn: parent
                        visible: row.modelData.pinned
                        name: "star"
                        size: Theme.px(14)
                        color: Theme.secondary
                    }
                }
            }
        }

        // --- Preview pane.
        Rectangle {
            width: parent.width - list.width - parent.spacing
            height: list.height
            radius: Theme.px(16)
            color: Theme.alpha(Theme.scrim, 0.28)
            clip: true

            readonly property var e: root.current
            readonly property var pv: Clipboard.preview

            Text {
                id: header
                x: Theme.px(14)
                y: Theme.px(14)
                width: parent.width - Theme.px(28)
                text: !parent.e ? "" : parent.e.kind === "image" ? `Preview · ${parent.e.sub}`
                    : ["Preview", `${parent.pv.lines} line${parent.pv.lines === 1 ? "" : "s"}`, root.language(parent.pv.text)].filter(s => s).join(" · ")
                color: Theme.textFaint
                font.family: Theme.font
                font.pixelSize: Theme.px(11.5)
                elide: Text.ElideRight
            }
            Text {
                anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: footer.top; margins: Theme.px(14); topMargin: Theme.px(10) }
                visible: parent.pv.image === ""
                text: root.colour(parent.pv.text)
                textFormat: Text.StyledText
                color: Theme.text
                font.family: parent.e?.kind === "text" ? Theme.font : Theme.fontMono
                font.pixelSize: Theme.px(11.5)
                lineHeight: Theme.px(19)
                lineHeightMode: Text.FixedHeight
                wrapMode: Text.WrapAnywhere
                elide: Text.ElideRight
                clip: true
            }
            Image {
                anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: footer.top; margins: Theme.px(14); topMargin: Theme.px(10) }
                visible: parent.pv.image !== ""
                source: parent.pv.image !== "" ? "file://" + parent.pv.image : ""
                fillMode: Image.PreserveAspectFit
                horizontalAlignment: Image.AlignLeft
                verticalAlignment: Image.AlignTop
                asynchronous: true
                cache: false
                sourceSize.width: width * 2
            }
            Text {
                id: footer
                anchors { left: parent.left; leftMargin: Theme.px(14); bottom: parent.bottom; bottomMargin: Theme.px(14) }
                text: parent.e?.source ? `copied from ${parent.e.source}` : ""
                color: Theme.textFaint
                font.family: Theme.font
                font.pixelSize: Theme.px(11.5)
            }
        }
    }
}
