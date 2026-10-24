import QtQuick
import Quickshell
import qs.services
import qs.components

// Toasts (DESIGN.md §3.5, 18-Notifications, 19-NotifStates "Toast stack"): 340 px under the bell,
// right-aligned with the bar. Up to three; the newest in front, older ones tucked behind it (scale 95 % /
// 90 %, 80 % / 55 %, only their lower edge showing). Hovering the stack fans them out into a column and
// pauses every timer (04-MotionOverlays "Toast stack", 240 ms). Click = open, right-click = put it away.
//
// A new toast comes out of the bell (02-MotionLauncher toBlob): the bell widens along the top, drops a bit
// past the toast and springs back into it; the content fades up 8 px once the shape is 60 % done. Leaving
// (timer ran out, opened, dismissed) it shrinks straight back into the bell, content first, and the bell
// shows its dot if it's still unread. Reduced motion: a 150 ms fade.
//
// This item is the area the toasts rest in (the bar window's input mask uses it); the drip starts above it.
Item {
    id: root

    required property Item bell
    property real edge: parent.width - Theme.px(12)   // right edge, the bar's inset

    x: edge - width
    y: Theme.px(58)
    width: Theme.px(340)
    // Fanned: down to the last toast; tucked: the front toast plus the lips of the ones behind.
    height: {
        const n = repeater.count
        if (n === 0) return 0
        const last = repeater.itemAt(n - 1), front = repeater.itemAt(0)
        if (!last || !front) return 0
        return Math.max(front.restH, fan * (last.fanY + last.restH) + (1 - fan) * (front.restH + Theme.px(n > 1 ? 30 : 0)))
    }
    // Fanned out: each toast under the one in front of it, 8 px apart.
    readonly property var fanYs: {
        const ys = []
        let y = 0
        for (let i = 0; i < repeater.count; i++) {
            ys.push(y)
            y += (repeater.itemAt(i)?.ownH ?? 0) + Theme.px(8)
        }
        return ys
    }

    // Stays fanned for a moment when the pointer crosses a gap.
    readonly property bool hovered: hover.hovered || grace.running
    HoverHandler {
        id: hover
        onHoveredChanged: if (!hovered) grace.restart()
    }
    Timer { id: grace; interval: 150 }
    property real fan: hovered && repeater.count > 1 ? 1 : 0
    Behavior on fan { NumberAnimation { duration: Motion.fixed(Motion.toastFan); easing.type: Easing.OutCubic } }

    // The bell, in this item's coordinates (taken when a toast starts to drip).
    function bellRect(): rect {
        const b = bell.mapToItem(root, 0, 0, bell.width, bell.height)
        return Qt.rect(b.x, b.y, b.width, b.height)
    }

    Repeater {
        id: repeater
        model: ScriptModel { values: Notifs.toasts }

        Item {
            id: toast

            required property var modelData
            required property int index
            readonly property var entry: modelData

            // Drip progress (0 = the bell, 1 = resting); leaving runs it back to 0 in a straight line.
            property real p: 0
            property real fade: 1
            property bool leaving: false
            property rect bellAt: Qt.rect(0, 0, 0, 0)

            // Timer
            readonly property int total: entry.critical ? 0 : entry.actions.length > 0 ? Motion.toastLong : Motion.toastShort
            property real remaining: 1
            NumberAnimation {
                id: timer
                target: toast
                property: "remaining"
                from: 1
                to: 0
                duration: Math.max(1, toast.total)
                paused: running && root.hovered
                onFinished: Notifs.leave(toast.entry)
            }

            // Place in the stack: 0 = front. Animates when a toast in front of it arrives or leaves.
            property real depth: index
            Behavior on depth { NumberAnimation { duration: Motion.fixed(Motion.toastFan); easing.type: Easing.OutCubic } }
            readonly property real tuck: Math.min(depth, 2)

            readonly property real ownH: content.implicitHeight + 2 * pad
            readonly property real pad: Theme.px(12)
            readonly property Item front: repeater.count > 0 ? repeater.itemAt(0) : null
            readonly property real fanY: root.fanYs[index] ?? 0
            // Tucked behind the front one: as tall as it, pushed down 18 / 30 px and scaled from the top
            // centre, so only a lip shows.
            readonly property real tuckY: Theme.px(Motion.frames(tuck, [[0, 0], [1, 18], [2, 30]]))
            readonly property real tuckH: front && front !== toast ? front.ownH : ownH
            readonly property real restY: root.fan * fanY + (1 - root.fan) * tuckY
            readonly property real restH: root.fan * ownH + (1 - root.fan) * (ownH + (tuckH - ownH) * Math.min(1, tuck))
            readonly property real restScale: 1 - (1 - root.fan) * 0.05 * tuck
            readonly property real restOpacity: root.fan + (1 - root.fan) * Motion.frames(tuck, [[0, 1], [1, 0.8], [2, 0.55]])
            readonly property real contentOpacity: root.fan + (1 - root.fan) * Math.max(0, 1 - tuck)

            // Shape: keyframes from the bell (p < 1) or a straight line back to it (leaving).
            readonly property real bw: bellAt.width
            readonly property real shapeX: leaving ? lerp(bellAt.x, 0, p)
                : Motion.frames(p, [[0, bellAt.x], [0.33, bellAt.x + bw - Theme.px(208)], [0.75, -Theme.px(4)], [1, 0]])
            readonly property real shapeY: leaving ? lerp(bellAt.y, restY, p)
                : Motion.frames(p, [[0, bellAt.y], [0.33, bellAt.y], [0.75, restY - Theme.px(2)], [1, restY]])
            readonly property real shapeW: leaving ? lerp(bw, root.width, p)
                : Motion.frames(p, [[0, bw], [0.33, Theme.px(208)], [0.75, root.width + Theme.px(8)], [1, root.width]])
            readonly property real shapeH: leaving ? lerp(bellAt.height, restH, p)
                : Motion.frames(p, [[0, bellAt.height], [0.33, bellAt.height], [0.75, restH + Theme.px(6)], [1, restH]])
            readonly property real shapeR: leaving ? lerp(bellAt.height / 2, Theme.px(20), p)
                : Motion.frames(p, [[0, bellAt.height / 2], [0.33, bellAt.height / 2], [0.75, Theme.px(24)], [1, Theme.px(20)]])
            function lerp(a: real, b: real, t: real): real { return a + (b - a) * t }
            readonly property real reveal: Math.max(0, Math.min(1, leaving ? Motion.frames(p, [[0.4, 0], [1, 1]])
                                                                            : Motion.frames(p, [[0.58, 0], [1, 1]])))

            function enter() {
                bellAt = root.bellRect()
                if (Motion.reduced) {
                    p = 1
                    fade = 0
                    fadeAnim.to = 1
                    fadeAnim.restart()
                } else {
                    anim.to = 1
                    anim.duration = Motion.toastIn
                    anim.easing.type = Easing.Linear   // the keyframes ease each step
                    anim.restart()
                }
                if (total > 0) timer.restart()
            }
            function exit() {
                timer.stop()
                bellAt = root.bellRect()
                if (Motion.reduced) {
                    fadeAnim.to = 0
                    fadeAnim.restart()
                } else {
                    anim.stop()
                    leaving = true
                    anim.to = 0
                    anim.duration = Motion.toastOut
                    anim.easing.type = Motion.easeClose
                    anim.restart()
                }
            }
            Component.onCompleted: entry.leaving ? Notifs.toastDone(entry) : enter()
            readonly property bool wantsOut: entry.leaving
            onWantsOutChanged: if (wantsOut) exit()

            NumberAnimation {
                id: anim
                target: toast
                property: "p"
                onFinished: if (toast.p === 0) Notifs.toastDone(toast.entry)
            }
            NumberAnimation {
                id: fadeAnim
                target: toast
                property: "fade"
                duration: Motion.reducedFade
                onFinished: if (toast.fade === 0) Notifs.toastDone(toast.entry)
            }

            // Fronts on top; the drip of a new one goes over the others.
            z: 10 - index
            // Tucked toasts only show below the front one: the glass is see-through, and in one layer
            // Hyprland's blur can't hide what's behind the front toast.
            readonly property bool behind: index > 0 && front && !front.leaving
            readonly property real clipTop: behind ? front.shapeY + front.shapeH * front.restScale - Theme.px(2) - root.fan * Theme.px(400) : -Theme.px(400)
            Item {
                id: clipper
                x: -Theme.px(60)
                y: toast.clipTop
                width: root.width + Theme.px(120)
                height: Theme.px(1200)
                clip: true
                Item {
                    id: scaler
                    x: toast.shapeX - clipper.x
                    y: toast.shapeY - clipper.y
                    width: toast.shapeW
                    height: toast.shapeH
                    opacity: toast.fade * (toast.leaving ? 1 : Math.min(1, toast.p / 0.05)) * (toast.p >= 1 || toast.leaving ? toast.restOpacity : 1)
                    transform: Scale {
                        origin.x: scaler.width / 2
                        origin.y: 0
                        xScale: toast.restScale
                        yScale: toast.restScale
                    }

                    GlassRect {
                        anchors.fill: parent
                        radius: toast.shapeR
                        tone: toast.entry.critical ? "critical" : ""

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: e => e.button === Qt.RightButton ? Notifs.leave(toast.entry) : Notifs.open(toast.entry)
                        }

                        Item {
                            anchors.fill: parent
                            anchors.margins: 1
                            clip: true
                            Toast {
                                id: content
                                // Laid out at the resting size from the start, so nothing reflows while it drips.
                                x: toast.pad - 1 - toast.shapeX
                                y: toast.pad - 1 + Theme.px(8) * (1 - toast.reveal) * (toast.leaving ? 0 : 1)
                                width: root.width - 2 * toast.pad
                                entry: toast.entry
                                remaining: toast.remaining
                                timed: toast.total > 0
                                opacity: toast.reveal * toast.contentOpacity
                            }
                        }
                    }
                }
            }
        }
    }
}
