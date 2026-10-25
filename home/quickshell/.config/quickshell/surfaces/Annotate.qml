import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import qs.services
import qs.components
import qs.surfaces.annotate

// Annotate (DESIGN.md §3.7, 23-Annotate): E on the shot card (or `qs ipc call capture annotate <path>`) opens the
// image full screen over the blurred, darkened desktop. Top-left the file, top-right Copy / Save as / Done;
// the bottom toolbar has the tools, five colours, three strokes and undo / redo.
// The image is a scene at its own pixel size, scaled to fit; marks live in image pixels inside it, so the export
// (grabToImage at the native size, then an ffmpeg crop if Crop was used) is 1:1 with the screenshot.
// Keys: V A R P T H B C tools · 1–5 colour · [ ] stroke · Ctrl+Z / Ctrl+Shift+Z · Del · Ctrl+C copy · Ctrl+S save as ·
// Enter done (copies, and saves over the shot) · Esc discard (asks once if there are marks).
Scope {
    id: root

    required property ShellScreen screen

    readonly property bool shown: Capture.annotating !== ""
        && (Capture.monitor.name === screen.name || (Capture.monitor.name === "" && screen === Quickshell.screens[0]))

    // ================================================================ Editor state
    QtObject {
        id: editor

        property string tool: "arrow"
        readonly property var colors: [Theme.markRed, Theme.markYellow, Theme.accent, Theme.markWhite, Theme.markBlack]
        property int colorIndex: 0
        readonly property color color: colors[colorIndex]
        property int stroke: 1
        // Stroke widths on screen (logical px); marks store them in image px.
        readonly property var strokes: [Theme.px(2.5), Theme.px(4), Theme.px(6.5)]
        readonly property real size: strokes[stroke] / view.k

        property var marks: []
        property int selected: -1
        property var crop: null       // { x, y, w, h } in image px
        property var undoStack: []
        property var redoStack: []
        readonly property bool canUndo: undoStack.length > 0
        readonly property bool canRedo: redoStack.length > 0
        readonly property bool edited: marks.length > 0 || crop !== null

        function setTool(t: string) { finishText(); tool = t; if (t !== "select") selected = -1 }
        function setColor(i: int) {
            colorIndex = i
            if (selected >= 0) change(selected, { color: colors[i] })
        }
        function snapshot() {
            undoStack = undoStack.concat([{ marks: marks, crop: crop }])
            redoStack = []
        }
        function undo() {
            if (!canUndo) return
            redoStack = redoStack.concat([{ marks: marks, crop: crop }])
            const s = undoStack[undoStack.length - 1]
            undoStack = undoStack.slice(0, -1)
            marks = s.marks
            crop = s.crop
            selected = -1
        }
        function redo() {
            if (!canRedo) return
            undoStack = undoStack.concat([{ marks: marks, crop: crop }])
            const s = redoStack[redoStack.length - 1]
            redoStack = redoStack.slice(0, -1)
            marks = s.marks
            crop = s.crop
            selected = -1
        }
        function add(m: var) { snapshot(); marks = marks.concat([m]) }
        function change(i: int, props: var) {
            snapshot()
            const next = marks.slice()
            next[i] = Object.assign({}, marks[i], props)
            marks = next
        }
        function removeSelected() {
            if (selected < 0) return
            snapshot()
            marks = marks.filter((m, i) => i !== selected)
            selected = -1
        }

        // The mark being drawn / moved / typed, drawn by its own delegate until it's committed.
        property var draft: null
        property bool typing: false
        function finishText() {
            if (!typing) return
            typing = false
            draftMark.stopEditing()
            keys.forceActiveFocus()
            const d = draft
            draft = null
            if (d && (d.text ?? "").trim() !== "") add(d)
        }

        function reset() {
            marks = []
            crop = null
            undoStack = []
            redoStack = []
            selected = -1
            draft = null
            typing = false
            tool = "arrow"
            discardArmed = false
            saving = false
            note = ""
        }
        property bool discardArmed: false
        property bool saving: false
        property string note: ""      // "Copied" / "Saved" for a moment on the button
    }

    onShownChanged: if (shown) editor.reset()

    // Test hook (`qs ipc call capture mark …`): adds a mark with the current colour and stroke.
    Connections {
        target: Capture
        enabled: root.shown
        function onTestMark(m: var) {
            if (m.kind === "crop") { editor.snapshot(); editor.crop = root.norm(m); return }
            editor.add(Object.assign({ color: editor.color, size: editor.size }, m))
        }
    }

    // ================================================================ Export
    // grabToImage at the native size → PNG; then crop (if any), copy and / or write to `out`.
    function exportTo(out: string, copy: bool, done: var) {
        editor.finishText()
        const tmp = `${Capture.runDir}/annotate-${Date.now()}.png`
        scene.grabToImage(r => {
            r.saveToFile(tmp)
            // Without a Crop mark, crop to the image itself (a fractional scene size can round 1 px over).
            const c = editor.crop ?? { x: 0, y: 0, w: view.imgW, h: view.imgH }
            const crop = `min(iw\\,${Math.round(c.w)}):min(ih\\,${Math.round(c.h)}):${Math.round(c.x)}:${Math.round(c.y)}`
            Capture.sh(`
                src=$1; out=$2; crop=$3; copy=$4
                mkdir -p "$(dirname "$out")"
                ffmpeg -v error -y -i "$src" -vf "crop=$crop" "$out.tmp.png" && mv "$out.tmp.png" "$out"
                rm -f "$src"
                [ "$copy" = 1 ] && wl-copy -t image/png < "$out" >/dev/null 2>&1
                exit 0`, [tmp, out, crop, copy ? "1" : "0"], done)
        })
    }
    function copyNow() {
        exportTo(`${Capture.runDir}/annotated.png`, true, () => flashNote("Copied"))
    }
    function done() {
        // Saves over the shot (a "Copy" only shot lives in $XDG_RUNTIME_DIR) and copies it.
        exportTo(Capture.annotating, true, () => { Capture.lastShot = Capture.annotating; Capture.annotating = "" })
    }
    function saveAs(path: string) {
        const p = path.replace(/^~/, Quickshell.env("HOME"))
        exportTo(p, false, () => { editor.saving = false; pathInput.focus = false; flashNote("Saved"); keys.forceActiveFocus() })
    }
    function discard() {
        if (editor.edited && !editor.discardArmed) {
            editor.discardArmed = true
            disarm.restart()
            return
        }
        Capture.annotating = ""
    }
    function flashNote(n: string) { editor.note = n; noteTimer.restart() }
    Timer { id: noteTimer; interval: 1500; onTriggered: editor.note = "" }
    Timer { id: disarm; interval: 2500; onTriggered: editor.discardArmed = false }

    PanelWindow {
        id: win

        screen: root.screen
        visible: root.shown || fade.running
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "glass-shell-annotate"
        WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"

        // Rise (04-MotionOverlays): dim + blur first, then the image scales in from 92 %.
        property real p: 0
        NumberAnimation on p { id: fade; running: false }
        Connections {
            target: root
            function onShownChanged() {
                fade.stop()
                fade.to = root.shown ? 1 : 0
                fade.duration = root.shown ? Motion.open(Motion.medium) : Motion.close(Motion.medium)
                fade.easing.type = root.shown ? Motion.easeSmall : Motion.easeClose
                fade.start()
                if (root.shown) keys.forceActiveFocus()
            }
        }

        FocusScope {
            id: keys
            anchors.fill: parent
            focus: true

            // Blurred desktop (Hyprland blurs everything behind this layer) darkened to ~40 %.
            Rectangle {
                anchors.fill: parent
                color: Theme.alpha(Theme.scrim, 0.6)
                opacity: Math.min(1, win.p * 2)
            }

            Keys.onPressed: e => {
                const k = e.key, ctrl = e.modifiers & Qt.ControlModifier, shift = e.modifiers & Qt.ShiftModifier
                const tools = { [Qt.Key_V]: "select", [Qt.Key_A]: "arrow", [Qt.Key_R]: "rect", [Qt.Key_P]: "pen",
                                [Qt.Key_T]: "text", [Qt.Key_H]: "highlight", [Qt.Key_B]: "blur", [Qt.Key_C]: "crop" }
                if (ctrl && k === Qt.Key_Z) shift ? editor.redo() : editor.undo()
                else if (ctrl && k === Qt.Key_Y) editor.redo()
                else if (ctrl && k === Qt.Key_C) root.copyNow()
                else if (ctrl && k === Qt.Key_S) saveField.open()
                else if (ctrl) return
                else if (k === Qt.Key_Escape) root.discard()
                else if (k === Qt.Key_Return || k === Qt.Key_Enter) root.done()
                else if (k === Qt.Key_Delete || k === Qt.Key_Backspace) editor.removeSelected()
                else if (k >= Qt.Key_1 && k <= Qt.Key_5) editor.setColor(k - Qt.Key_1)
                else if (k === Qt.Key_BracketLeft) editor.stroke = Math.max(0, editor.stroke - 1)
                else if (k === Qt.Key_BracketRight) editor.stroke = Math.min(2, editor.stroke + 1)
                else if (tools[k] !== undefined) editor.setTool(tools[k])
                else return
                e.accepted = true
            }

            // ======================================================== The image
            Item {
                id: view
                readonly property real imgW: shotImage.implicitWidth || 1
                readonly property real imgH: shotImage.implicitHeight || 1
                // Fits between the top buttons and the caption; at most 3 screen px per image px.
                readonly property real availW: parent.width - Theme.px(160)
                readonly property real availH: Theme.px(720 - 96)
                readonly property real k: Math.min(availW / imgW, availH / imgH, 3 / scene.dpr)
                width: imgW * k
                height: imgH * k
                x: Math.round((parent.width - width) / 2)
                y: Math.round(Theme.px(96) + (availH - height) / 2)
                scale: Motion.reduced ? 1 : 0.92 + 0.08 * win.p
                opacity: Math.max(0, win.p * 2 - 1)

                RectangularShadow {
                    anchors.fill: parent
                    radius: Theme.px(12)
                    offset.y: Theme.px(30)
                    blur: Theme.px(80)
                    color: Qt.rgba(0, 0, 0, 0.6)
                }
                ClippingRectangle {
                    anchors.fill: parent
                    radius: Theme.px(12)
                    color: "transparent"

                    // The scene, exported 1:1. grabToImage renders at the screen's pixel ratio, so the scene is
                    // image px / dpr logical px with the content scaled down inside it: the grab is then exactly
                    // the image's size.
                    Item {
                        id: scene
                        // Hyprland's (fractional) scale; Qt's screen.devicePixelRatio rounds it up to 2.
                        readonly property real dpr: Hyprland.monitorFor(root.screen)?.scale || 1
                        width: view.imgW / dpr
                        height: view.imgH / dpr
                        scale: view.k * dpr
                        transformOrigin: Item.TopLeft

                        Item {
                            width: view.imgW
                            height: view.imgH
                            scale: 1 / scene.dpr
                            transformOrigin: Item.TopLeft

                            Image {
                                id: shotImage
                                source: Capture.annotating !== "" ? "file://" + Capture.annotating : ""
                                cache: false
                                smooth: false
                            }
                            Repeater {
                                model: editor.marks
                                Mark {
                                    required property var modelData
                                    required property int index
                                    mark: modelData
                                    base: shotImage
                                    visible: !(editor.draft && editor.draft.from === index)
                                }
                            }
                            Mark {
                                id: draftMark
                                visible: editor.draft !== null
                                mark: editor.draft ?? { kind: "", x1: 0, y1: 0, x2: 0, y2: 0, color: "transparent", size: 1 }
                                base: shotImage
                                editing: editor.typing
                                onTextEdited: t => { if (editor.draft) editor.draft.text = t }
                                onEditDone: editor.finishText()
                            }
                        }
                    }

                    // Crop: everything outside it dimmed, a dashed accent frame around it.
                    Item {
                        anchors.fill: parent
                        visible: editor.crop !== null || (editor.draft?.kind === "crop")
                        readonly property var c: editor.draft?.kind === "crop" ? root.norm(editor.draft) : editor.crop
                        readonly property real cx: (c?.x ?? 0) * view.k
                        readonly property real cy: (c?.y ?? 0) * view.k
                        readonly property real cw: (c?.w ?? 0) * view.k
                        readonly property real ch: (c?.h ?? 0) * view.k
                        readonly property color dim: Qt.rgba(0, 0, 0, 0.55)
                        Rectangle { width: parent.width; height: parent.cy; color: parent.dim }
                        Rectangle { y: parent.cy + parent.ch; width: parent.width; height: parent.height - y; color: parent.dim }
                        Rectangle { y: parent.cy; width: parent.cx; height: parent.ch; color: parent.dim }
                        Rectangle { x: parent.cx + parent.cw; y: parent.cy; width: parent.width - x; height: parent.ch; color: parent.dim }
                        Dashed { x: parent.cx; y: parent.cy; width: parent.cw; height: parent.ch }
                    }

                    // Selected mark: dashed box + two handles (23: the text label).
                    Item {
                        readonly property var m: editor.selected >= 0 ? editor.marks[editor.selected] : null
                        readonly property rect b: m ? root.boxOf(m) : Qt.rect(0, 0, 0, 0)
                        visible: m !== null && editor.draft === null
                        x: b.x * view.k - Theme.px(6)
                        y: b.y * view.k - Theme.px(6)
                        width: b.width * view.k + Theme.px(12)
                        height: b.height * view.k + Theme.px(12)
                        Dashed { anchors.fill: parent }
                        Handle { x: -width / 2; y: -height / 2 }
                        Handle { x: parent.width - width / 2; y: parent.height - height / 2 }
                    }
                }

                // Drawing, moving, typing.
                MouseArea {
                    id: drawArea
                    anchors.fill: parent
                    cursorShape: editor.tool === "select" ? Qt.ArrowCursor : editor.tool === "text" ? Qt.IBeamCursor : Qt.CrossCursor
                    property point from
                    property var orig: null

                    function img(e: var): point { return Qt.point(Math.max(0, Math.min(view.imgW, e.x / view.k)), Math.max(0, Math.min(view.imgH, e.y / view.k))) }

                    onPressed: e => {
                        const p = img(e)
                        editor.finishText()
                        from = p
                        if (editor.tool === "select") {
                            editor.selected = root.markAt(p)
                            if (editor.selected >= 0) {
                                orig = editor.marks[editor.selected]
                                editor.draft = Object.assign({}, orig, { from: editor.selected })
                            }
                            return
                        }
                        if (editor.tool === "text") {
                            editor.draft = { kind: "text", x1: p.x, y1: p.y, x2: p.x, y2: p.y, color: editor.color, size: editor.size, text: "" }
                            editor.typing = true
                            Qt.callLater(() => draftMark.startEditing())
                            return
                        }
                        editor.draft = { kind: editor.tool, x1: p.x, y1: p.y, x2: p.x, y2: p.y, color: editor.color, size: editor.size,
                                         points: editor.tool === "pen" ? [[p.x, p.y]] : undefined }
                    }
                    onPositionChanged: e => {
                        const d = editor.draft
                        if (!d || editor.typing || !pressed) return
                        const p = img(e)
                        if (d.from !== undefined) {
                            // Moving the selected mark.
                            const dx = p.x - from.x, dy = p.y - from.y, o = orig
                            editor.draft = Object.assign({}, d, { x1: o.x1 + dx, y1: o.y1 + dy, x2: o.x2 + dx, y2: o.y2 + dy,
                                                                   points: o.points ? o.points.map(q => [q[0] + dx, q[1] + dy]) : undefined })
                        } else if (d.kind === "pen") {
                            editor.draft = Object.assign({}, d, { points: d.points.concat([[p.x, p.y]]), x2: p.x, y2: p.y })
                        } else {
                            editor.draft = Object.assign({}, d, { x2: p.x, y2: p.y })
                        }
                    }
                    onReleased: {
                        const d = editor.draft
                        if (!d || editor.typing) return
                        editor.draft = null
                        if (d.from !== undefined) {
                            const i = d.from
                            const moved = Object.assign({}, d)
                            delete moved.from
                            if (moved.x1 !== orig.x1 || moved.y1 !== orig.y1) editor.change(i, moved)
                            return
                        }
                        const big = Math.abs(d.x2 - d.x1) > 3 || Math.abs(d.y2 - d.y1) > 3
                        if (!big && d.kind !== "pen") return
                        if (d.kind === "crop") {
                            editor.snapshot()
                            editor.crop = root.norm(d)
                        } else {
                            editor.add(d)
                        }
                    }
                    onDoubleClicked: e => {
                        // Double-click a text label to edit it.
                        const i = root.markAt(img(e))
                        if (i < 0 || editor.marks[i].kind !== "text") return
                        const m = editor.marks[i]
                        editor.snapshot()
                        editor.marks = editor.marks.filter((x, j) => j !== i)
                        editor.selected = -1
                        editor.draft = Object.assign({}, m)
                        editor.typing = true
                        Qt.callLater(() => draftMark.startEditing())
                    }
                }
            }

            // Caption under the image: what the tool does · the marks (the selected one named).
            Item {
                x: view.x
                y: view.y + view.height + Theme.px(8)
                width: view.width
                height: Theme.px(16)
                opacity: view.opacity
                Text {
                    text: root.toolHints[editor.tool]
                    font.family: Theme.font
                    font.pixelSize: Theme.px(12)
                    color: Theme.textFaint
                }
                Text {
                    anchors.right: parent.right
                    text: root.summary
                    font.family: Theme.font
                    font.pixelSize: Theme.px(12)
                    color: Theme.textFaint
                }
            }

            // ======================================================== Top bar
            GlassRect {
                variant: "pill"
                x: Theme.px(24)
                y: Theme.px(20)
                width: info.implicitWidth + Theme.px(32)
                height: Theme.px(40)
                opacity: win.p
                Row {
                    id: info
                    anchors.centerIn: parent
                    spacing: Theme.px(10)
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Screenshot " + Qt.formatTime(new Date(Capture.annotating === Capture.lastShot && Capture.lastTime > 0 ? Capture.lastTime : Date.now()), "HH:mm")
                        font.family: Theme.font
                        font.pixelSize: Theme.px(13)
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: `${view.imgW} × ${view.imgH} · ${scene.dpr}×`
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.px(12)
                        color: Theme.textFaint
                    }
                }
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: Theme.px(24)
                y: Theme.px(20)
                spacing: Theme.px(8)
                opacity: win.p
                TopButton { label: editor.note === "Copied" ? "Copied ✓" : "Copy"; key: "Ctrl C"; onClicked: root.copyNow() }
                TopButton { label: editor.note === "Saved" ? "Saved ✓" : "Save as…"; key: "Ctrl S"; onClicked: saveField.open() }
                TopButton { label: "Done"; key: "Enter"; solid: true; onClicked: root.done() }
            }

            // Save as: a path field under the buttons (Enter saves, Esc cancels).
            GlassRect {
                id: saveField
                variant: "popover"
                visible: editor.saving
                radius: Theme.px(20)
                anchors.right: parent.right
                anchors.rightMargin: Theme.px(24)
                y: Theme.px(72)
                width: Theme.px(440)
                height: Theme.px(40)
                function open() {
                    editor.saving = true
                    pathInput.text = Capture.annotating.replace(/(\.[^.]+)$/, "_annotated$1").replace(Quickshell.env("HOME"), "~")
                    pathInput.forceActiveFocus()
                    pathInput.cursorPosition = pathInput.text.length
                }
                TextInput {
                    id: pathInput
                    anchors.fill: parent
                    anchors.leftMargin: Theme.px(16)
                    anchors.rightMargin: Theme.px(16)
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.px(12)
                    color: Theme.text
                    selectionColor: Theme.alpha(Theme.accent, 0.4)
                    Keys.onPressed: e => {
                        if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { root.saveAs(text); e.accepted = true }
                        else if (e.key === Qt.Key_Escape) { editor.saving = false; pathInput.focus = false; keys.forceActiveFocus(); e.accepted = true }
                    }
                }
            }

            // Esc with marks: asks once.
            GlassRect {
                variant: "pill"
                visible: editor.discardArmed
                anchors.horizontalCenter: parent.horizontalCenter
                y: Theme.px(20)
                width: discardText.implicitWidth + Theme.px(32)
                height: Theme.px(40)
                tone: "warning"
                Text {
                    id: discardText
                    anchors.centerIn: parent
                    text: "Press Esc again to discard your marks"
                    font.family: Theme.font
                    font.pixelSize: Theme.px(13)
                    color: Theme.textOnWarning
                }
            }

            // ======================================================== Bottom toolbar + key hints
            AnnotateToolbar {
                id: toolbar
                editor: editor
                anchors.horizontalCenter: parent.horizontalCenter
                y: Theme.px(776) + (1 - win.p) * Theme.px(40)
                opacity: win.p
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                y: toolbar.y + toolbar.height + Theme.px(12)
                spacing: Theme.px(8)
                opacity: KeyHints.held ? win.p : 0
                Behavior on opacity { NumberAnimation { duration: Motion.micro; easing.type: Motion.easeMicro } }
                Repeater {
                    model: [["1–5", "colour"], ["[ ]", "stroke"], ["Ctrl Z", "undo"], ["Del", "delete selected"], ["Esc", "discard"]]
                    Row {
                        required property var modelData
                        spacing: Theme.px(8)
                        KeyHint { anchors.verticalCenter: parent.verticalCenter; key: parent.modelData[0]; alwaysVisible: true }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: parent.modelData[1]
                            font.family: Theme.font
                            font.pixelSize: Theme.px(12)
                            color: Theme.textFaint
                        }
                    }
                }
            }
        }
    }

    // ================================================================ Helpers
    readonly property var toolHints: ({
        select: "Select (V): click a mark, drag to move, Del removes it",
        arrow: "Arrow (A): drag from the tail to the point",
        rect: "Rectangle (R): drag a box",
        pen: "Pen (P): draw freehand",
        text: "Text (T): click to place a label, Enter to finish",
        highlight: "Highlight (H): drag over text",
        blur: "Blur (B): drag over what should be hidden",
        crop: "Crop (C): drag the part to keep"
    })
    readonly property var kindNames: ({ arrow: "arrow", rect: "rectangle", pen: "pen stroke", text: "text label", highlight: "highlight", blur: "blur" })
    readonly property string summary: {
        const parts = editor.marks.map((m, i) => kindNames[m.kind] + (i === editor.selected ? " selected" : ""))
        if (editor.crop) parts.push("cropped")
        if (parts.length === 0) return ""
        const s = parts.join(" · ")
        return s.charAt(0).toUpperCase() + s.slice(1)
    }

    function norm(d: var): var {
        return { x: Math.min(d.x1, d.x2), y: Math.min(d.y1, d.y2), w: Math.abs(d.x2 - d.x1), h: Math.abs(d.y2 - d.y1) }
    }
    // Bounding box of a mark in image px (text: its chip, approximated from the text length).
    function boxOf(m: var): rect {
        if (m.kind === "text") {
            const fs = m.size * 5
            return Qt.rect(m.x1, m.y1, (m.text ?? "").length * fs * 0.55 + fs * 1.4, fs * 2)
        }
        if (m.kind === "pen") {
            const xs = m.points.map(q => q[0]), ys = m.points.map(q => q[1])
            const x = Math.min(...xs), y = Math.min(...ys)
            return Qt.rect(x, y, Math.max(...xs) - x, Math.max(...ys) - y)
        }
        const n = norm(m)
        return Qt.rect(n.x, n.y, n.w, n.h)
    }
    // Topmost mark under p (with a little slack for thin strokes).
    function markAt(p: point): int {
        const slack = Theme.px(8) / view.k
        for (let i = editor.marks.length - 1; i >= 0; i--) {
            const b = boxOf(editor.marks[i])
            if (p.x >= b.x - slack && p.x <= b.x + b.width + slack && p.y >= b.y - slack && p.y <= b.y + b.height + slack) return i
        }
        return -1
    }

    // Copy / Save as… / Done: 40 px pills; Done is solid accent.
    component TopButton: Item {
        id: tb
        property string label
        property string key
        property bool solid: false
        signal clicked()
        implicitWidth: tbRow.implicitWidth + Theme.px(solid ? 36 : 32)
        implicitHeight: Theme.px(40)
        GlassRect {
            anchors.fill: parent
            variant: "pill"
            visible: !tb.solid
            hovered: tbMouse.containsMouse
            pressed: tbMouse.pressed
        }
        Rectangle {
            anchors.fill: parent
            visible: tb.solid
            radius: height / 2
            color: Theme.accent
        }
        Row {
            id: tbRow
            anchors.centerIn: parent
            spacing: Theme.px(8)
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: tb.label
                font.family: Theme.font
                font.pixelSize: Theme.px(13)
                font.weight: tb.solid ? Font.DemiBold : Font.Normal
                color: tb.solid ? Theme.textOnAccent : Theme.text
            }
            KeyHint {
                anchors.verticalCenter: parent.verticalCenter
                key: tb.key
                ink: tb.solid ? Theme.textOnAccent : "transparent"
            }
        }
        MouseArea {
            id: tbMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: tb.clicked()
        }
    }

    // 1.5 px dashed accent frame.
    component Dashed: Shape {
        id: dashed
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: Theme.accent
            strokeWidth: Theme.px(1.5)
            fillColor: "transparent"
            strokeStyle: ShapePath.DashLine
            dashPattern: [3, 3]
            PathRectangle { x: 0; y: 0; width: dashed.width; height: dashed.height }
        }
    }
    component Handle: Rectangle {
        width: Theme.px(10)
        height: width
        radius: width / 2
        color: Theme.markWhite
        border.width: Theme.px(2)
        border.color: Theme.accent
    }
}
