import QtQuick
import qs.services

// A pill popover (DESIGN.md §3.1) that grows out of its pill (§5.2 "Grow from the pill", the same shape
// path as 01-MotionControl at popover scale): a droplet the pill's size appears on top of it, stretches
// down, a short neck forms, then it springs into the popover. Content fades in and rises 10 px once the
// shape is 60 % done. Closing runs the path backwards in ≈ 60 % of the time (InCubic).
//
// Fills the bar window; the popover sits 10 px under `pill`, centred under `target` (the pill, or a part
// of it like a workspace dot) and kept 12 px inside the screen. Content goes into a Column, `width` wide.
FocusScope {
    id: root

    required property Item pill
    property Item target: pill
    // Open while Shell.popover is `name` on this bar's screen.
    property string name
    property string screenName
    property bool shown: name !== "" && Shell.popover === name
                         && (Shell.popoverScreen === "" || Shell.popoverScreen === screenName)
    property real contentWidth: Theme.px(290)
    property real padding: Theme.px(10)
    default property alias content: column.data
    readonly property alias body: glass
    readonly property bool opened: p === 1
    readonly property bool hovered: hover.hovered

    anchors.fill: parent

    // Shape progress: 0 = the pill itself, 1 = the popover.
    property real p: 0
    property real fade: 1   // reduced motion fades instead of growing
    visible: p > 0 && fade > 0

    // Start shape (the pill) and final centre, in this item's coordinates; taken when it opens (pills don't
    // move while their popover is open) and when the target changes (the peek follows the hovered dot).
    property rect start: Qt.rect(0, 0, 0, 0)
    property real centre: 0
    Behavior on centre {
        enabled: root.opened && !Motion.reduced
        NumberAnimation { duration: Motion.small; easing.type: Motion.easeSmall }
    }
    function measure() {
        const s = pill.mapToItem(root, 0, 0, pill.width, pill.height)
        start = Qt.rect(s.x, s.y, s.width, s.height)
        const t = target.mapToItem(root, 0, 0, target.width, target.height)
        centre = t.x + t.width / 2
    }
    onTargetChanged: if (visible) measure()

    readonly property real inset: Theme.px(12)
    readonly property real finalWidth: contentWidth
    property real finalHeight: column.implicitHeight + 2 * padding
    Behavior on finalHeight {
        enabled: root.opened && !Motion.reduced
        NumberAnimation { duration: Motion.small; easing.type: Motion.easeSmall }
    }
    readonly property real finalX: Math.max(inset, Math.min(width - inset - finalWidth, centre - finalWidth / 2))
    readonly property real finalY: start.y + start.height + Theme.px(10)

    // Keyframes: 0 pill → 0.3 droplet still over the pill (a bit narrower, 2.5× taller) → 0.75 a few px past
    // the popover → 1 popover.
    readonly property real sc: start.x + start.width / 2
    readonly property real shapeCx: Motion.frames(p, [[0, sc], [0.3, sc], [0.75, finalX + finalWidth / 2], [1, finalX + finalWidth / 2]])
    readonly property real shapeW: Motion.frames(p, [[0, start.width], [0.3, Math.max(start.height, start.width - Theme.px(16))], [0.75, finalWidth + Theme.px(8)], [1, finalWidth]])
    readonly property real shapeY: Motion.frames(p, [[0, start.y], [0.3, start.y], [0.75, finalY - Theme.px(3)], [1, finalY]])
    readonly property real shapeH: Motion.frames(p, [[0, start.height], [0.3, start.height * 2.5], [0.75, finalHeight + Theme.px(8)], [1, finalHeight]])
    readonly property real shapeR: Motion.frames(p, [[0, start.height / 2], [0.3, Theme.px(30)], [0.75, Theme.px(26)], [1, Theme.px(22)]])
    function clamp(v: real): real { return Math.max(0, Math.min(1, v)) }

    onShownChanged: {
        if (shown) {
            measure()
            forceActiveFocus()
        }
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
            anim.duration = shown ? Motion.small : Motion.close(Motion.small)
            anim.easing.type = shown ? Motion.easeSmall : Motion.easeClose
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

    Keys.onEscapePressed: Shell.closePopover()

    // The neck between pill and droplet while they come apart.
    Rectangle {
        readonly property real grow: Motion.frames(root.p, [[0.3, 0.3], [0.5, 1], [0.9, 0.6]])
        x: root.sc - width / 2
        y: root.start.y + root.start.height - Theme.px(12)
        width: Math.min(Theme.px(80), root.start.width * 0.45, root.finalWidth * 0.4)
        height: Math.max(0, root.finalY - y + Theme.px(12)) * grow
        radius: Math.min(width, height) / 2
        color: Theme.alpha(glass.fillColor, 0.55)
        opacity: root.fade * root.clamp(Motion.frames(root.p, [[0.3, 0], [0.5, 1], [0.9, 0]]))
        visible: opacity > 0
    }

    GlassRect {
        id: glass
        variant: "popover"
        x: root.shapeCx - width / 2
        y: root.shapeY
        width: root.shapeW
        height: root.shapeH
        radius: root.shapeR
        opacity: root.fade * root.clamp(Motion.frames(root.p, [[0, 0], [0.08, 1]]))
        HoverHandler { id: hover }
        // Presses on the popover itself (not on a button) stop here, so they don't close it as "outside".
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        Item {
            anchors.fill: parent
            anchors.margins: 1
            clip: root.p < 1

            Column {
                id: column
                readonly property real reveal: root.clamp(Motion.frames(root.p, [[0.6, 0], [1, 1]]))
                // Laid out at the final size from the start, so nothing reflows while the shape grows.
                x: root.padding - 1 + (root.finalX - glass.x)
                y: root.padding - 1 + (root.finalY - glass.y) + Theme.px(10) * (1 - reveal)
                width: root.finalWidth - 2 * root.padding
                opacity: reveal
            }
        }
    }
}
