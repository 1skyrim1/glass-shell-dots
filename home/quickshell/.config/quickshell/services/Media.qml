pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// The MPRIS player the bar shows: the one playing, otherwise the one that played last.
// `shown` drives the media pill: on while playing, off 10 s after playback stops (§5.3).
Singleton {
    id: root

    readonly property var players: Mpris.players.values
    property MprisPlayer player: null
    readonly property bool playing: player?.isPlaying ?? false
    readonly property string title: player?.trackTitle || player?.identity || ""
    property bool shown: false

    function pick() {
        const playing = players.find(p => p.isPlaying)
        if (playing) player = playing
        else if (!players.includes(player)) player = players[0] ?? null
    }
    onPlayersChanged: pick()
    Component.onCompleted: pick()

    // A player that starts playing takes over the pill.
    Instantiator {
        model: Mpris.players
        delegate: Connections {
            required property MprisPlayer modelData
            target: modelData
            function onIsPlayingChanged() { root.pick() }
        }
    }

    onPlayingChanged: {
        if (playing) {
            tuck.stop()
            shown = true
        } else {
            tuck.restart()
        }
    }

    Timer {
        id: tuck
        interval: Motion.mediaTuck
        onTriggered: root.shown = root.playing
    }

    function toggle() { if (player?.canTogglePlaying) player.togglePlaying() }
    function next() { if (player?.canGoNext) player.next() }
    function previous() { if (player?.canGoPrevious) player.previous() }
}
