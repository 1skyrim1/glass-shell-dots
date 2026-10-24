import QtQuick
import qs.services

// A panel or sheet that grows out of its pill (DESIGN.md §5.2 "Grow from the pill", 02-MotionLauncher):
// a droplet the pill's size appears on top of it, hangs down under it with a short neck, then springs
// into the sheet (a little past it, then back). Content fades in and rises 10 px once the shape is 60 %
// done. Closing sucks it back into the pill (content first fades out moving up 6 px), InCubic.
// Reduced motion: a 150 ms fade.
//
// Fills the bar window. The final shape is finalX / finalY / finalWidth, and as tall as the content; while
// open, changes to any of them morph the sheet (launcher ↔ cheatsheet, content growing).
FocusScope {
    id: root

    required property Item pill
    property bool shown: false
    property int openMs: Motion.launcherIn
    property int closeMs: Motion.launcherOut
    property real finalWidth: Theme.px(660)
    property real finalX: Math.round((width - finalWidth) / 2)
    property real finalY: Theme.px(150)
    property real finalRadius: Theme.px(28)
    property real padding: Theme.px(14)
    default property alias content: column.data
    readonly property alias body: glass
    readonly property bool opened: p === 1 && fade === 1
    // How far the desktop is dimmed (0…1), for the dim layer under the pills.
    readonly property real dimLevel: fade * clamp(Motion.frames(p, [[0.05, 0], [0.8, 1]]))

    anchors.fill: parent

    // Shape progress: 0 = the pill itself, 1 = the sheet.
    property real p: 0
    property real fade: 1   // reduced motion fades instead of growing
    property bool closing: false
    visible: p > 0 && fade > 0

    property rect start: Qt.rect(0, 0, 0, 0)
    function measure() {
        const s = pill.mapToItem(root, 0, 0, pill.width, pill.height)
        start = Qt.rect(s.x, s.y, s.width, s.height)
    }

    // Morphs while open (the sheet resizes in place).
    property real targetX: finalX
    property real targetY: finalY
    property real targetW: finalWidth
    property real targetR: finalRadius
    property real targetH: column.implicitHeight + 2 * padding
    Behavior on targetX { enabled: root.opened && !Motion.reduced; NumberAnimation { duration: Motion.sheetMorph; easing.type: Easing.OutCubic } }
    Behavior on targetY { enabled: root.opened && !Motion.reduced; NumberAnimation { duration: Motion.sheetMorph; easing.type: Easing.OutCubic } }
    Behavior on targetW { enabled: root.opened && !Motion.reduced; NumberAnimation { duration: Motion.sheetMorph; easing.type: Easing.OutCubic } }
    Behavior on targetR { enabled: root.opened && !Motion.reduced; NumberAnimation { duration: Motion.sheetMorph; easing.type: Easing.OutCubic } }
    Behavior on targetH { enabled: root.opened && !Motion.reduced; NumberAnimation { duration: Motion.sheetMorph; easing.type: Easing.OutCubic } }

    // Keyframes from MotionLauncher.dc.html .la (5 % pill → 9 % droplet → 15 % overshoot → 18 % sheet),
    // relative to the pill: droplet 112 × 70 hanging 26 px below the pill's top, overshoot 8 px wider and
    // 6 px higher on each side.
    readonly property real sc: start.x + start.width / 2
    readonly property real fc: targetX + targetW / 2
    readonly property real shapeCx: Motion.frames(p, [[0, sc], [0.31, sc], [0.77, fc], [1, fc]])
    readonly property real shapeW: Motion.frames(p, [[0, start.width], [0.31, Theme.px(112)], [0.77, targetW + Theme.px(16)], [1, targetW]])
    readonly property real shapeY: Motion.frames(p, [[0, start.y], [0.31, start.y + Theme.px(26)], [0.77, targetY - Theme.px(6)], [1, targetY]])
    readonly property real shapeH: Motion.frames(p, [[0, start.height], [0.31, Theme.px(70)], [0.77, targetH + Theme.px(16)], [1, targetH]])
    readonly property real shapeR: Motion.frames(p, [[0, start.height / 2], [0.31, Theme.px(35)], [0.77, targetR + Theme.px(4)], [1, targetR]])
    function clamp(v: real): real { return Math.max(0, Math.min(1, v)) }

    onShownChanged: {
        if (shown) {
            measure()
            forceActiveFocus()
        }
        closing = !shown
        if (Motion.reduced) {
            anim.stop()
            if (shown && p < 1) fade = 0   // fade in from nothing, not from the last shape
            p = 1
            fadeAnim.to = shown ? 1 : 0
            fadeAnim.restart()
        } else {
            fadeAnim.stop()
            fade = 1
            anim.to = shown ? 1 : 0
            anim.duration = shown ? openMs : closeMs
            anim.easing.type = shown ? Easing.OutCubic : Motion.easeClose
            anim.restart()
        }
    }
    NumberAnimation { id: anim; target: root; property: "p" }
    NumberAnimation {
        id: fadeAnim
        target: root
        property: "fade"
        duration: Motion.reducedFade
        onFinished: if (root.fade === 0) root.p = 0
    }

    // The neck between the pill and the droplet while they come apart.
    Rectangle {
        readonly property real grow: Motion.frames(root.p, [[0.1, 0], [0.31, 1], [0.6, 0.5]])
        x: root.sc - width / 2
        y: root.start.y + root.start.height - Theme.px(10)
        width: Math.min(Theme.px(56), root.start.width * 0.4)
        height: Math.max(0, root.shapeY - y + Theme.px(14)) * grow
        radius: Math.min(width, height) / 2
        color: Theme.alpha(glass.fillColor, 0.55)
        opacity: root.fade * root.clamp(Motion.frames(root.p, [[0.1, 0], [0.25, 1], [0.6, 0]]))
        visible: opacity > 0 && root.p < 0.7
    }

    GlassRect {
        id: glass
        variant: "panel"
        x: root.shapeCx - width / 2
        y: root.shapeY
        width: root.shapeW
        height: root.shapeH
        radius: root.shapeR
        opacity: root.fade * root.clamp(Motion.frames(root.p, [[0, 0], [0.06, 1]]))
        // Presses on the sheet itself stop here, so they don't close it as "outside".
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        Item {
            anchors.fill: parent
            anchors.margins: 1
            clip: true   // also while open: content can be ahead of the shape when the sheet morphs

            Column {
                id: column
                readonly property real reveal: root.clamp(Motion.frames(root.p, [[0.6, 0], [1, 1]]))
                // Laid out at the final size from the start, so nothing reflows while the shape grows.
                x: root.padding - 1 + (root.targetX - glass.x)
                y: root.padding - 1 + (root.targetY - glass.y) + Theme.px(root.closing ? -6 : 10) * (1 - reveal)
                width: root.targetW - 2 * root.padding
                opacity: reveal
            }
        }
    }
}
