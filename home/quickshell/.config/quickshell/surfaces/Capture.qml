import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.services
import qs.components
import qs.surfaces.capture

// The capture tool on one screen (DESIGN.md §3.7; 21-CaptureRegion, 22-CaptureWindow, 24-CaptureExtras), driven
// by services/Capture.qml. Two Overlay layers, like the bar's dim under its pills:
//  1. "glass-capture-freeze" (not blurred): the frozen frame, the 58 % dim with the target cut out, selection +
//     handles / window outline / screen frame, the loupe, the flashes and the selection flying into the corner.
//     It takes the pointer. During a countdown it shows only the dim and the outline over the live screen.
//  2. "glass-shell-capture" (glass, so Hyprland blurs the dimmed frame behind it): toolbar, size / window pills,
//     the colour chip and the countdown. It holds the keyboard. Mapped after layer 1 so it stacks above it.
// Motion (04-MotionOverlays "Capture"): soft flash on freeze, dim (200 ms), the toolbar rises; the selection draws
// from the drag point. On capture a second flash, the dim clears and the selection flies into the bottom-left
// thumbnail (300 ms), where the card (CaptureCards.qml) takes over.
Scope {
    id: root

    required property ShellScreen screen

    readonly property bool here: Capture.monitor.name === screen.name
    readonly property string phase: here ? Capture.phase : ""
    readonly property bool picker: Capture.tool === "color"
    readonly property bool flying: phase === "shooting" && Capture.flyFrom !== null
    readonly property real s: Capture.monitor.scale || 1   // physical px per logical px
    function rectL(r: var): var { return r ? { x: r.x / s, y: r.y / s, w: r.w / s, h: r.h / s } : null }

    // The cut-out in the dim (logical px): the selection or the target window.
    readonly property var hole: picker || Capture.mode === "screen" ? null : rectL(Capture.rect)

    // Layer 2 maps once layer 1 is up (or straight away for a countdown).
    property bool uiReady: false
    onPhaseChanged: {
        if (phase === "") uiReady = false
        else if (phase === "countdown") uiReady = true
    }
    Timer {
        id: uiDelay
        interval: 30
        onTriggered: root.uiReady = true
    }

    // ================================================================ Layer 1: frozen frame
    PanelWindow {
        id: frozen

        screen: root.screen
        visible: root.phase === "open" || root.phase === "countdown" || root.flying
        onVisibleChanged: if (visible) uiDelay.restart()
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "glass-capture-freeze"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        // Live screen during a countdown: clicks pass through.
        mask: Region { item: root.phase === "countdown" ? null : stage }

        Item {
            id: stage
            anchors.fill: parent

            // 0 → 1 as the tool opens (dim), back to 0 once the capture is taken.
            property real dim: 0
            readonly property bool up: root.phase === "open" || root.phase === "countdown"
            onUpChanged: {
                dimAnim.to = up ? 1 : 0
                dimAnim.duration = up ? Motion.fixed(Motion.captureDim) : Motion.close(Motion.captureDim)
                dimAnim.restart()
                if (up && root.phase === "open") flash.fire(0.6)
            }
            NumberAnimation { id: dimAnim; target: stage; property: "dim"; easing.type: Motion.easeSmall }

            Image {
                id: frame
                anchors.fill: parent
                visible: root.phase !== "countdown"
                source: Capture.frame !== "" ? "file://" + Capture.frame : ""
                cache: true
                smooth: false
                asynchronous: false
                // The live screen shows through once the shot is taken.
                opacity: root.phase === "open" ? 1 : stage.dim
            }

            // --- Dim, 58 % (24: 55 % during the countdown), with the target cut out.
            Item {
                anchors.fill: parent
                visible: !root.picker && Capture.mode !== "screen"
                opacity: stage.dim
                readonly property var h: root.hole ?? { x: 0, y: 0, w: 0, h: 0 }
                readonly property color c: Theme.alpha(Theme.scrim, root.phase === "countdown" ? 0.55 : 0.58)
                Rectangle { width: parent.width; height: parent.h.y; color: parent.c }
                Rectangle { y: parent.h.y + parent.h.h; width: parent.width; height: parent.height - y; color: parent.c }
                Rectangle { y: parent.h.y; width: parent.h.x; height: parent.h.h; color: parent.c }
                Rectangle { x: parent.h.x + parent.h.w; y: parent.h.y; width: parent.width - x; height: parent.h.h; color: parent.c }
            }

            // --- Screen mode: the whole screen gets the accent frame (24 "Screen mode").
            Rectangle {
                anchors.fill: parent
                visible: !root.picker && Capture.mode === "screen"
                opacity: stage.dim
                color: Theme.alpha(Theme.accent, 0.08)
                border.width: Theme.px(3)
                border.color: Theme.accent
            }

            // --- Region: 2 px accent frame (+1 px dark edge) and 8 handles.
            Item {
                id: sel
                visible: !root.picker && Capture.mode === "region" && root.hole !== null && root.phase !== "shooting"
                opacity: stage.dim
                x: root.hole?.x ?? 0
                y: root.hole?.y ?? 0
                width: root.hole?.w ?? 0
                height: root.hole?.h ?? 0
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -Theme.px(1) - 1
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.rgba(0, 0, 0, 0.4)
                }
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -Theme.px(1)
                    color: "transparent"
                    border.width: Theme.px(2)
                    border.color: Theme.accent
                }
                Repeater {
                    model: root.phase === "countdown" ? [] : [[0, 0], [0.5, 0], [1, 0], [0, 0.5], [1, 0.5], [0, 1], [0.5, 1], [1, 1]]
                    Rectangle {
                        required property var modelData
                        x: sel.width * modelData[0] - width / 2
                        y: sel.height * modelData[1] - height / 2
                        width: Theme.px(12)
                        height: width
                        radius: width / 2
                        color: Theme.markWhite
                        border.width: Theme.px(2)
                        border.color: Theme.accent
                    }
                }
            }

            // --- Window: 3 px accent outline (radius 16) with a 6 px accent halo, gliding between windows.
            Item {
                id: outline
                visible: !root.picker && Capture.mode === "window" && root.hole !== null && root.phase !== "shooting"
                opacity: stage.dim
                readonly property real grow: Theme.px(2)
                x: (root.hole?.x ?? 0) - grow
                y: (root.hole?.y ?? 0) - grow
                width: (root.hole?.w ?? 0) + 2 * grow
                height: (root.hole?.h ?? 0) + 2 * grow
                Behavior on x { enabled: outline.visible; NumberAnimation { duration: Motion.micro; easing.type: Motion.easeMicro } }
                Behavior on y { enabled: outline.visible; NumberAnimation { duration: Motion.micro; easing.type: Motion.easeMicro } }
                Behavior on width { enabled: outline.visible; NumberAnimation { duration: Motion.micro; easing.type: Motion.easeMicro } }
                Behavior on height { enabled: outline.visible; NumberAnimation { duration: Motion.micro; easing.type: Motion.easeMicro } }
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -Theme.px(6)
                    radius: Theme.px(16 + 6)
                    color: "transparent"
                    border.width: Theme.px(6)
                    border.color: Theme.alpha(Theme.accent, 0.2)
                }
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.px(16)
                    color: "transparent"
                    border.width: Theme.px(root.phase === "countdown" ? 2.5 : 3)
                    border.color: Theme.accent
                }
            }

            // --- Pointer: draw / move / resize the selection, hover windows, pick colours.
            MouseArea {
                id: pointer
                anchors.fill: parent
                enabled: root.phase === "open"
                hoverEnabled: true
                cursorShape: root.picker || Capture.mode === "region" ? Qt.CrossCursor : Qt.ArrowCursor
                property string drag: ""      // "" | "new" | "move" | handle: n, s, e, w, ne, nw, se, sw
                property point from
                property var fromSel
                readonly property bool active: drag !== ""

                function phys(e: var): point {
                    return Qt.point(Math.max(0, Math.min(Capture.monitor.width - 1, Math.round(e.x * root.s))),
                                    Math.max(0, Math.min(Capture.monitor.height - 1, Math.round(e.y * root.s))))
                }
                function handleAt(p: point): string {
                    const r = Capture.selection, near = Theme.px(10) * root.s
                    const col = Math.abs(p.x - r.x) < near ? "w" : Math.abs(p.x - r.x - r.w) < near ? "e"
                              : Math.abs(p.x - r.x - r.w / 2) < near ? "c" : ""
                    const row = Math.abs(p.y - r.y) < near ? "n" : Math.abs(p.y - r.y - r.h) < near ? "s"
                              : Math.abs(p.y - r.y - r.h / 2) < near ? "c" : ""
                    if (col === "" || row === "" || (col === "c" && row === "c")) return ""
                    return (row === "c" ? "" : row) + (col === "c" ? "" : col)
                }

                onPositionChanged: e => {
                    const p = phys(e)
                    Capture.cursorPos = p
                    if (root.picker) return
                    if (Capture.mode === "window" && !pressed) {
                        const i = Capture.windowAt(p.x, p.y)
                        if (i >= 0) Capture.targetIndex = i
                    }
                    if (drag === "") return
                    const r = fromSel
                    if (drag === "new") {
                        Capture.selection = { x: Math.min(from.x, p.x), y: Math.min(from.y, p.y), w: Math.abs(p.x - from.x), h: Math.abs(p.y - from.y) }
                    } else if (drag === "move") {
                        Capture.selection = { x: Math.max(0, Math.min(Capture.monitor.width - r.w, r.x + p.x - from.x)),
                                              y: Math.max(0, Math.min(Capture.monitor.height - r.h, r.y + p.y - from.y)), w: r.w, h: r.h }
                    } else {
                        let l = r.x, t = r.y, rr = r.x + r.w, b = r.y + r.h
                        if (drag.includes("w")) l = p.x
                        if (drag.includes("e")) rr = p.x
                        if (drag.includes("n")) t = p.y
                        if (drag.includes("s")) b = p.y
                        Capture.selection = { x: Math.min(l, rr), y: Math.min(t, b), w: Math.abs(rr - l), h: Math.abs(b - t) }
                    }
                }
                onPressed: e => {
                    if (root.picker || Capture.mode !== "region") return
                    const p = phys(e), r = Capture.selection
                    toolbar.held = root.hole
                    from = p
                    fromSel = r
                    const h = handleAt(p)
                    if (h !== "") drag = h
                    else if (p.x > r.x && p.x < r.x + r.w && p.y > r.y && p.y < r.y + r.h) drag = "move"
                    else {
                        drag = "new"
                        Capture.selection = { x: p.x, y: p.y, w: 0, h: 0 }
                    }
                }
                onReleased: drag = ""
                onClicked: e => {
                    if (root.picker) Capture.pick()
                    // Window mode: hovering picks the window, clicking it captures.
                    else if (Capture.mode === "window" && Capture.windowAt(phys(e).x, phys(e).y) >= 0) Capture.capture()
                    else if (Capture.mode === "screen") Capture.capture()
                }
                onDoubleClicked: if (!root.picker && Capture.mode === "region") Capture.capture()
            }

            // --- Region loupe (104 px) with the hex under it, next to the cursor (hidden over the toolbar).
            Item {
                id: regionLoupe
                readonly property point c: Qt.point(Capture.cursorPos.x / root.s, Capture.cursorPos.y / root.s)
                visible: !root.picker && Capture.mode === "region" && root.phase === "open"
                    && !(c.x >= toolbar.x && c.x <= toolbar.x + toolbar.width && c.y >= toolbar.y && c.y <= toolbar.y + toolbar.height)
                readonly property real gap: Theme.px(12)
                x: c.x + gap + loupe.width > stage.width ? c.x - gap - loupe.width : c.x + gap
                y: c.y + gap + height > stage.height ? c.y - gap - height : c.y + gap
                width: loupe.width
                height: loupe.height + Theme.px(24)
                Loupe {
                    id: loupe
                    source: frame.source
                    pixel: Capture.cursorPos
                    frame: Qt.size(Capture.monitor.width, Capture.monitor.height)
                }
                Text {
                    y: loupe.height + Theme.px(6)
                    width: loupe.width
                    horizontalAlignment: Text.AlignHCenter
                    text: Capture.hex(Capture.pickColor)
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.px(11)
                    color: Theme.text
                    style: Text.Raised
                    styleColor: Qt.rgba(0, 0, 0, 0.35)
                }
            }

            // --- Colour picker: crosshair at the cursor, 120 px loupe (one pixel boxed) under it.
            Item {
                visible: root.picker && root.phase === "open"
                readonly property point c: Qt.point(Capture.cursorPos.x / root.s, Capture.cursorPos.y / root.s)
                Rectangle { x: parent.c.x; y: parent.c.y - Theme.px(19); width: 1; height: Theme.px(40); color: Qt.rgba(0, 0, 0, 0.6) }
                Rectangle { x: parent.c.x - Theme.px(20); y: parent.c.y; width: Theme.px(40); height: 1; color: Qt.rgba(0, 0, 0, 0.6) }
                Loupe {
                    id: pickLoupe
                    x: Math.min(stage.width - width - Theme.px(8), parent.c.x + Theme.px(10))
                    y: parent.c.y + Theme.px(21) + width + Theme.px(70) > stage.height ? parent.c.y - Theme.px(21) - width : parent.c.y + Theme.px(21)
                    width: Theme.px(120)
                    cell: Theme.px(12)
                    boxed: true
                    ring: Theme.px(3)
                    ringColor: Theme.markWhite
                    source: frame.source
                    pixel: Capture.cursorPos
                    frame: Qt.size(Capture.monitor.width, Capture.monitor.height)
                }
            }

            // Reads the frozen pixel under the cursor (loupe hex, colour picker).
            Canvas {
                id: sampler
                width: 1
                height: 1
                opacity: 0.01
                renderStrategy: Canvas.Immediate
                property string src: frame.source.toString()
                onSrcChanged: if (src !== "") loadImage(src)
                onImageLoaded: requestPaint()
                Connections {
                    target: Capture
                    function onCursorPosChanged() { sampler.requestPaint() }
                }
                onPaint: {
                    if (src === "" || !isImageLoaded(src)) return
                    const ctx = getContext("2d")
                    ctx.clearRect(0, 0, 1, 1)
                    ctx.drawImage(src, Capture.cursorPos.x, Capture.cursorPos.y, 1, 1, 0, 0, 1, 1)
                    const d = ctx.getImageData(0, 0, 1, 1).data
                    Capture.pickColor = Qt.rgba(d[0] / 255, d[1] / 255, d[2] / 255, 1)
                }
            }

            // --- The shot flies into the corner thumbnail (bottom-left card, CaptureCards.qml).
            ClippingRectangle {
                id: fly
                property real t: 0
                readonly property var a: Capture.flyFrom ?? { x: 0, y: 0, w: 1, h: 1 }
                readonly property var b: ({ x: Theme.px(52), y: stage.height - Theme.px(188), w: Theme.px(112), h: Theme.px(70) })
                visible: root.flying
                x: a.x + (b.x - a.x) * t
                y: a.y + (b.y - a.y) * t
                width: a.w + (b.w - a.w) * t
                height: a.h + (b.h - a.h) * t
                radius: Theme.px(10) * t
                color: "transparent"
                // The shot "covers" the box as it shrinks to the thumbnail's shape.
                Image {
                    readonly property real k: Math.max(fly.width / fly.a.w, fly.height / fly.a.h)
                    source: frame.source
                    smooth: true
                    width: stage.width
                    height: stage.height
                    scale: k
                    transformOrigin: Item.TopLeft
                    x: -fly.a.x * k + (fly.width - fly.a.w * k) / 2
                    y: -fly.a.y * k + (fly.height - fly.a.h * k) / 2
                }
                Rectangle {
                    anchors.fill: parent
                    radius: fly.radius
                    color: "transparent"
                    border.width: Theme.px(2)
                    border.color: Theme.alpha(Theme.accent, 1 - fly.t)
                }
            }
            // After the flash, the shot flies (300 ms); then the card takes over.
            Timer {
                id: flyDelay
                interval: Motion.captureFlash
                onTriggered: flyAnim.restart()
            }
            NumberAnimation {
                id: flyAnim
                target: fly
                property: "t"
                from: 0
                to: 1
                duration: Motion.fixed(Motion.captureFly)
                easing.type: Easing.InOutCubic
                onFinished: Capture.flown()
            }
            Connections {
                target: root
                function onFlyingChanged() {
                    if (!root.flying) return
                    fly.t = 0
                    flash.fire(0.55)
                    flyDelay.restart()
                }
            }

            // --- Flash: white, soft on freeze (60 %), again on capture (55 %).
            Rectangle {
                id: flash
                anchors.fill: parent
                color: Theme.markWhite
                opacity: 0
                function fire(peak: real) {
                    if (Motion.reduced) return
                    opacity = peak
                    flashAnim.restart()
                }
                NumberAnimation { id: flashAnim; target: flash; property: "opacity"; to: 0; duration: Motion.captureFlash; easing.type: Motion.easeSmall }
            }
        }
    }

    // ================================================================ Layer 2: toolbar and pills (glass)
    PanelWindow {
        id: ui

        screen: root.screen
        visible: root.uiReady && (root.phase === "open" || root.phase === "countdown" || root.flying)
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "glass-shell-capture"
        WlrLayershell.keyboardFocus: root.phase === "open" || root.phase === "countdown" ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        mask: Region {
            Region { item: toolbar.visible ? toolbar : null }
            Region { item: countdown.visible ? countdown : null }
        }

        FocusScope {
            id: keys
            anchors.fill: parent
            focus: true
            Component.onCompleted: forceActiveFocus()
            Connections {
                target: ui
                function onVisibleChanged() { if (ui.visible) keys.forceActiveFocus() }
            }

            // Enter and Esc act on release: the layer gives the keyboard back as it closes, and a key still
            // held then would reach the window underneath.
            property int armed: 0
            Keys.onReleased: e => {
                if (e.isAutoRepeat || e.key !== armed) return
                armed = 0
                e.accepted = true
                if (e.key === Qt.Key_Escape) Capture.close()
                else if (root.picker) Capture.pick()
                else Capture.capture()
            }
            Keys.onPressed: e => {
                const k = e.key, shift = e.modifiers & Qt.ShiftModifier
                const step = shift ? 10 : 1
                if (k === Qt.Key_Escape || ((k === Qt.Key_Return || k === Qt.Key_Enter) && root.phase === "open")) {
                    armed = k
                    e.accepted = true
                    return
                }
                if (root.phase !== "open") return
                else if (k === Qt.Key_Left || k === Qt.Key_Right || k === Qt.Key_Up || k === Qt.Key_Down) {
                    if (!root.picker && Capture.mode === "window") Capture.nextWindow(k === Qt.Key_Left || k === Qt.Key_Up ? -1 : 1)
                    else Capture.nudge(k === Qt.Key_Left ? -step : k === Qt.Key_Right ? step : 0, k === Qt.Key_Up ? -step : k === Qt.Key_Down ? step : 0)
                }
                else if (root.picker) {
                    if (k === Qt.Key_Tab || k === Qt.Key_Backtab) Capture.cyclePickFormat()
                    else return
                }
                else if (k === Qt.Key_R) Capture.setMode("region")
                else if (k === Qt.Key_W) Capture.setMode("window")
                else if (k === Qt.Key_S) Capture.setMode("screen")
                // Tab: photo ↔ video; in Window mode it picks the next window (Shift+Tab: previous), V switches.
                else if (k === Qt.Key_Tab || k === Qt.Key_Backtab) {
                    if (Capture.mode === "window") Capture.nextWindow(k === Qt.Key_Backtab || shift ? -1 : 1)
                    else Capture.kind = Capture.kind === "photo" ? "video" : "photo"
                }
                else if (k === Qt.Key_V) Capture.kind = Capture.kind === "photo" ? "video" : "photo"
                else if (k === Qt.Key_D) Capture.cycleDelay()
                else if (k === Qt.Key_O && Capture.kind === "photo") Capture.cycleOutput()
                else if (k === Qt.Key_M && Capture.kind === "video") Capture.mic = !Capture.mic
                else if (k === Qt.Key_A && Capture.kind === "video") Capture.desktopAudio = !Capture.desktopAudio
                else if (k === Qt.Key_C && Capture.kind === "video") Capture.cursor = !Capture.cursor
                else if (k === Qt.Key_F && Capture.kind === "video") Capture.cycleFormat()
                else return
                e.accepted = true
            }

            // --- Toolbar: bottom centre unless that would cover the target, then the middle, then the top
            // ("it sits on the free side of the screen so it never covers what you capture").
            Toolbar {
                id: toolbar
                visible: !root.picker && rise > 0
                // While a selection is being drawn the toolbar stays put; it moves once the drag ends.
                property var held: null
                readonly property var avoid: pointer.active ? held : root.hole
                // Candidates in order: bottom centre, middle, top, then centred in the free band left or right of
                // the target. The first that stays on screen and keeps 6 px off the target wins.
                readonly property point place: {
                    const a = avoid, m = Theme.px(6), W = parent.width, H = parent.height, w = width, h = height
                    const hits = (x, y) => a && a.x < x + w + m && a.x + a.w > x - m && a.y < y + h + m && a.y + a.h > y - m
                    const cx = (W - w) / 2, mid = (H - h) / 2
                    const opts = [[cx, H - Theme.px(56) - h], [cx, mid], [cx, Theme.px(60)]]
                    if (a) {
                        opts.push([(a.x - w) / 2, mid])
                        opts.push([a.x + a.w + (W - a.x - a.w - w) / 2, mid])
                    }
                    const o = opts.find(p => p[0] >= 0 && p[0] + w <= W && !hits(p[0], p[1])) ?? opts[0]
                    return Qt.point(Math.round(o[0]), Math.round(o[1]))
                }
                property real placeX: place.x
                property real placeY: place.y
                Behavior on placeX { enabled: toolbar.rise >= 1; NumberAnimation { duration: Motion.push; easing.type: Motion.easeOpen; easing.overshoot: Motion.overshoot } }
                Behavior on placeY { enabled: toolbar.rise >= 1; NumberAnimation { duration: Motion.push; easing.type: Motion.easeOpen; easing.overshoot: Motion.overshoot } }
                x: placeX
                y: placeY + (1 - rise) * Theme.px(60)
                opacity: Math.min(1, rise * 1.5)

                // Rises after the dim (OutBack); sinks away on capture.
                property real rise: 0
                readonly property bool up: root.phase === "open" && !root.picker
                onUpChanged: {
                    riseAnim.stop()
                    riseAnim.to = up ? 1 : 0
                    riseAnim.duration = up ? Motion.open(Motion.toolbarRise) : Motion.close(Motion.toolbarRise)
                    riseAnim.easing.type = up ? Motion.easeOpen : Motion.easeClose
                    riseDelay.interval = up && !Motion.reduced ? Motion.captureDim / 2 : 0
                    riseDelay.restart()
                }
                Timer { id: riseDelay; onTriggered: riseAnim.restart() }
                NumberAnimation { id: riseAnim; target: toolbar; property: "rise"; easing.overshoot: Motion.overshoot }
            }

            // --- Region: size readout above the selection: "624 × 389 at 1104, 154" (physical px).
            GlassRect {
                id: sizePill
                variant: "pill"
                visible: !root.picker && Capture.mode === "region" && root.phase === "open" && root.hole !== null
                readonly property real above: (root.hole?.y ?? 0) - Theme.px(12) - height
                x: Math.min(parent.width - width - Theme.px(8), root.hole?.x ?? 0)
                y: above >= Theme.px(8) ? above : (root.hole?.y ?? 0) + Theme.px(12)
                width: sizeRow.implicitWidth + Theme.px(20)
                height: Theme.px(28)
                Row {
                    id: sizeRow
                    anchors.centerIn: parent
                    spacing: Theme.px(8)
                    Text {
                        text: `${Capture.selection.w} × ${Capture.selection.h}`
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.px(12)
                        color: Theme.text
                    }
                    Text {
                        text: `at ${Capture.selection.x}, ${Capture.selection.y}`
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.px(12)
                        color: Theme.textFaint
                    }
                }
            }

            // --- Window: "Discord 847 × 423 [Tab] next window" over the target's top edge.
            GlassRect {
                id: windowPill
                variant: "pill"
                visible: !root.picker && Capture.mode === "window" && root.phase === "open" && Capture.target !== null
                readonly property real above: (root.hole?.y ?? 0) - Theme.px(12) - height
                x: Math.max(Theme.px(8), Math.min(parent.width - width - Theme.px(8), (root.hole?.x ?? 0) + ((root.hole?.w ?? 0) - width) / 2))
                y: above >= Theme.px(56) ? above : (root.hole?.y ?? 0) + Theme.px(12)
                width: windowRow.implicitWidth + Theme.px(24)
                height: Theme.px(32)
                Row {
                    id: windowRow
                    anchors.centerIn: parent
                    spacing: Theme.px(9)
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Capture.target ? Capture.appName(Capture.target) : ""
                        font.family: Theme.font
                        font.pixelSize: Theme.px(12.5)
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Capture.target ? `${Capture.target.w} × ${Capture.target.h}` : ""
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.px(12.5)
                        color: Theme.textMuted
                    }
                    KeyHint {
                        id: tabHint
                        anchors.verticalCenter: parent.verticalCenter
                        key: "Tab"
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: tabHint.visible
                        opacity: tabHint.opacity
                        text: "next window"
                        font.family: Theme.font
                        font.pixelSize: Theme.px(12.5)
                        color: Theme.textMuted
                    }
                }
            }

            // --- Colour picker chip under its loupe: swatch, the value, and the next format below it.
            GlassRect {
                id: chip
                variant: "popover"
                visible: root.picker && root.phase === "open"
                radius: Theme.px(16)
                x: Math.min(parent.width - width - Theme.px(8), pickLoupe.x - Theme.px(10))
                y: pickLoupe.y + pickLoupe.height + Theme.px(10)
                width: chipRow.implicitWidth + Theme.px(24)
                height: chipRow.implicitHeight + Theme.px(20)
                Row {
                    id: chipRow
                    anchors.centerIn: parent
                    spacing: Theme.px(10)
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.px(30)
                        height: width
                        radius: Theme.px(9)
                        color: Capture.pickColor
                        border.width: 1
                        border.color: Theme.white(0.4)
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            text: Capture.pickText
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.px(13)
                            font.weight: Font.Medium
                            color: Theme.text
                        }
                        Text {
                            readonly property var c: Capture.pickColor
                            text: Capture.pickFormat === "hex" ? `rgb(${Math.round(c.r * 255)} ${Math.round(c.g * 255)} ${Math.round(c.b * 255)})`
                                : Capture.pickFormat === "rgb" ? `hsl(${Math.round(Math.max(0, c.hslHue) * 360)} ${Math.round(c.hslSaturation * 100)}% ${Math.round(c.hslLightness * 100)}%)`
                                : Capture.hex(c)
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.px(10.5)
                            color: Theme.textMuted
                        }
                        Row {
                            spacing: Theme.px(6)
                            topPadding: Theme.px(4)
                            visible: KeyHints.held
                            KeyHint { key: "Enter" }
                            KeyHint { key: "Tab" }
                        }
                    }
                }
            }

            // --- Countdown (24): glass circle, Outfit number, red ring draining each second.
            Item {
                id: countdown
                visible: root.phase === "countdown"
                anchors.centerIn: parent
                width: Theme.px(132)
                height: width

                GlassRect {
                    variant: "pill"
                    anchors.centerIn: parent
                    width: Theme.px(120)
                    height: width
                    Text {
                        anchors.centerIn: parent
                        text: Capture.countdown
                        font.family: Theme.fontClock
                        font.weight: Font.DemiBold
                        font.pixelSize: Theme.px(64)
                        color: Theme.text
                    }
                }
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: Theme.error
                        strokeWidth: Theme.px(3)
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        PathAngleArc {
                            centerX: countdown.width / 2
                            centerY: countdown.height / 2
                            radiusX: countdown.width / 2 - Theme.px(1.5)
                            radiusY: radiusX
                            startAngle: -90
                            sweepAngle: 360 * (1 - drain.p)
                        }
                    }
                }
                // Restarts with each number.
                QtObject {
                    id: drain
                    property real p: 0
                }
                NumberAnimation { id: drainAnim; target: drain; property: "p"; from: 0; to: 1; duration: Motion.countdownTick }
                Connections {
                    target: Capture
                    function onCountdownChanged() { if (Capture.countdown > 0) drainAnim.restart() }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height + Theme.px(10)
                    text: Capture.countdownLabel + " · Esc cancels"
                    font.family: Theme.font
                    font.pixelSize: Theme.px(12)
                    color: Theme.text
                    style: Text.Raised
                    styleColor: Qt.rgba(0, 0, 0, 0.35)
                }
            }
        }
    }
}
