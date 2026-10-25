import QtQuick
import qs.services
import qs.components

// OSDs (DESIGN.md §2 "OSDs", 03-MotionPills lane 4): 290 × 46, radius 23, under the clock. The first press
// drips a droplet out of the clock that springs into the OSD; further presses only move the fill
// (120 ms per step); 1.2 s after the last press it is pulled back up into the clock.
// Volume (accent fill, grey when muted), brightness (tertiary fill), keyboard layout.
Item {
    id: root

    required property Item clock

    // Shape progress: 0 = the clock itself, 0.5 = a droplet just under it, 1 = the OSD. Keyframes from
    // MotionPills.dc.html .osd (8 %–24 % of the loop), relative to the clock; OutBack overshoots past 1.
    property real p: 0
    property real fade: 1   // reduced motion fades instead of dropping
    visible: p > 0 && fade > 0
    opacity: Capture.hiding ? 0 : 1   // never in a capture (§4)

    readonly property real shapeWidth: Motion.frames(p, [[0, clock.width], [0.5, Theme.px(100)], [1, Theme.px(290)]])
    readonly property real shapeHeight: Theme.px(Motion.frames(p, [[0, 38], [0.5, 40], [1, 46]]))
    readonly property real shapeTop: Theme.px(Motion.frames(p, [[0, 0], [0.5, 24], [1, 76]]))
    function clamp(v: real): real { return Math.max(0, Math.min(1, v)) }

    Connections {
        target: Osd
        function onShownChanged() {
            if (Motion.reduced) {
                anim.stop()
                if (Osd.shown && root.p < 1) root.fade = 0   // fade in from nothing, not from the last shape
                root.p = 1
                fadeAnim.to = Osd.shown ? 1 : 0
                fadeAnim.restart()
            } else {
                fadeAnim.stop()
                root.fade = 1
                anim.to = Osd.shown ? 1 : 0
                anim.duration = Osd.shown ? Motion.osdIn : Motion.osdOut
                anim.easing.type = Osd.shown ? Motion.easeOpen : Motion.easeClose
                anim.restart()
            }
        }
    }
    NumberAnimation { id: anim; target: root; property: "p"; easing.overshoot: Motion.overshoot }
    NumberAnimation {
        id: fadeAnim
        target: root
        property: "fade"
        duration: Motion.reducedFade
        onFinished: if (root.fade === 0) root.p = 0
    }

    GlassRect {
        id: body
        x: root.clock.x + (root.clock.width - width) / 2
        y: root.clock.y + root.shapeTop
        width: root.shapeWidth
        height: root.shapeHeight
        opacity: root.fade * root.clamp(Motion.frames(root.p, [[0, 0], [0.19, 1]]))

        Item {
            anchors.fill: parent
            anchors.margins: 1
            clip: true

            Item {
                id: content
                anchors.centerIn: parent
                width: Theme.px(290 - 2 * 16)
                height: parent.height
                opacity: root.clamp(Motion.frames(root.p, [[0.63, 0], [1, 1]]))

                Meter {
                    kind: "volume"
                    icon: Audio.muted || Audio.percent === 0 ? "volume-x" : Audio.percent < 50 ? "volume-1" : "volume-2"
                    value: Audio.percent
                    fill: Audio.muted ? Theme.textFaint : Theme.accent
                }
                Meter {
                    kind: "brightness"
                    icon: "sun"
                    value: Brightness.percent
                    fill: Theme.secondary
                }
                // Layout: keyboard icon + layout name. (No bind switches it, so no key hint.)
                Row {
                    anchors.fill: parent
                    spacing: Theme.px(12)
                    opacity: Osd.kind === "layout" ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Motion.osdStep } }
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "keyboard"
                        size: Theme.px(17)
                    }
                    BarText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - x
                        text: Keyboard.name
                        font.weight: Font.Medium
                    }
                }
            }
        }
    }

    // Icon, track with fill, value in mono.
    component Meter: Row {
        id: meter
        property string kind
        property string icon
        property int value
        property color fill
        anchors.fill: parent
        spacing: Theme.px(12)
        opacity: Osd.kind === kind ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Motion.osdStep } }

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: meter.icon
            size: Theme.px(17)
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: meter.width - x - number.width - meter.spacing
            height: Theme.px(6)
            radius: height / 2
            color: Theme.white(0.14)
            Rectangle {
                width: parent.width * Math.max(0, Math.min(100, meter.value)) / 100
                height: parent.height
                radius: parent.radius
                color: meter.fill
                Behavior on width { NumberAnimation { duration: Motion.osdStep; easing.type: Motion.easeSmall } }
                Behavior on color { ColorAnimation { duration: Motion.micro; easing.type: Motion.easeMicro } }
            }
        }
        Text {
            id: number
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.px(22)
            horizontalAlignment: Text.AlignRight
            text: meter.value
            color: Theme.text
            font.family: Theme.fontMono
            font.pixelSize: Theme.px(12)
        }
    }
}
