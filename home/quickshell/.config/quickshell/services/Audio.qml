pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Default speaker and microphone (PipeWire). Volume changes from binds and the status pill go through
// here so they show the volume OSD. The Control Center's Sound page also lists every output, input and
// app stream (it sets `watching` while it's shown, so their volumes are tracked only then).
Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property int percent: Math.round(volume * 100)
    readonly property bool micMuted: source?.audio?.muted ?? false
    // Something is recording from the microphone: the status pill shows a red mic (09-Bar, recording row).
    readonly property bool micInUse: (micLinks.linkGroups?.length ?? 0) > 0

    readonly property real step: 0.05

    // Outputs, inputs and app playback streams. Recording streams (our own mic level meter among them)
    // aren't apps playing.
    readonly property var nodes: Pipewire.nodes.values.filter(n => n.audio)
    readonly property var sinks: nodes.filter(n => n.type === PwNodeType.AudioSink)
    readonly property var sources: nodes.filter(n => n.type === PwNodeType.AudioSource)
    readonly property var streams: nodes.filter(n => n.type === PwNodeType.AudioOutStream)
    property bool watching: false

    // Node properties (volume, mute) are only live while the node is tracked.
    PwObjectTracker { objects: [root.sink, root.source] }
    PwObjectTracker { objects: root.watching ? root.sinks.concat(root.sources, root.streams) : [] }
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

    // Any node, from a slider: no snapping, unmutes.
    function setVolume(n: PwNode, v: real) {
        if (!n?.audio) return
        n.audio.muted = false
        n.audio.volume = Math.max(0, Math.min(1, v))
    }
    function toggleNodeMute(n: PwNode) { if (n?.audio) n.audio.muted = !n.audio.muted }
    function setDefault(n: PwNode) {
        if (n.isSink) Pipewire.preferredDefaultAudioSink = n
        else Pipewire.preferredDefaultAudioSource = n
    }

    // Short names like the design's ("Headphones", "Laptop speakers", "Built-in microphone"): a Bluetooth
    // device by its own name, the laptop's own card by what it is, anything else by its description.
    function bluetooth(n: PwNode): bool { return (n?.properties?.["device.api"] ?? "") === "bluez5" }
    function btDevice(n: PwNode): var {
        const addr = n?.properties?.["api.bluez5.address"] ?? ""
        return Bt.all.find(d => d.address === addr) ?? null
    }
    function nameOf(n: PwNode): string {
        if (!n) return ""
        if (n.isStream) return n.properties?.["application.name"] || n.description || n.name
        const d = n.description || n.nickname || n.name
        if (bluetooth(n)) return (btDevice(n)?.name || d) + (n.isSink ? "" : " mic")
        if (/hdmi|displayport/i.test(d + n.name)) return "HDMI / DisplayPort"
        if (/usb/i.test(n.name)) return n.nickname || d
        return n.isSink ? "Laptop speakers" : "Built-in microphone"
    }
    // Muted note on the right of a row: "Bluetooth · 80 %", "lower quality" for a headset mic.
    function noteOf(n: PwNode): string {
        if (!bluetooth(n)) return ""
        if (!n.isSink) return "lower quality"
        const b = Bt.batteryOf(btDevice(n))
        return "Bluetooth" + (b !== "" ? " · " + b : "")
    }
    function iconOf(n: PwNode): string {
        return bluetooth(n) ? "headphones" : n?.isSink ? "speaker" : "mic"
    }
}
