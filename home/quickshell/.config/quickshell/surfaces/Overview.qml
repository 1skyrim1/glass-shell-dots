import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.components
import qs.surfaces.overview

// Overview (DESIGN.md §3.2, 11-Overview; values from Overview.dc.html): Super+Tab. The desktop blurs away,
// a filter field at the top, workspace cards 1–5 (400 × 225, 3 × 2) with live window previews and the
// scratchpad card. The selected card has the accent edge, its selected window too.
// Keys (Alt shows them): ←→↑↓ or H J K L move between cards, Tab / Shift+Tab pick a window in the card,
// Enter goes there, Shift+Enter moves the window you came from to that workspace, X closes the selected
// window, / filters by title or app (Esc leaves the field), Esc closes. Super+1–5 zoom into that card.
// Motion (§5.3, 05-MotionWindows "Overview"): the current workspace zooms out of the screen into its card
// (380 ms) while the others fade in and the background blurs; leaving zooms the chosen card back up.
Scope {
    id: root

    required property ShellScreen screen

    readonly property bool shown: Shell.isOpen("overview") && (Shell.panelScreen === "" || Shell.panelScreen === screen.name)
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)

    // Cards: workspaces 1–5, then the scratchpad.
    readonly property var cards: [1, 2, 3, 4, 5, -1]
    function wsOf(i: int): HyprlandWorkspace {
        const id = cards[i]
        return Hyprland.workspaces.values.find(w => id > 0 ? w.id === id : w.name === "special:scratchpad") ?? null
    }
    function windowsOf(i: int): var { return wsOf(i)?.toplevels.values ?? [] }
    function slot(i: int): rect {
        return Qt.rect(Theme.px([172, 600, 1028][i % 3]), Theme.px([128, 408][Math.floor(i / 3)]), Theme.px(400), Theme.px(225))
    }
    // -1 on workspaces 6–9: then nothing zooms, the cards only fade in.
    readonly property int currentCard: cards.indexOf(monitor?.activeWorkspace?.id ?? 1)

    property int sel: 0                 // selected card
    property string selWin: ""          // selected window's address (no 0x), "" = none
    property string query: ""
    property bool filtering: false      // the filter field has the keyboard
    property HyprlandToplevel cameFrom: null   // the focused window when the overview opened (Shift+Enter)

    // The window to preselect in a card: the focused one, else the workspace's last focused one.
    function defaultWindow(i: int): string {
        const wins = windowsOf(i)
        if (wins.length === 0) return ""
        const active = Hyprland.activeToplevel
        if (active && wins.includes(active)) return active.address
        const last = (wsOf(i)?.lastIpcObject?.lastwindow ?? "").replace(/^0x/, "")
        return wins.some(w => w.address === last) ? last : wins[0].address
    }
    function select(i: int) {
        sel = i
        selWin = firstMatch(i) ?? defaultWindow(i)
    }
    function matches(w: HyprlandToplevel): bool {
        const q = query.toLowerCase()
        return q === "" || w.title.toLowerCase().includes(q) || (w.wayland?.appId ?? "").toLowerCase().includes(q)
    }
    function firstMatch(i: int): var {
        if (query === "") return null
        return windowsOf(i).find(w => matches(w))?.address ?? null
    }
    onQueryChanged: {
        if (query === "") return
        for (let i = 0; i < cards.length; i++) if (firstMatch(i)) return select(i)
    }

    // ←→↑↓: 3 columns, 2 rows.
    function move(dx: int, dy: int) {
        const col = Math.max(0, Math.min(2, sel % 3 + dx)), row = Math.max(0, Math.min(1, Math.floor(sel / 3) + dy))
        select(row * 3 + col)
    }
    function cycleWindow(step: int) {
        const wins = windowsOf(sel).filter(w => matches(w))
        if (wins.length === 0) return
        const i = wins.findIndex(w => w.address === selWin)
        selWin = wins[(i + step + wins.length) % wins.length].address
    }
    function selectedToplevel(): var { return windowsOf(sel).find(w => w.address === selWin) ?? null }

    // Enter: go to the selected window (or the empty workspace) and zoom into its card.
    function activate() {
        const w = selectedToplevel()
        if (w) goTo.cmd = `hl.dsp.focus({ window = "address:0x${w.address}" })`
        else if (cards[sel] > 0) goTo.cmd = `hl.dsp.focus({ workspace = ${cards[sel]} })`
        else goTo.cmd = `hl.dsp.workspace.toggle_special("scratchpad")`
        leave(sel)
        goTo.restart()
    }
    // Dispatched once the overview has let go of the keyboard: Hyprland hands focus back to the window that
    // had it before the layer took it, and that would undo an earlier focus change.
    Timer {
        id: goTo
        property string cmd: ""
        interval: 60
        onTriggered: Hyprland.dispatch(cmd)
    }
    // Shift+Enter: bring the window the overview was opened from here (it stays open to show it arrive).
    function moveHere() {
        if (!cameFrom || wsOf(sel)?.toplevels.values.includes(cameFrom)) return
        const target = cards[sel] > 0 ? cards[sel] : `"special:scratchpad"`
        Hyprland.dispatch(`hl.dsp.window.move({ workspace = ${target}, window = "address:0x${cameFrom.address}", follow = false })`)
        selWin = cameFrom.address
        refresh.restart()
    }
    function closeSelected() {
        const w = selectedToplevel()
        if (!w) return
        Hyprland.dispatch(`hl.dsp.window.close({ window = "address:0x${w.address}" })`)
        refresh.restart()
    }
    // Positions (lastIpcObject) are only fresh after a refresh; windows move after a close or move.
    Timer {
        id: refresh
        interval: Motion.small
        onTriggered: { Hyprland.refreshToplevels(); root.selWin = root.selectedToplevel() ? root.selWin : root.defaultWindow(root.sel) }
    }

    // --- Motion. zoom: 0 = the zooming card fills the screen, 1 = every card in its slot.
    // zoomCard: the card that zooms (the current workspace on the way in, the chosen one on the way out).
    property real zoom: 0
    property real fade: 0               // the whole window (reduced motion fades only)
    property int zoomCard: 0
    property bool leaving: false
    function leave(i: int) {
        zoomCard = i
        leaving = true
        Shell.close("overview")
    }

    NumberAnimation { id: zoomAnim; target: root; property: "zoom" }
    NumberAnimation { id: fadeAnim; target: root; property: "fade" }
    onShownChanged: {
        zoomAnim.stop()
        fadeAnim.stop()
        if (shown) {
            Hyprland.refreshToplevels()
            Hyprland.refreshWorkspaces()
            cameFrom = Hyprland.activeToplevel
            query = ""
            filtering = false
            leaving = false
            zoomCard = currentCard
            select(Math.max(0, currentCard))
            if (Motion.reduced) {
                zoom = 1
                fadeAnim.to = 1
                fadeAnim.duration = Motion.reducedFade
                fadeAnim.easing.type = Motion.easeSmall
                fadeAnim.start()
            } else {
                zoom = 0
                fade = 1
                zoomAnim.to = 1
                zoomAnim.duration = Motion.overviewZoom
                zoomAnim.easing.type = Motion.easeLarge
                // Starts once the window exists (startZoom); a reopen while it's still there starts now.
                if (windowUp) zoomAnim.start()
            }
        } else {
            // Esc / a click outside / locking: back into the current workspace (Super+N may have changed it).
            if (!leaving) zoomCard = currentCard
            if (Motion.reduced) {
                fadeAnim.to = 0
                fadeAnim.duration = Motion.reducedFade
                fadeAnim.easing.type = Motion.easeClose
                fadeAnim.start()
            } else {
                // Into another card: the full zoom, so Hyprland's 300 ms workspace slide underneath is over
                // by the time the card fills the screen; back into the same one: a quicker closing zoom.
                zoomAnim.to = 0
                zoomAnim.duration = leaving ? Motion.overviewZoom : Motion.close(Motion.overviewZoom)
                zoomAnim.easing.type = leaving ? Motion.easeLarge : Motion.easeClose
                zoomAnim.start()
            }
        }
    }
    // The window is created on demand and takes a moment; the first zoom frame (the card filling the screen)
    // looks like the desktop, so starting then hides that delay.
    property bool windowUp: false
    function startZoom() {
        windowUp = true
        if (shown && !Motion.reduced && zoom === 0) zoomAnim.start()
    }
    // When the zoom lands at the screen the window goes (the real desktop under it looks the same).
    Connections {
        target: zoomAnim
        function onFinished() { if (!root.shown) root.fade = 0 }
    }
    // Super+1–5 while open: zoom into that card.
    Connections {
        target: root.monitor
        function onActiveWorkspaceChanged() {
            if (root.shown && !root.leaving) {
                const i = root.cards.indexOf(root.monitor.activeWorkspace?.id ?? 0)
                if (i >= 0) root.leave(i)
            }
        }
    }

    LazyLoader {
        active: root.shown || root.fade > 0
        PanelWindow {
            id: win

            screen: root.screen
            // Above the pills (mapped later on the same layer); above a fullscreen window too.
            WlrLayershell.layer: Shell.fullscreenOn(root.screen.name) ? WlrLayer.Overlay : WlrLayer.Top
            WlrLayershell.namespace: "glass-overview"
            WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"

            // Everything but the zooming card follows this: fades in over the first part of the zoom.
            readonly property real around: Math.max(0, Math.min(1, root.zoom / 0.6))
            Component.onCompleted: Qt.callLater(root.startZoom)
            Component.onDestruction: root.windowUp = false

            FocusScope {
                id: keys
                anchors.fill: parent
                focus: true
                opacity: root.fade
                Component.onCompleted: forceActiveFocus()

                // --- Background: the wallpaper blurred and darkened (blur 28, brightness .55, saturate 1.2).
                // Zooming into another card it stays until the card fills the screen, so Hyprland's workspace
                // slide underneath never shows.
                Item {
                    anchors.fill: parent
                    opacity: root.leaving ? 1 : win.around
                    Image {
                        id: wall
                        anchors.fill: parent
                        anchors.margins: -Theme.px(40)
                        source: Theme.wallpaper ? "file://" + Theme.wallpaper : ""
                        sourceSize: Qt.size(win.width / 2, win.height / 2)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: false
                    }
                    MultiEffect {
                        anchors.fill: wall
                        source: wall
                        blurEnabled: true
                        blur: 1
                        blurMax: 48
                        saturation: 0.2
                    }
                    Rectangle {
                        anchors.fill: parent
                        color: Qt.rgba(0, 0, 0, 0.45)
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: root.shown
                    onPressed: Shell.close("overview")
                }

                // --- Filter field: 540 × 46, glass pill.
                GlassRect {
                    id: field
                    x: Math.round((win.width - width) / 2)
                    y: Theme.px(44)
                    width: Theme.px(540)
                    height: Theme.px(46)
                    opacity: win.around
                    focused: root.filtering
                    Row {
                        anchors { left: parent.left; leftMargin: Theme.px(18); verticalCenter: parent.verticalCenter }
                        spacing: Theme.px(12)
                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "search"
                            size: Theme.px(17)
                            color: Theme.textMuted
                        }
                        Item {
                            anchors.verticalCenter: parent.verticalCenter
                            width: field.width - Theme.px(18 + 17 + 12 + 10) - hint.width
                            height: input.implicitHeight
                            TextInput {
                                id: input
                                anchors.fill: parent
                                focus: root.filtering
                                text: root.query
                                onTextEdited: root.query = text
                                color: Theme.text
                                selectionColor: Theme.alpha(Theme.accent, 0.4)
                                font.family: Theme.font
                                font.pixelSize: Theme.px(14)
                                cursorVisible: root.filtering
                                // Esc, Enter, arrows and Tab go to the overview's handler first.
                                Keys.forwardTo: [keys]
                            }
                            Text {
                                anchors.fill: parent
                                visible: root.query === ""
                                text: root.filtering ? "Type to filter windows" : "Press / to filter windows"
                                color: Theme.textFaint
                                font.family: Theme.font
                                font.pixelSize: Theme.px(14)
                            }
                        }
                    }
                    KeyHint {
                        id: hint
                        anchors { right: parent.right; rightMargin: Theme.px(10); verticalCenter: parent.verticalCenter }
                        key: "Super Tab"
                    }
                }

                // --- Cards
                Repeater {
                    model: root.cards.length
                    Item {
                        id: cell
                        required property int index
                        readonly property rect slot: root.slot(index)
                        readonly property bool zooming: root.zoomCard === index
                        readonly property real e: zooming ? root.zoom : 1
                        // The zooming card runs between the screen and its slot; the others fade in from 92 %.
                        x: zooming ? slot.x * e : slot.x
                        y: zooming ? slot.y * e : slot.y
                        width: zooming ? win.width + (slot.width - win.width) * e : slot.width
                        height: zooming ? win.height + (slot.height - win.height) * e : slot.height
                        z: zooming ? 1 : 0
                        opacity: zooming ? 1 : win.around
                        scale: zooming ? 1 : 0.9 + 0.1 * win.around

                        WorkspaceCard {
                            anchors.fill: parent
                            ws: root.wsOf(cell.index)
                            scratchpad: root.cards[cell.index] < 0
                            windows: root.windowsOf(cell.index)
                            selected: root.sel === cell.index
                            selectedWindow: root.sel === cell.index ? root.selWin : ""
                            query: root.leaving ? "" : root.query
                            live: root.shown || root.fade > 0
                            zoom: cell.e
                            monW: win.width
                            monH: win.height
                        }
                        MouseArea {
                            anchors.fill: parent
                            enabled: root.shown
                            onClicked: { root.select(cell.index); root.activate() }
                        }

                        // Caption: number (600) + name (if it isn't just the number) … "Super N".
                        Item {
                            y: parent.height + Theme.px(9)
                            width: parent.width
                            height: num.implicitHeight
                            opacity: win.around
                            visible: !cell.zooming || root.zoom > 0.9
                            Row {
                                spacing: Theme.px(8)
                                Text {
                                    id: num
                                    text: root.cards[cell.index] > 0 ? root.cards[cell.index] : "S"
                                    color: Theme.text
                                    font.family: Theme.font
                                    font.pixelSize: Theme.px(13)
                                    font.weight: Font.DemiBold
                                }
                                Text {
                                    readonly property string name: root.wsOf(cell.index)?.name ?? ""
                                    text: root.cards[cell.index] < 0 ? "scratchpad" : name === String(root.cards[cell.index]) ? "" : name
                                    color: Theme.textMuted
                                    font.family: Theme.font
                                    font.pixelSize: Theme.px(13)
                                }
                            }
                            KeyHint {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                key: "Super " + num.text
                            }
                        }
                    }
                }

                // --- Key hints (Alt): the bottom row.
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Theme.px(866)
                    spacing: Theme.px(10)
                    opacity: KeyHints.held ? win.around : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: Motion.micro; easing.type: Motion.easeMicro } }
                    Repeater {
                        model: [["← → ↑ ↓", ""], ["H J K L", "move"], ["/", "filter"], ["Enter", "focus"],
                                ["Shift Enter", "move window here"], ["X", "close window"], ["Esc", "back"]]
                        Row {
                            required property var modelData
                            required property int index
                            spacing: Theme.px(10)
                            KeyHint { anchors.verticalCenter: parent.verticalCenter; key: modelData[0]; alwaysVisible: true }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: index === 0 ? "or" : modelData[1]
                                color: Theme.textMuted
                                font.family: Theme.font
                                font.pixelSize: Theme.px(12.5)
                            }
                        }
                    }
                }

                Keys.onPressed: event => {
                    const k = event.key
                    const shift = event.modifiers & Qt.ShiftModifier
                    if (event.modifiers & (Qt.ControlModifier | Qt.MetaModifier)) return
                    if (k === Qt.Key_Alt) { KeyHints.held = true; return }
                    if (root.filtering) {
                        // In the field letters type; arrows, Tab and Enter still work, Esc leaves the field.
                        if (k === Qt.Key_Escape) { root.query = ""; root.filtering = false; keys.forceActiveFocus() }
                        else if (k === Qt.Key_Return || k === Qt.Key_Enter) shift ? root.moveHere() : root.activate()
                        else if (k === Qt.Key_Left) root.move(-1, 0)
                        else if (k === Qt.Key_Right) root.move(1, 0)
                        else if (k === Qt.Key_Up) root.move(0, -1)
                        else if (k === Qt.Key_Down) root.move(0, 1)
                        else if (k === Qt.Key_Tab || k === Qt.Key_Backtab) root.cycleWindow(shift || k === Qt.Key_Backtab ? -1 : 1)
                        else return
                        event.accepted = true
                        return
                    }
                    if (k === Qt.Key_Left || k === Qt.Key_H) root.move(-1, 0)
                    else if (k === Qt.Key_Right || k === Qt.Key_L) root.move(1, 0)
                    else if (k === Qt.Key_Up || k === Qt.Key_K) root.move(0, -1)
                    else if (k === Qt.Key_Down || k === Qt.Key_J) root.move(0, 1)
                    else if (k === Qt.Key_Tab || k === Qt.Key_Backtab) root.cycleWindow(shift || k === Qt.Key_Backtab ? -1 : 1)
                    else if (k === Qt.Key_Return || k === Qt.Key_Enter) shift ? root.moveHere() : root.activate()
                    else if (k === Qt.Key_X) root.closeSelected()
                    else if (event.text === "/") { root.filtering = true; input.forceActiveFocus() }
                    else if (k === Qt.Key_Escape) Shell.close("overview")
                    else return
                    event.accepted = true
                }
                Keys.onReleased: event => { if (event.key === Qt.Key_Alt) KeyHints.held = false }
            }
        }
    }
}
