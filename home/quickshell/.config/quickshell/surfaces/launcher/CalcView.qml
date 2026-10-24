import QtQuick
import qs.services
import qs.components

// Calculator mode (= prefix, 14-Modes "Calculator"): the result as you type in a big accent card, hex and
// binary for whole numbers, history below. Enter copies the result (and keeps it in the history), ↑ puts
// the last expression back into the field, Alt+n copies history row n.
Column {
    id: root

    property var launcher
    property string query
    onQueryChanged: Calc.evaluate(query)
    readonly property bool showChips: false
    readonly property var hints: [["Enter", "copy result"], ["↑", "reuse"]]
    readonly property var trailingHints: []
    readonly property var history: LauncherState.calc.slice(0, 4)
    property int reuse: -1

    function jump(n: int) {
        const h = history[n]
        if (!h) return
        launcher.setQuery(h.expr)
    }

    function key(e: var): bool {
        if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
            Calc.copy(() => launcher.close())
            return true
        }
        if (e.key === Qt.Key_Up || e.key === Qt.Key_Down) {
            if (history.length === 0) return true
            reuse = Math.max(0, Math.min(history.length - 1, reuse + (e.key === Qt.Key_Up ? 1 : -1)))
            launcher.setQuery(history[reuse].expr)
            return true
        }
        return false
    }

    Item { width: 1; height: Theme.px(12) }

    // --- Result card (accent 14 %, 1 px accent 30 %).
    Rectangle {
        width: parent.width
        height: card.implicitHeight + Theme.px(40)
        radius: Theme.px(18)
        color: Theme.alpha(Theme.accent, 0.14)
        border.width: 1
        border.color: Theme.alpha(Theme.accent, 0.3)
        Column {
            id: card
            x: Theme.px(18)
            y: Theme.px(20)
            width: parent.width - Theme.px(36)
            spacing: Theme.px(2)
            Text {
                text: "Result"
                color: Theme.textMuted
                font.family: Theme.font
                font.pixelSize: Theme.px(12)
            }
            Text {
                width: parent.width
                text: Calc.result !== "" ? Calc.result : "–"
                color: Calc.result !== "" ? Theme.text : Theme.textFaint
                font.family: Theme.fontMono
                font.pixelSize: Theme.px(44)
                font.weight: Font.Medium
                font.letterSpacing: Theme.px(-1)
                elide: Text.ElideRight
            }
            Text {
                visible: Calc.integer
                topPadding: Theme.px(6)
                text: `hex ${Calc.hex}  ·  bin ${Calc.bin}`
                color: Theme.textMuted
                font.family: Theme.font
                font.pixelSize: Theme.px(12)
            }
        }
    }

    // --- History: expression muted left, result right (mono 13).
    SectionLabel {
        visible: root.history.length > 0
        text: "History"
        above: Theme.px(14)
        leftPadding: Theme.px(4)
    }
    Repeater {
        model: root.history
        Item {
            required property var modelData
            required property int index
            width: root.width
            height: Theme.px(35)
            Rectangle {
                anchors.fill: parent
                radius: Theme.px(10)
                color: root.reuse === index ? Theme.white(0.06) : hover.hovered ? Theme.white(0.04) : "transparent"
            }
            HoverHandler { id: hover }
            TapHandler { onTapped: root.jump(index) }
            Text {
                anchors { left: parent.left; leftMargin: Theme.px(6); verticalCenter: parent.verticalCenter }
                text: modelData.expr
                color: Theme.textMuted
                font.family: Theme.fontMono
                font.pixelSize: Theme.px(13)
            }
            Row {
                anchors { right: parent.right; rightMargin: Theme.px(6); verticalCenter: parent.verticalCenter }
                spacing: Theme.px(8)
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.result
                    color: Theme.text
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.px(13)
                }
            }
        }
    }
}
