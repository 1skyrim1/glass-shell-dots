import QtQuick
import qs.services
import qs.components

// The launcher family (DESIGN.md §3.3, 12–15): one glass sheet that drips out of the clock pill
// (02-MotionLauncher). Super+Space opens Apps; typing a prefix as the first character switches mode in
// place (= calc, ; clipboard, : emoji, > command, / files, ? shortcuts, ! web) and Backspace on the empty
// field goes back. Tab cycles modes. The cheatsheet (Super+Shift+Space, or ?) is the same sheet in
// "shortcuts" mode, 1260 px wide; switching morphs it in place.
// Enter acts and closes, Shift+Enter is the alternative, Alt+1–9 jumps, Esc closes. Each mode is a view
// (AppsView, CalcView, …) with the same small interface: query, key(event), jump(n), hints.
Item {
    id: root

    required property Item clock
    property string screenName
    anchors.fill: parent

    readonly property bool shown: Shell.launcherOpen && (Shell.panelScreen === "" || Shell.panelScreen === screenName)
    readonly property string mode: Shell.launcherMode
    readonly property bool cheat: mode === "shortcuts"
    readonly property alias body: panel.body
    readonly property alias dimLevel: panel.dimLevel
    readonly property bool active: panel.visible

    readonly property var modes: ({
        apps:      { prefix: "",  chip: "Apps",      label: "Apps",       view: "AppsView.qml",      hint: "Search apps, or type = ; : > / ? !" },
        calc:      { prefix: "=", chip: "Calc",      label: "Calculator", view: "CalcView.qml",      hint: "Maths or units, e.g. 16 GiB in MB" },
        clipboard: { prefix: ";", chip: "Clipboard", label: "Clipboard",  view: "ClipboardView.qml", hint: "Filter clipboard" },
        emoji:     { prefix: ":", chip: "Emoji",     label: "Emoji",      view: "EmojiView.qml",     hint: "Search emoji" },
        command:   { prefix: ">", chip: "Command",   label: "Command",    view: "CommandView.qml",   hint: "Run a shell command" },
        files:     { prefix: "/", chip: "Files",     label: "Files",      view: "FilesView.qml",     hint: "Search files in ~" },
        shortcuts: { prefix: "?", chip: "Shortcuts", label: "Shortcuts",  view: "CheatsheetView.qml", hint: "Search shortcuts, e.g. “record” or “workspace”" },
        web:       { prefix: "!", chip: "Web",       label: "Web",        view: "AppsView.qml",      hint: "Search the web" }
    })
    // Tab order; the chips show the same list (web has no chip: it's just "!").
    readonly property var cycle: ["apps", "calc", "clipboard", "emoji", "command", "files", "shortcuts"]
    readonly property var m: modes[mode] ?? modes.apps

    function setMode(name: string) { Shell.setLauncherMode(name) }
    function cycleMode(step: int) {
        const i = cycle.indexOf(mode)
        setMode(cycle[(Math.max(0, i) + step + cycle.length) % cycle.length])
    }
    // Views call these to act and close, or to put text into the field (history).
    function close() { Shell.closeAll() }
    function setQuery(text: string) {
        field.text = text
        field.cursorPosition = text.length
    }

    // A fresh sheet every time (only history is remembered).
    onShownChanged: if (shown) field.text = ""

    Panel {
        id: panel
        pill: root.clock
        shown: root.shown
        finalWidth: Theme.px(root.cheat ? 1260 : 660)
        finalY: Theme.px(root.cheat ? 92 : 150)
        finalRadius: Theme.px(root.cheat ? 30 : 28)
        padding: Theme.px(14)

        // --- Field: search icon (or the mode's prefix), the text, the mode chip.
        Rectangle {
            id: fieldBox
            width: parent.width
            height: Theme.px(56)
            radius: Theme.px(18)
            color: Theme.white(0.07)
            border.width: 1
            border.color: Theme.white(0.08)

            Item {
                id: lead
                x: Theme.px(16)
                width: Theme.px(20)
                height: parent.height
                Icon {
                    anchors.centerIn: parent
                    visible: root.mode === "apps" || root.cheat
                    name: root.cheat ? "keyboard" : "search"
                    size: Theme.px(20)
                    color: Theme.accent
                }
                Text {
                    anchors.centerIn: parent
                    visible: !(root.mode === "apps" || root.cheat)
                    text: root.m.prefix
                    color: Theme.secondary
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.px(18)
                }
            }

            TextInput {
                id: field
                anchors { left: lead.right; leftMargin: Theme.px(14); right: chip.left; rightMargin: Theme.px(12); verticalCenter: parent.verticalCenter }
                focus: true
                clip: true
                color: Theme.text
                selectionColor: Theme.alpha(Theme.accent, 0.35)
                selectedTextColor: Theme.text
                font.family: root.mode === "calc" || root.mode === "command" ? Theme.fontMono : Theme.font
                font.pixelSize: Theme.px(root.mode === "calc" || root.mode === "command" ? 17 : root.cheat ? 18 : 19)
                cursorDelegate: Rectangle {
                    width: 2
                    radius: 1
                    color: Theme.accent
                    visible: field.cursorVisible
                }

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    visible: field.text === ""
                    text: root.m.hint
                    color: Theme.textFaint
                    font.family: Theme.font
                    font.pixelSize: field.font.pixelSize
                    elide: Text.ElideRight
                }

                // A prefix typed into the empty Apps field switches mode; the prefix itself moves into the
                // icon slot.
                onTextChanged: {
                    if (root.mode !== "apps" || text === "") return
                    const next = root.cycle.concat(["web"]).find(n => n !== "apps" && root.modes[n].prefix === text[0])
                    if (!next) return
                    root.setMode(next)
                    text = text.slice(1)
                }

                Keys.onPressed: e => {
                    const v = view.item
                    if (e.key === Qt.Key_Escape) root.close()
                    else if (v && v.key(e)) { /* the view handled it */ }
                    else if ((e.modifiers & Qt.AltModifier) && e.key >= Qt.Key_1 && e.key <= Qt.Key_9) v?.jump(e.key - Qt.Key_1)
                    else if (e.key === Qt.Key_Tab) root.cycleMode(1)
                    else if (e.key === Qt.Key_Backtab) root.cycleMode(-1)
                    else if (e.key === Qt.Key_Backspace && text === "" && root.mode !== "apps") root.setMode("apps")
                    else return
                    e.accepted = true
                }
            }

            Rectangle {
                id: chip
                anchors { right: parent.right; rightMargin: Theme.px(12); verticalCenter: parent.verticalCenter }
                width: chipText.implicitWidth + Theme.px(root.cheat ? 24 : 20)
                height: Theme.px(28)
                radius: height / 2
                color: Theme.accent
                Behavior on width { enabled: !Motion.reduced; NumberAnimation { duration: Motion.small; easing.type: Motion.easeSmall } }
                Text {
                    id: chipText
                    anchors.centerIn: parent
                    text: root.m.chip
                    color: Theme.textOnAccent
                    font.family: Theme.font
                    font.pixelSize: Theme.px(12)
                    font.weight: Font.DemiBold
                }
            }
        }

        // --- The mode's view.
        Loader {
            id: view
            width: parent.width
            source: root.m.view
            onLoaded: item.launcher = root
        }
        Binding { target: view.item; property: "query"; value: field.text; when: view.status === Loader.Ready }

        // --- Mode chips (12-Launcher): while searching apps. The chip row follows Tab.
        Item {
            width: parent.width
            visible: view.item?.showChips ?? false
            implicitHeight: visible ? chips.height + Theme.px(25) : 0
            Rectangle {
                x: Theme.px(4)
                y: Theme.px(12)
                width: parent.width - Theme.px(8)
                height: 1
                color: Theme.white(0.10)
            }
            Flow {
                id: chips
                x: Theme.px(2)
                y: Theme.px(25)
                width: parent.width - Theme.px(4)
                spacing: Theme.px(6)
                Repeater {
                    model: root.cycle
                    Button {
                        required property string modelData
                        readonly property var info: root.modes[modelData]
                        implicitWidth: chipRow.implicitWidth + Theme.px(20)
                        implicitHeight: Theme.px(28)
                        width: implicitWidth
                        height: implicitHeight
                        base: Theme.white(0.06)
                        lit: root.mode === modelData
                        litColor: Theme.alpha(Theme.accent, 0.22)
                        onClicked: root.setMode(modelData)
                        Row {
                            id: chipRow
                            anchors.centerIn: parent
                            spacing: Theme.px(6)
                            Text {
                                visible: info.prefix !== ""
                                text: info.prefix
                                color: Theme.secondary
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.px(12)
                            }
                            Text {
                                text: info.label
                                color: root.mode === modelData ? Theme.textOnContainer : Theme.textMuted
                                font.family: Theme.font
                                font.pixelSize: Theme.px(12)
                            }
                        }
                    }
                }
            }
        }

        HintBar {
            visible: !root.cheat
            hints: view.item?.hints ?? []
            trailing: view.item?.trailingHints ?? []
        }
    }
}
