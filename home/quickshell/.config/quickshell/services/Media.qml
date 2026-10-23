pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// The MPRIS player the bar and the media popover show: the one playing, otherwise the one that played
// last; the popover's player chips (or Tab) pick another. A player that starts playing takes over.
// `shown` drives the media pill: on while playing, off 10 s after playback stops (§5.3).
Singleton {
    id: root

    readonly property var players: Mpris.players.values
    property MprisPlayer player: null
    readonly property bool playing: player?.isPlaying ?? false
    readonly property string title: player?.trackTitle || player?.identity || ""
    property bool shown: false

    function pick() {
        if (player?.isPlaying && players.includes(player)) return
        const playing = players.find(p => p.isPlaying)
        if (playing) player = playing
        else if (!players.includes(player)) player = players[0] ?? null
    }
    function select(p: MprisPlayer) { player = p }
    function nextPlayer() {
        if (players.length > 1) player = players[(players.indexOf(player) + 1) % players.length]
    }
    onPlayersChanged: pick()
    Component.onCompleted: pick()

    // A player that starts playing takes over the pill.
    Instantiator {
        model: Mpris.players
        delegate: Connections {
            required property MprisPlayer modelData
            target: modelData
            function onIsPlayingChanged() { modelData.isPlaying ? root.player = modelData : root.pick() }
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

    // --- Popover: position (seconds), seeking, shuffle / repeat.
    readonly property real length: player?.lengthSupported ? player.length : 0
    readonly property real position: player?.positionSupported ? player.position : 0
    readonly property bool canSeek: (player?.canSeek ?? false) && length > 0
    // MPRIS doesn't announce position changes; poll while someone looks (the media popover).
    property bool watching: false
    Timer {
        running: root.watching && root.playing
        interval: 500
        repeat: true
        onTriggered: root.player.positionChanged()
    }
    function setPosition(s: real) { if (canSeek) player.position = Math.max(0, Math.min(length - 0.5, s)) }
    function seek(delta: real) { setPosition(position + delta) }
    function toggleShuffle() { if (player?.shuffleSupported) player.shuffle = !player.shuffle }
    // Off → whole playlist → this track → off.
    function cycleLoop() {
        if (!player?.loopSupported) return
        player.loopState = player.loopState === MprisLoopState.None ? MprisLoopState.Playlist
                         : player.loopState === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None
    }

    // Player chip label: the app, plus the site for a browser tab ("Firefox · YouTube").
    readonly property var sites: ({ youtube: "YouTube", soundcloud: "SoundCloud", twitch: "Twitch", bandcamp: "Bandcamp" })
    function appName(p: MprisPlayer): string { return (p?.identity ?? "").replace(/^Mozilla /, "") }
    function label(p: MprisPlayer): string {
        const app = appName(p)
        const m = String(p?.metadata?.["xesam:url"] ?? "").match(/^https?:\/\/(?:www\.|m\.|music\.)?([^./]+)\./)
        if (!m) return app
        return app + " · " + (sites[m[1]] ?? m[1][0].toUpperCase() + m[1].slice(1))
    }

    function toggle() { if (player?.canTogglePlaying) player.togglePlaying() }
    function next() { if (player?.canGoNext) player.next() }
    function previous() { if (player?.canGoPrevious) player.previous() }
}
