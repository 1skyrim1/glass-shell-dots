import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import Quickshell.Services.Mpris
import qs.services
import qs.components

// Media popover (DESIGN.md §3.1, 10-Popovers "Media"): click the media pill. Cover, title, artist · player,
// seek bar with times, shuffle · previous · play/pause · next · repeat, and a chip per player when there
// are several. Keys: Space play/pause, ←/→ seek 5 s, Tab next player, Esc.
Popover {
    id: root

    name: "media"
    contentWidth: Theme.px(360)
    padding: Theme.px(14)

    readonly property MprisPlayer player: Media.player
    onPlayerChanged: if (!player) Shell.closePopoverIf("media")
    Binding { target: Media; property: "watching"; value: root.shown }

    function time(s: real): string {
        s = Math.max(0, Math.round(s))
        const h = Math.floor(s / 3600), m = Math.floor(s / 60) % 60, ss = String(s % 60).padStart(2, "0")
        return h > 0 ? `${h}:${String(m).padStart(2, "0")}:${ss}` : `${m}:${ss}`
    }

    Keys.onPressed: e => {
        if (e.key === Qt.Key_Space) Media.toggle()
        else if (e.key === Qt.Key_Left || e.key === Qt.Key_H) Media.seek(-5)
        else if (e.key === Qt.Key_Right || e.key === Qt.Key_L) Media.seek(5)
        else if (e.key === Qt.Key_Tab || e.key === Qt.Key_Backtab) Media.nextPlayer()
        else return
        e.accepted = true
    }

    // --- Cover 76 r14 with its own shadow, title 15/600, "artist · player".
    Row {
        width: parent.width
        spacing: Theme.px(14)

        Item {
            id: cover
            width: Theme.px(76)
            height: width
            RectangularShadow {
                anchors.fill: parent
                radius: Theme.px(14)
                offset.y: Theme.px(8)
                blur: Theme.px(20)
                color: Qt.rgba(0, 0, 0, 0.4)
            }
            ClippingRectangle {
                anchors.fill: parent
                radius: Theme.px(14)
                color: Theme.accentContainer
                Icon {
                    anchors.centerIn: parent
                    visible: art.status !== Image.Ready
                    name: "music"
                    size: Theme.px(28)
                    color: Theme.textOnContainer
                }
                Image {
                    id: art
                    anchors.fill: parent
                    source: root.player?.trackArtUrl ?? ""
                    sourceSize: Qt.size(width * 2, height * 2)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    smooth: true
                }
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - cover.width - parent.spacing
            spacing: Theme.px(2)
            BarText {
                width: parent.width
                text: root.player?.trackTitle || root.player?.identity || ""
                font.pixelSize: Theme.px(15)
                font.weight: Font.DemiBold
            }
            BarText {
                width: parent.width
                text: [root.player?.trackArtist, Media.appName(root.player)].filter(Boolean).join(" · ")
                font.pixelSize: Theme.px(12.5)
                color: Theme.textMuted
            }
        }
    }

    // --- Seek bar: 5 px track, light fill, 13 px knob. Click or drag to seek.
    Item {
        id: seek
        width: parent.width
        height: Theme.px(14 + 5) + Theme.px(4)   // 14 px gap above, knob overhang below
        readonly property real fraction: drag.pressed ? drag.fraction
            : Media.length > 0 ? Math.max(0, Math.min(1, Media.position / Media.length)) : 0

        Rectangle {
            id: track
            y: Theme.px(14)
            width: parent.width
            height: Theme.px(5)
            radius: height / 2
            color: Theme.white(0.14)
            Rectangle {
                width: Math.max(height, parent.width * seek.fraction)
                height: parent.height
                radius: parent.radius
                color: Theme.text
                visible: Media.length > 0
            }
            Rectangle {
                visible: Media.canSeek
                x: parent.width * seek.fraction - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.px(13) * (drag.pressed ? 1.15 : drag.containsMouse ? 1.08 : 1)
                height: width
                radius: width / 2
                color: Theme.white(1)
                Behavior on width { NumberAnimation { duration: Motion.micro; easing.type: Motion.easeMicro } }
            }
        }
        MouseArea {
            id: drag
            enabled: Media.canSeek
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Media.canSeek ? Qt.PointingHandCursor : Qt.ArrowCursor
            property real fraction: 0
            function update(x: real) { fraction = Math.max(0, Math.min(1, x / width)) }
            onPressed: e => update(e.x)
            onPositionChanged: e => { if (pressed) update(e.x) }
            onReleased: Media.setPosition(fraction * Media.length)
        }
    }

    // --- Times: elapsed and remaining, mono 11.
    Item {
        width: parent.width
        height: elapsed.implicitHeight + Theme.px(6)
        visible: Media.length > 0
        component Time: Text {
            y: Theme.px(6)
            color: Theme.textFaint
            font.family: Theme.fontMono
            font.pixelSize: Theme.px(11)
        }
        Time {
            id: elapsed
            text: root.time(seek.fraction * Media.length)
        }
        Time {
            anchors.right: parent.right
            text: "-" + root.time(Media.length * (1 - seek.fraction))
        }
    }

    // --- Controls, 22 px apart.
    Item {
        width: parent.width
        height: controls.height + Theme.px(6)
        Row {
            id: controls
            y: Theme.px(6)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.px(22) - 2 * Theme.px(6)   // the round buttons are 6 px larger than their icons

            component Control: Button {
                id: control
                property string icon
                property real iconSize: Theme.px(15)
                property color iconColor: Theme.textFaint
                anchors.verticalCenter: parent.verticalCenter
                width: iconSize + Theme.px(12)
                height: width
                Icon {
                    anchors.centerIn: parent
                    name: control.icon
                    size: control.iconSize
                    color: control.iconColor
                }
            }

            Control {
                icon: "shuffle"
                iconColor: root.player?.shuffle ? Theme.accent : Theme.textFaint
                enabled: root.player?.shuffleSupported ?? false
                onClicked: Media.toggleShuffle()
            }
            Control {
                icon: "skip-back"
                iconSize: Theme.px(22)
                iconColor: Theme.text
                enabled: root.player?.canGoPrevious ?? false
                onClicked: Media.previous()
            }
            // Play / pause: 50 px light circle.
            Button {
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.px(50)
                height: width
                base: Theme.text
                enabled: root.player?.canTogglePlaying ?? false
                onClicked: Media.toggle()
                Icon {
                    anchors.centerIn: parent
                    name: Media.playing ? "pause" : "play"
                    size: Theme.px(20)
                    color: Theme.glassTint
                }
            }
            Control {
                icon: "skip-forward"
                iconSize: Theme.px(22)
                iconColor: Theme.text
                enabled: root.player?.canGoNext ?? false
                onClicked: Media.next()
            }
            Control {
                icon: "repeat"
                iconColor: (root.player?.loopState ?? MprisLoopState.None) !== MprisLoopState.None ? Theme.accent : Theme.textFaint
                enabled: root.player?.loopSupported ?? false
                onClicked: Media.cycleLoop()
                // Repeating one track: a small "1" badge.
                Text {
                    visible: root.player?.loopState === MprisLoopState.Track
                    anchors { right: parent.right; top: parent.top }
                    text: "1"
                    color: Theme.accent
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.px(9)
                    font.weight: Font.Bold
                }
            }
        }
    }

    // --- Player chips, only when there's more than one player.
    Column {
        width: parent.width
        visible: Media.players.length > 1
        Separator { inset: 0; above: Theme.px(12); below: Theme.px(10) }
        Row {
            spacing: Theme.px(6)
            Repeater {
                model: Media.players
                Button {
                    id: chip
                    required property MprisPlayer modelData
                    width: chipText.implicitWidth + Theme.px(24)
                    height: chipText.implicitHeight + Theme.px(12)
                    radius: Theme.px(12)
                    base: Theme.white(0.06)
                    litColor: Theme.alpha(Theme.accent, 0.22)
                    lit: modelData === Media.player
                    onClicked: Media.select(modelData)
                    Text {
                        id: chipText
                        anchors.centerIn: parent
                        text: Media.label(chip.modelData)
                        color: chip.lit ? Theme.textOnContainer : Theme.textMuted
                        font.family: Theme.font
                        font.pixelSize: Theme.px(12)
                    }
                }
            }
        }
    }

    // --- Key hints (while Alt is held): Space play · ← → seek · Tab player.
    Item {
        width: parent.width
        height: KeyHints.held ? hints.implicitHeight + Theme.px(10) : 0
        clip: true
        Behavior on height { NumberAnimation { duration: Motion.micro; easing.type: Motion.easeMicro } }
        Row {
            id: hints
            y: Theme.px(10)
            spacing: Theme.px(7)
            Repeater {
                model: [["Space", "play"], ["← →", "seek"], ["Tab", "player"]]
                Row {
                    required property var modelData
                    spacing: Theme.px(7)
                    KeyHint { key: parent.modelData[0] }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: parent.modelData[1]
                        color: Theme.textFaint
                        font.family: Theme.font
                        font.pixelSize: Theme.px(11.5)
                    }
                }
            }
        }
    }
}
