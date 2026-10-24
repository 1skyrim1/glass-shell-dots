import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Command mode (> prefix, 13-LauncherStates "Command"): Enter runs the line in a shell and the output
// stays in the sheet (green, red when it fails); Shift+Enter runs it in kitty instead. ↑↓, Alt+n or a
// click put a history line into the field; only Enter runs (history may hold `sudo reboot`).
// A command still running when the sheet closes is stopped.
Column {
    id: root

    property var launcher
    property string query
    readonly property string q: query.trim()
    property int sel: -1         // history row, -1 = none
    property string output: ""
    property int exitCode: 0
    property string ran: ""
    readonly property bool showChips: false
    readonly property var hints: [["Enter", "run here"], ["Shift Enter", "run in kitty"]]
    readonly property var trailingHints: []
    readonly property var history: LauncherState.commands.slice(0, 5)

    function run(cmd: string, inKitty: bool) {
        if (cmd === "") return
        LauncherState.pushCommand(cmd)
        if (inKitty) {
            Quickshell.execDetached(["kitty", "--hold", "sh", "-c", cmd])
            launcher.close()
            return
        }
        proc.running = false
        output = ""
        exitCode = 0
        ran = cmd
        sel = -1
        proc.command = ["sh", "-c", 'eval "$1" 2>&1', "sh", cmd]
        proc.running = true
    }
    function pick(n: int) {
        if (!history[n]) return
        sel = n
        launcher.setQuery(history[n].cmd)
    }
    function jump(n: int) { pick(n) }

    function key(e: var): bool {
        if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
            run(q, e.modifiers & Qt.ShiftModifier)
            return true
        }
        if (e.key === Qt.Key_Up || e.key === Qt.Key_Down) {
            if (history.length === 0) return true
            pick(Math.max(0, Math.min(history.length - 1, sel + (e.key === Qt.Key_Down ? 1 : -1))))
            return true
        }
        return false
    }

    readonly property bool open: launcher?.shown ?? false
    onOpenChanged: if (!open) proc.running = false

    Process {
        id: proc
        stdout: SplitParser {
            onRead: line => {
                const lines = (root.output === "" ? [] : root.output.split("\n")).concat([line])
                root.output = lines.slice(-200).join("\n")
            }
        }
        onExited: code => root.exitCode = code
    }

    // --- Output, once something ran.
    Item { width: 1; height: Theme.px(10); visible: out.visible }
    Rectangle {
        id: out
        visible: root.ran !== ""
        width: parent.width
        height: Math.min(Theme.px(240), outText.implicitHeight + Theme.px(24))
        radius: Theme.px(14)
        color: Theme.alpha(Theme.scrim, 0.3)
        clip: true
        Flickable {
            anchors.fill: parent
            anchors.margins: Theme.px(12)
            anchors.leftMargin: Theme.px(14)
            contentHeight: outText.implicitHeight
            contentY: Math.max(0, contentHeight - height)   // follow the end
            Text {
                id: outText
                width: parent.width
                text: {
                    let t = root.output
                    if (proc.running) return t === "" ? "…" : t
                    if (root.exitCode !== 0) return t + (t !== "" ? "\n" : "") + `exit ${root.exitCode}`
                    return t === "" ? "done, no output" : t
                }
                color: root.exitCode === 0 ? Theme.good : Theme.error
                font.family: Theme.fontMono
                font.pixelSize: Theme.px(12)
                lineHeight: Theme.px(19)
                lineHeightMode: Text.FixedHeight
                wrapMode: Text.WrapAnywhere
                textFormat: Text.PlainText
            }
        }
    }

    // --- History.
    SectionLabel {
        visible: root.history.length > 0
        text: "History"
        above: Theme.px(root.ran !== "" ? 12 : 14)
    }
    Repeater {
        model: root.history
        Rectangle {
            id: hrow
            required property var modelData
            required property int index
            width: root.width
            height: Theme.px(38)
            radius: Theme.px(13)
            color: root.sel === index ? Theme.alpha(Theme.accent, 0.16) : hmouse.containsMouse ? Theme.white(0.05) : "transparent"
            border.width: root.sel === index ? 1 : 0
            border.color: Theme.alpha(Theme.accent, 0.35)
            Text {
                anchors { left: parent.left; leftMargin: Theme.px(12); right: when.left; rightMargin: Theme.px(12); verticalCenter: parent.verticalCenter }
                text: hrow.modelData.cmd
                color: Theme.text
                font.family: Theme.fontMono
                font.pixelSize: Theme.px(12.5)
                elide: Text.ElideRight
                textFormat: Text.PlainText
            }
            Row {
                id: when
                anchors { right: parent.right; rightMargin: Theme.px(12); verticalCenter: parent.verticalCenter }
                spacing: Theme.px(8)
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: LauncherState.ago(hrow.modelData.time, true)
                    color: Theme.textFaint
                    font.family: Theme.font
                    font.pixelSize: Theme.px(11.5)
                }
            }
            MouseArea {
                id: hmouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.pick(hrow.index)
            }
        }
    }
}
