import QtQuick
import qs.services
import qs.components

// Media pill (DESIGN.md §2.2): only while something plays. 26 px accent-container circle with three
// equalizer bars + track title (max 110 px). It slides out from behind the workspace pill with a small
// overshoot and tucks back 10 s after playback stops (03-MotionPills lane 2).
// Click = media popover (Phase 3), scroll = previous / next track.
Pill {
    id: root

    required property Item anchor   // the workspace pill it slides out from behind
    property real gap: Theme.px(8)

    // 0 = tucked behind the workspace pill, 1 = out. OutBack on the way out gives the 4 px overshoot.
    property real slide: 0
    readonly property real fullWidth: Theme.px(6) + content.implicitWidth + Theme.px(13)

    x: anchor.x + anchor.width + gap - Theme.px(30) * (1 - slide)
    implicitWidth: Math.max(height, fullWidth * slide)
    opacity: Math.min(1, slide * 2.5)
    visible: slide > 0
    animateWidth: false   // the slide drives the width

    states: State {
        name: "out"
        when: Media.shown && Media.title !== ""
        PropertyChanges { root.slide: 1 }
    }
    transitions: [
        Transition {
            to: "out"
            NumberAnimation {
                property: "slide"
                duration: Motion.fixed(Motion.mediaIn)
                easing.type: Motion.easeOpen
                easing.overshoot: Motion.overshoot
            }
        },
        Transition {
            to: ""
            NumberAnimation { property: "slide"; duration: Motion.fixed(Motion.mediaOut); easing.type: Motion.easeClose }
        }
    ]

    onClicked: Shell.openPopover("media")   // TODO Phase 3: media popover
    onScrolled: step => step > 0 ? Media.next() : Media.previous()

    Item {
        anchors.fill: parent
        anchors.margins: 1
        clip: true

        Row {
            id: content
            x: Theme.px(6) - 1
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.px(8)

            // Equalizer: three bars bouncing between 4 and 12 px, out of phase; still while paused.
            Rectangle {
                width: Theme.px(26)
                height: width
                radius: width / 2
                color: Theme.accentContainer

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.px(2)
                    Repeater {
                        // Phase offsets (-0.3 s, -0.5 s of a 1.4 s loop) and the resting heights from Bar.dc.html.
                        model: [{ phase: 0, rest: 7 }, { phase: 0.21, rest: 11 }, { phase: 0.36, rest: 5 }]
                        Rectangle {
                            required property var modelData
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.px(2.5)
                            radius: Theme.px(1)
                            color: Theme.textOnContainer
                            height: Theme.px(Media.playing
                                ? 8 - 4 * Math.cos(2 * Math.PI * (root.eqPhase + modelData.phase))
                                : modelData.rest)
                        }
                    }
                }
            }

            BarText {
                anchors.verticalCenter: parent.verticalCenter
                text: Media.title
                font.pixelSize: Theme.px(12.5)
                font.weight: Font.Medium
                width: Math.min(implicitWidth, Theme.px(110))
            }
        }
    }

    property real eqPhase: 0
    NumberAnimation on eqPhase {
        from: 0
        to: 1
        duration: Motion.eqPeriod
        loops: Animation.Infinite
        running: Media.playing && root.visible && !Motion.reduced
    }
}
