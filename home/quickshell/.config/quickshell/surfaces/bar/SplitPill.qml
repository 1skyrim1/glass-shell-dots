import QtQuick
import qs.services
import qs.components

// A temporary pill that buds off the clock (DESIGN.md §2 "Temporary pills", §5.2 "Split / merge",
// 03-MotionPills lane 3): a droplet bulges out of the clock's end, a thin neck stretches and snaps, the
// droplet takes its colour and widens to fit its content. Hiding runs the same path backwards and merges
// it into the clock. Recording and sharing bud off the right end, key modes off the left.
// Lives next to the clock in the same parent, stacked below it so the droplet starts hidden inside it.
Item {
    id: root

    required property Item clock
    property string side: "right"
    property bool shown: false
    property string tone: "accent"
    property real padLeft: Theme.px(14)
    property real padRight: Theme.px(14)
    property alias spacing: row.spacing
    default property alias content: row.data
    readonly property alias pill: drop
    signal clicked()

    // Shape progress: 0 = inside the clock, 1 = split off. The keyframes below are MotionPills.dc.html's
    // .rec / .neck / .rtxt between 8 % and 30 % of the loop, in design px measured outward from the clock's
    // edge (negative = still inside the clock).
    property real p: 0
    property real fade: 1   // reduced motion fades instead of splitting
    visible: p > 0 && fade > 0

    property real full: padLeft + row.implicitWidth + padRight
    Behavior on full { NumberAnimation { duration: Motion.pillWidth; easing.type: Motion.easeSmall } }
    readonly property real dropOut: Theme.px(Motion.frames(p, [[0, -42], [0.18, -38], [0.64, 14], [1, 8]]))
    readonly property real dropWidth: Motion.frames(p, [[0, Theme.px(38)], [0.64, Theme.px(38)], [1, full]])
    readonly property real neckOut: Theme.px(Motion.frames(p, [[0.23, -22], [0.45, -22], [0.73, -8], [0.91, -2]]))
    readonly property real neckWidth: Math.max(0, Theme.px(Motion.frames(p, [[0.23, 0], [0.45, 40], [0.73, 20], [0.91, 0]])))
    function clamp(v: real): real { return Math.max(0, Math.min(1, v)) }

    // x of a shape that starts `out` px beyond the clock's edge and is `w` wide.
    function outward(out: real, w: real): real {
        return side === "right" ? clock.x + clock.width + out : clock.x - out - w
    }

    onShownChanged: {
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
            anim.duration = shown ? Motion.splitIn : Motion.splitOut
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

    // The neck: a thin glass bridge that stretches between clock and droplet, then snaps.
    Rectangle {
        x: root.outward(root.neckOut, width)
        y: root.clock.y + (root.clock.height - height) / 2
        width: root.neckWidth
        height: Theme.px(14)
        radius: height / 2
        color: Theme.alpha(drop.fillColor, 0.55)
        opacity: root.clamp(Motion.frames(root.p, [[0.23, 0], [0.45, 1], [0.73, 0.8], [0.91, 0]]))
        visible: width > 0
    }

    Pill {
        id: drop
        x: root.outward(root.dropOut, width)
        y: root.clock.y
        implicitWidth: root.dropWidth
        animateWidth: false   // the split drives the width
        opacity: root.fade * root.clamp(Motion.frames(root.p, [[0, 0], [0.18, 1]]))
        tone: root.tone
        toneMix: root.clamp(Motion.frames(root.p, [[0.18, 0], [0.64, 1]]))
        smoothColor: false
        onClicked: root.clicked()

        Item {
            anchors.fill: parent
            anchors.margins: 1
            clip: true
            Row {
                id: row
                x: root.padLeft - 1
                anchors.verticalCenter: parent.verticalCenter
                opacity: root.clamp(Motion.frames(root.p, [[0.8, 0], [1, 1]]))
            }
        }
    }
}
