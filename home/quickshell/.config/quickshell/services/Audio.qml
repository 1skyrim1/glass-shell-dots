pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Default speaker and microphone (PipeWire). Volume changes from binds and the status pill go through
// here so they show the volume OSD.
Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property int percent: Math.round(volume * 100)
    // Something is recording from the microphone: the status pill shows a red mic (09-Bar, recording row).
    readonly property bool micInUse: (micLinks.linkGroups?.length ?? 0) > 0

    readonly property real step: 0.05

    // Node properties (volume, mute) are only live while the node is tracked.
    PwObjectTracker { objects: [root.sink, root.source] }
    PwNodeLinkTracker { id: micLinks; node: root.source }

    function set(v: real) {
        if (!sink?.audio) return
        sink.audio.muted = false
        // Snap to the step grid so repeated presses land on round numbers.
        sink.audio.volume = Math.max(0, Math.min(1, Math.round(v / step) * step))
        Osd.show("volume")
    }
    function up() { set(volume + step) }
    function down() { set(volume - step) }
    function toggleMute() {
        if (!sink?.audio) return
        sink.audio.muted = !sink.audio.muted
        Osd.show("volume")
    }
    function toggleMicMute() { if (source?.audio) source.audio.muted = !source.audio.muted }
}
